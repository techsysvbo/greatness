#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/techs/OneDrive/Desktop/ag-workspace"
cd "$ROOT"

echo "==> 1) Ensure gateway forwards Authorization header (idempotent)"
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

echo "==> 2) Auto-detect token key used by client (localStorage.setItem)"
TOKEN_KEY="$(grep -R --line-number --no-messages -E "localStorage\.setItem\(['\"][^'\"]+['\"]" client/src \
  | head -n 1 \
  | sed -E "s/.*localStorage\.setItem\(['\"]([^'\"]+)['\"].*/\1/")"

if [ -z "${TOKEN_KEY}" ]; then
  echo "WARN: Could not auto-detect token key via localStorage.setItem."
  echo "      Falling back to common keys: token, accessToken, authToken, jwt"
  TOKEN_KEY="token"
else
  echo "Detected token key: ${TOKEN_KEY}"
fi

echo "==> 3) Patch API client to always attach Authorization"
API_TS=""
if [ -f client/src/services/api.ts ]; then API_TS="client/src/services/api.ts"; fi
if [ -z "$API_TS" ] && [ -f client/src/services/api.js ]; then API_TS="client/src/services/api.js"; fi
if [ -z "$API_TS" ] && [ -f client/src/services/api.tsx ]; then API_TS="client/src/services/api.tsx"; fi

PATCHED=0

# If there is an axios client file, patch it
if [ -n "$API_TS" ] && grep -q "axios" "$API_TS"; then
  echo "Patching axios API client: $API_TS"
  python3 - <<PY
import re
p="${API_TS}"
token_key="${TOKEN_KEY}"
s=open(p,"r",encoding="utf-8").read()

# If already patched, exit
if "interceptors.request.use" in s and "Authorization" in s:
    print("Already has interceptor:", p)
else:
    # Find axios.create and capture var name
    m=re.search(r'(const\\s+(\\w+)\\s*=\\s*axios\\.create\\([^;]*\\);)', s, re.S)
    if not m:
        print("Could not find axios.create(...) in", p)
    else:
        full=m.group(1)
        var=m.group(2)
        interceptor=f"""{full}

{var}.interceptors.request.use((config) => {{
  const token =
    localStorage.getItem("{token_key}") ||
    localStorage.getItem("token") ||
    localStorage.getItem("accessToken") ||
    localStorage.getItem("authToken") ||
    localStorage.getItem("jwt");

  if (token) {{
    config.headers = config.headers || {{}};
    config.headers.Authorization = `Bearer \${{token}}`;
  }}

  return config;
}});
"""
        s=s.replace(full, interceptor)
        open(p,"w",encoding="utf-8").write(s)
        print("Inserted interceptor into", p)
PY
  PATCHED=1
fi

# Otherwise patch Profile page fetch calls directly
PROFILE_PAGE=""
if [ -f client/src/pages/Profile.tsx ]; then PROFILE_PAGE="client/src/pages/Profile.tsx"; fi
if [ -z "$PROFILE_PAGE" ] && [ -f client/src/pages/Profile.jsx ]; then PROFILE_PAGE="client/src/pages/Profile.jsx"; fi

if [ "$PATCHED" -eq 0 ] && [ -n "$PROFILE_PAGE" ]; then
  echo "No axios api client found. Patching Profile page fetch calls: $PROFILE_PAGE"
  python3 - <<PY
import re
p="${PROFILE_PAGE}"
token_key="${TOKEN_KEY}"
s=open(p,"r",encoding="utf-8").read()

# Avoid double-patching
if "Authorization" in s and "Bearer" in s:
    print("Already contains Authorization header logic:", p)
else:
    # Add token retrieval at top of submit handler, best-effort
    s=re.sub(r'(async\\s+function\\s+handleSubmit\\([^)]*\\)\\s*\\{)',
             r'\\1\\n    const token = localStorage.getItem("%s") || localStorage.getItem("token") || localStorage.getItem("accessToken") || localStorage.getItem("authToken") || localStorage.getItem("jwt");\\n' % token_key,
             s)

    # Add Authorization header into common JSON fetch headers
    s=re.sub(r'headers\\s*:\\s*\\{\\s*["\\\']Content-Type["\\\']\\s*:\\s*["\\\']application\\/json["\\\']\\s*\\}',
             'headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }',
             s)

    open(p,"w",encoding="utf-8").write(s)
    print("Patched", p)
PY
  PATCHED=1
fi

if [ "$PATCHED" -eq 0 ]; then
  echo "ERROR: Could not find an axios api client or Profile page to patch."
  echo "Run: ls client/src/services && ls client/src/pages"
  exit 1
fi

echo "==> 4) Make UI show backend error details (so you don’t get blind 'Failed to update profile')"
# Patch the same Profile page if it exists; if not, skip
if [ -n "$PROFILE_PAGE" ] && [ -f "$PROFILE_PAGE" ]; then
  python3 - <<'PY'
import re
import os
p=os.environ.get("PROFILE_PAGE","")
if not p or not os.path.exists(p):
    raise SystemExit(0)
s=open(p,"r",encoding="utf-8").read()

# try to improve error alert: use response body
# Best-effort patch: if code uses `alert("Failed to update profile")`, replace with body-aware alert
s=s.replace('alert("Failed to update profile")','alert(data?.message || data?.error || JSON.stringify(data) || "Failed to update profile")')
open(p,"w",encoding="utf-8").write(s)
print("Improved error reporting in", p)
PY
fi

echo "==> 5) Rebuild client + gateway and restart them"
docker-compose build --no-cache client gateway
docker-compose up -d client gateway

echo "==> 6) Quick verification: gateway running"
docker-compose ps gateway

echo "==> DONE"
echo "Now reload http://localhost:8080/profile, open DevTools > Network, click Save Changes."
echo "If it still fails, the UI will now show the real backend error message."
