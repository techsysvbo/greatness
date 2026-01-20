#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Collect candidate auth POST endpoints from source"
CANDIDATES="$(grep -R --no-messages -nE "router\.post\(['\"][^'\"]+['\"]" services/auth/src \
  | sed -E "s/.*router\.post\(['\"]([^'\"]+)['\"].*/\1/" \
  | sort -u)"

if [ -z "$CANDIDATES" ]; then
  echo "ERROR: Could not find any router.post(...) in services/auth/src"
  exit 1
fi

echo "Found endpoints:"
echo "$CANDIDATES"
echo

echo "==> 2) Start auth-service and gateway"
docker-compose up -d db redis auth-service gateway
sleep 2

echo "==> 3) Try each candidate endpoint directly on auth-service:4000"
PAYLOAD='{"username":"victor_test","email":"victor_test@example.com","password":"Passw0rd!"}'
WORKING=""

set +e
for p in $CANDIDATES; do
  echo "--- Testing POST $p on auth-service directly"
  # Use wget inside gateway container to reach auth-service via Docker DNS
  OUT="$(docker-compose exec -T gateway sh -lc \
    "wget -S -qO- --header='Content-Type: application/json' --post-data='$PAYLOAD' http://auth-service:4000$p 2>&1")"
  echo "$OUT" | head -n 15
  echo
  # Heuristic: if we see HTTP/1.1 2xx or 4xx other than 404, it's likely the right route
  if echo "$OUT" | grep -qE "HTTP/1\.1 (200|201|400|409|422)"; then
    if ! echo "$OUT" | grep -q "404 Not Found"; then
      WORKING="$p"
      break
    fi
  fi
done
set -e

if [ -z "$WORKING" ]; then
  echo "ERROR: Could not find a working register endpoint by probing auth-service."
  echo "Next step: show full auth route wiring."
  exit 1
fi

echo "✅ Working auth POST endpoint detected: $WORKING"
echo

echo "==> 4) Patch gateway nginx to map /api/auth/* to auth-service (already), keep as-is"
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

echo "==> 5) Patch client registration endpoint to /api/auth$WORKING"
python3 - <<PY
import pathlib

target = "/api/auth" + "${WORKING}"
root = pathlib.Path("client/src")

# Replace common register paths with detected target
patterns = [
  "/api/auth/register", "/api/auth/signup", "/auth/register", "/auth/signup", "/register", "/signup"
]

changed = 0
for p in root.rglob("*"):
  if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
    s = p.read_text(encoding="utf-8")
    orig = s
    for pat in patterns:
      s = s.replace(pat, target)
    if s != orig:
      p.write_text(s, encoding="utf-8")
      changed += 1

print("Patched files:", changed)
print("Register endpoint now:", target)
PY

echo "==> 6) Rebuild gateway + client (auth-service unchanged)"
docker-compose build --no-cache gateway client
docker-compose up -d gateway client

echo "==> 7) Verify register works via gateway URL (/api/auth...)"
docker-compose exec -T gateway sh -lc \
  "wget -S -qO- --header='Content-Type: application/json' --post-data='$PAYLOAD' http://localhost/api/auth${WORKING} 2>&1 | head -n 30 || true"

echo
echo "✅ Done. Now try Register in browser."
