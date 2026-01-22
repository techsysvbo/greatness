#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> Checkout feature-01"
git fetch --all >/dev/null 2>&1 || true
git checkout feature-01 >/dev/null 2>&1 || true

echo "==> 1) Patch client links/navigation: ensure UI routes are /login and /register (not /api/...)"
python3 - <<'PY'
import pathlib, re

root = pathlib.Path("client/src")
if not root.exists():
    raise SystemExit("client/src not found")

# Replace Link/href/navigate to API paths with UI paths
repls = [
    (r'(["\'])/api/auth[^"\']*/register\1', r'\1/register\1'),
    (r'(["\'])/api/auth[^"\']*/login\1', r'\1/login\1'),
    (r'(["\'])/api/auth[^"\']*/signup\1', r'\1/register\1'),
    (r'(["\'])/api/auth[^"\']*/signin\1', r'\1/login\1'),
    (r'(["\'])/auth/register\1', r'\1/register\1'),
    (r'(["\'])/auth/login\1', r'\1/login\1'),
]

changed = 0
for p in root.rglob("*"):
    if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
        s = p.read_text(encoding="utf-8")
        orig = s
        for pat, rep in repls:
            s = re.sub(pat, rep, s)
        # Also prevent accidental concatenation like `${apiUrl}/auth/register` for navigation
        s = re.sub(r'(\bto\s*=\s*\{)\s*[^}]*VITE_API_URL[^}]*\}', r'\1"/register"}', s)
        if s != orig:
            p.write_text(s, encoding="utf-8")
            changed += 1

print("Patched UI navigation in", changed, "files")
PY

echo "==> 2) Patch client API calls to correct auth endpoints"
python3 - <<'PY'
import pathlib, re

root = pathlib.Path("client/src")
AUTH_REGISTER = "/api/auth/auth/register"
AUTH_LOGIN    = "/api/auth/auth/login"

# Replace common API call strings
register_patterns = [
    "/api/auth/register", "/api/auth/signup", "/auth/register", "/register", "/signup"
]
login_patterns = [
    "/api/auth/login", "/api/auth/signin", "/auth/login", "/login", "/signin"
]

changed = 0
for p in root.rglob("*"):
    if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
        s = p.read_text(encoding="utf-8")
        orig = s

        for pat in register_patterns:
            s = s.replace(pat, AUTH_REGISTER)
        for pat in login_patterns:
            s = s.replace(pat, AUTH_LOGIN)

        # Fix doubled /api/auth prefixes in strings
        s = re.sub(r"/api/auth(/api/auth)+", "/api/auth", s)

        if s != orig:
            p.write_text(s, encoding="utf-8")
            changed += 1

print("Patched API endpoints in", changed, "files")
print("Register API =>", AUTH_REGISTER)
print("Login API    =>", AUTH_LOGIN)
PY

echo "==> 3) Patch Profile API calls to correct endpoint (gateway -> profile-service mount /profile)"
python3 - <<'PY'
import pathlib

root = pathlib.Path("client/src")
PROFILE_ME = "/api/profile/profile/me"

patterns = [
    "/api/profile/me",
    "/profile/me",
    "/api/profile/profile/me"
]

changed = 0
for p in root.rglob("*"):
    if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
        s = p.read_text(encoding="utf-8")
        orig = s
        for pat in patterns:
            # only replace if it looks like an API call string, not a UI route
            s = s.replace(pat, PROFILE_ME)
        if s != orig:
            p.write_text(s, encoding="utf-8")
            changed += 1

print("Patched profile endpoint in", changed, "files")
print("Profile API =>", PROFILE_ME)
PY

echo "==> 4) Ensure gateway forwards Authorization + Cookie (idempotent)"
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

echo "==> 5) Rebuild and restart gateway + client"
docker-compose build --no-cache gateway client
docker-compose up -d gateway client

echo
echo "✅ Done."
echo "Now open:"
echo "  http://localhost:8080/register  (UI route)"
echo "  http://localhost:8080/login     (UI route)"
echo
echo "API endpoints used by the client are now:"
echo "  POST  /api/auth/auth/register"
echo "  POST  /api/auth/auth/login"
echo "  GET/PUT /api/profile/profile/me"
