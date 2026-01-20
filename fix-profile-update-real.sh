#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Gateway: forward Authorization + cookies (idempotent)"
cat > services/gateway/nginx.conf <<'NGINX'
server {
  listen 80;

  location /api/auth/ {
    proxy_pass http://auth-service:4000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_set_header Authorization $http_authorization;
    proxy_set_header Cookie $http_cookie;
  }

  location /api/profile/ {
    proxy_pass http://profile-service:4001/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_set_header Authorization $http_authorization;
    proxy_set_header Cookie $http_cookie;
  }

  location / {
    proxy_pass http://client:3000/;
    proxy_set_header Host $host;
  }
}
NGINX

echo "==> 2) Profile service: robust auth middleware (Authorization OR cookie OR x-access-token)"
mkdir -p services/profile/src/middleware

cat > services/profile/src/middleware/authMiddleware.ts <<'TS'
import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

export interface AuthRequest extends Request {
  user?: { id: number; email?: string; username?: string };
}

function parseCookies(cookieHeader?: string): Record<string, string> {
  const out: Record<string, string> = {};
  if (!cookieHeader) return out;

  cookieHeader.split(";").forEach((part) => {
    const [k, ...rest] = part.trim().split("=");
    if (!k) return;
    out[k] = decodeURIComponent(rest.join("=") || "");
  });

  return out;
}

export const authMiddleware = (req: AuthRequest, res: Response, next: NextFunction) => {
  // 1) Authorization: Bearer <token>
  const auth = req.headers.authorization;
  let token: string | undefined;

  if (auth && auth.startsWith("Bearer ")) {
    token = auth.slice("Bearer ".length).trim();
  }

  // 2) x-access-token header
  if (!token) {
    const x = req.headers["x-access-token"];
    if (typeof x === "string" && x.length > 0) token = x;
  }

  // 3) Cookie token (supports multiple common names)
  if (!token) {
    const cookies = parseCookies(req.headers.cookie);
    token =
      cookies["token"] ||
      cookies["accessToken"] ||
      cookies["authToken"] ||
      cookies["jwt"] ||
      cookies["Authorization"];
  }

  if (!token) {
    return res.status(401).json({ message: "Unauthorized: missing token" });
  }

  try {
    const decoded: any = jwt.verify(token, process.env.JWT_SECRET || "dev_secret_key_change_me");

    // Support either { id } or { userId }
    const id = decoded.id ?? decoded.userId;
    if (!id) {
      return res.status(401).json({ message: "Unauthorized: token missing id/userId" });
    }

    req.user = { id: Number(id), email: decoded.email, username: decoded.username };
    return next();
  } catch (err: any) {
    return res.status(401).json({ message: "Unauthorized: invalid token", detail: err?.message });
  }
};
TS

echo "==> 3) Profile routes: enforce /profile/me with authMiddleware"
mkdir -p services/profile/src/routes

cat > services/profile/src/routes/profileRoutes.ts <<'TS'
import { Router } from "express";
import { getProfile, updateProfile } from "../controllers/profileController";
import { authMiddleware } from "../middleware/authMiddleware";

const router = Router();

router.get("/me", authMiddleware, getProfile);
router.put("/me", authMiddleware, updateProfile);

export default router;
TS

echo "==> 4) Client: force fetch/axios to include credentials (cookies) and attach token if present"
# We patch client/src/services/api.ts if it exists; otherwise patch Profile page.
API_FILE=""
if [ -f client/src/services/api.ts ]; then API_FILE="client/src/services/api.ts"; fi
if [ -z "$API_FILE" ] && [ -f client/src/services/api.js ]; then API_FILE="client/src/services/api.js"; fi

PROFILE_PAGE=""
if [ -f client/src/pages/Profile.tsx ]; then PROFILE_PAGE="client/src/pages/Profile.tsx"; fi
if [ -z "$PROFILE_PAGE" ] && [ -f client/src/pages/Profile.jsx ]; then PROFILE_PAGE="client/src/pages/Profile.jsx"; fi

if [ -n "$API_FILE" ] && grep -q "axios" "$API_FILE"; then
  echo "Patching axios api client: $API_FILE"
  python3 - <<PY
import re
p="${API_FILE}"
s=open(p,"r",encoding="utf-8").read()

# Ensure axios sends cookies
if "withCredentials" not in s:
    s=re.sub(r'axios\\.create\\(\\{', 'axios.create({\\n  withCredentials: true,', s)

# Add interceptor if missing
if "interceptors.request.use" not in s:
    m=re.search(r'(const\\s+(\\w+)\\s*=\\s*axios\\.create\\([^;]*\\);)', s, re.S)
    if m:
        full=m.group(1); var=m.group(2)
        insert=f"""{full}

{var}.interceptors.request.use((config) => {{
  const token =
    localStorage.getItem("token") ||
    localStorage.getItem("accessToken") ||
    localStorage.getItem("authToken") ||
    localStorage.getItem("jwt") ||
    sessionStorage.getItem("token") ||
    sessionStorage.getItem("accessToken") ||
    sessionStorage.getItem("authToken") ||
    sessionStorage.getItem("jwt");

  if (token) {{
    config.headers = config.headers || {{}};
    config.headers.Authorization = `Bearer \${{token}}`;
  }}

  config.withCredentials = true;
  return config;
}});
"""
        s=s.replace(full, insert)

open(p,"w",encoding="utf-8").write(s)
print("Patched:", p)
PY
else
  if [ -n "$PROFILE_PAGE" ]; then
    echo "Patching Profile page fetch calls: $PROFILE_PAGE"
    python3 - <<PY
import re
p="${PROFILE_PAGE}"
s=open(p,"r",encoding="utf-8").read()

# Best-effort: ensure credentials: "include" on fetch and add Authorization header if token exists
if "credentials" not in s:
    s=re.sub(r'fetch\\(([^,]+),\\s*\\{', r'fetch(\\1, {\\n      credentials: "include",', s, count=1)

# Add token variable near submit handler
if "handleSubmit" in s and "const token" not in s:
    s=re.sub(r'(async\\s+function\\s+handleSubmit\\([^)]*\\)\\s*\\{)',
             r'\\1\\n    const token = localStorage.getItem("token") || localStorage.getItem("accessToken") || localStorage.getItem("authToken") || localStorage.getItem("jwt") || sessionStorage.getItem("token") || sessionStorage.getItem("accessToken") || sessionStorage.getItem("authToken") || sessionStorage.getItem("jwt");\\n',
             s)

# Inject Authorization header into the first JSON headers block
s=re.sub(r'headers\\s*:\\s*\\{\\s*["\\\']Content-Type["\\\']\\s*:\\s*["\\\']application\\/json["\\\']\\s*\\}',
         'headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }',
         s)

open(p,"w",encoding="utf-8").write(s)
print("Patched:", p)
PY
  else
    echo "ERROR: Could not find api.ts or Profile page to patch."
    exit 1
  fi
fi

echo "==> 5) Rebuild and restart affected services"
docker-compose build --no-cache gateway profile-service client
docker-compose up -d gateway profile-service client

echo "==> 6) Verify profile-service reachable and protected"
docker-compose exec -T gateway sh -lc 'getent hosts profile-service && wget -qO- http://profile-service:4001/health'
echo
docker-compose exec -T gateway sh -lc 'wget -S -qO- http://profile-service:4001/profile/me || true'

echo
echo "✅ Done. Now go to http://localhost:8080/profile and click Save Changes."
echo "If it still fails, run: docker-compose logs --tail=200 profile-service"
