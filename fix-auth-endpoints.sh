#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> Switch to feature-01 (safe)"
git fetch --all >/dev/null 2>&1 || true
git checkout feature-01 >/dev/null 2>&1 || true

echo "==> 1) Detect auth route prefix from auth-service source"
AUTH_ENTRY=""
for f in services/auth/src/index.ts services/auth/src/server.ts services/auth/src/app.ts; do
  if [ -f "$f" ]; then AUTH_ENTRY="$f"; break; fi
done

if [ -z "$AUTH_ENTRY" ]; then
  echo "ERROR: Could not find auth entry file under services/auth/src/"
  exit 1
fi

echo "Auth entry: $AUTH_ENTRY"

# Try to detect app.use("...auth...", ...)
AUTH_PREFIX="$(grep -Eo "app\.use\(['\"][^'\"]+['\"]" "$AUTH_ENTRY" \
  | head -n 1 \
  | sed -E "s/app\.use\(['\"]([^'\"]+)['\"].*/\1/")"

# Fallback guesses if not found
if [ -z "$AUTH_PREFIX" ]; then
  AUTH_PREFIX="/"
fi

echo "Detected auth prefix: $AUTH_PREFIX"

echo "==> 2) Detect actual register/login paths by scanning auth routes/controllers"
# Look for strings like router.post('/register' ...) etc.
ROUTES_TXT="$(grep -R --no-messages -nE "router\.(post|get)\(['\"]/[^'\"]+" services/auth/src | head -n 50 || true)"

# Extract likely register/login endpoints
REGISTER_PATH="$(echo "$ROUTES_TXT" | grep -iE "register|signup" | head -n 1 | sed -E "s/.*router\.post\(['\"]([^'\"]+)['\"].*/\1/")"
LOGIN_PATH="$(echo "$ROUTES_TXT" | grep -iE "login|signin" | head -n 1 | sed -E "s/.*router\.post\(['\"]([^'\"]+)['\"].*/\1/")"

# Fallbacks
if [ -z "$REGISTER_PATH" ]; then REGISTER_PATH="/register"; fi
if [ -z "$LOGIN_PATH" ]; then LOGIN_PATH="/login"; fi

echo "Detected register route: $REGISTER_PATH"
echo "Detected login route:    $LOGIN_PATH"

echo "==> 3) Patch gateway nginx to proxy auth correctly"
# The auth service likely expects requests at AUTH_PREFIX + REGISTER_PATH etc.
# We will proxy /api/auth/* -> auth-service:4000/* and NOT assume deeper prefixes.
cat > services/gateway/nginx.conf <<'NGINX'
server {
  listen 80;

  # Auth
  location /api/auth/ {
    proxy_pass http://auth-service:4000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Authorization $http_authorization;
    proxy_set_header Cookie $http_cookie;
  }

  # Profile
  location /api/profile/ {
    proxy_pass http://profile-service:4001/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Authorization $http_authorization;
    proxy_set_header Cookie $http_cookie;
  }

  # Frontend
  location / {
    proxy_pass http://client:3000/;
    proxy_set_header Host $host;
  }
}
NGINX

echo "==> 4) Patch client auth calls to use /api/auth + detected paths"
# We’ll replace common wrong paths with correct ones inside client/src.
# This is safe + idempotent.
python3 - <<PY
import re, pathlib

root = pathlib.Path("client/src")
register_path = "/api/auth${REGISTER_PATH}"
login_path = "/api/auth${LOGIN_PATH}"

# patterns we replace
reg_patterns = [
  r"/api/auth/register",
  r"/api/auth/signup",
  r"/auth/register",
  r"/auth/signup",
  r"/register",
  r"/signup",
]
login_patterns = [
  r"/api/auth/login",
  r"/api/auth/signin",
  r"/auth/login",
  r"/auth/signin",
  r"/login",
  r"/signin",
]

def patch_file(p: pathlib.Path):
  s = p.read_text(encoding="utf-8")
  orig = s
  # replace register endpoints
  for pat in reg_patterns:
    s = s.replace(pat, register_path)
  # replace login endpoints
  for pat in login_patterns:
    s = s.replace(pat, login_path)
  if s != orig:
    p.write_text(s, encoding="utf-8")
    return True
  return False

changed = 0
for p in root.rglob("*"):
  if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
    if patch_file(p):
      changed += 1

print(f"Patched {changed} client files.")
print("Register endpoint now:", register_path)
print("Login endpoint now:", login_path)
PY

echo "==> 5) Rebuild + restart gateway, auth-service, client"
docker-compose build --no-cache gateway auth-service client
docker-compose up -d gateway auth-service client

echo "==> 6) Verify auth-service health from gateway"
docker-compose exec -T gateway sh -lc 'wget -S -qO- http://auth-service:4000/health || true'
echo

echo "==> 7) Test registration through gateway (actual endpoint)"
# Use wget inside gateway to hit the gateway itself (localhost inside gateway == gateway container)
# We’ll try multiple payload shapes to match your backend (username/email/password variations).
set +e
for payload in \
'{"username":"victor_test","password":"Passw0rd!"}' \
'{"email":"victor_test@example.com","password":"Passw0rd!"}' \
'{"username":"victor_test","email":"victor_test@example.com","password":"Passw0rd!"}'; do
  echo "--- POST /api/auth${REGISTER_PATH} payload=$payload"
  docker-compose exec -T gateway sh -lc "wget -S -qO- --header='Content-Type: application/json' --post-data='$payload' http://localhost/api/auth${REGISTER_PATH} || true"
  echo
done
set -e

echo "✅ Done. If registration still fails, paste: docker-compose logs --tail=200 auth-service"
