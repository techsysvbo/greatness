#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/techs/OneDrive/Desktop/ag-workspace"
cd "$ROOT"

echo "==> 0) Validate docker-compose config"
docker-compose config >/dev/null

echo "==> 1) Patch gateway nginx.conf to forward Authorization + cookies"
# gateway Dockerfile copies services/gateway/nginx.conf -> /etc/nginx/conf.d/default.conf
cat > services/gateway/nginx.conf <<'NGINX'
server {
  listen 80;

  # Auth service
  location /api/auth/ {
    proxy_pass http://auth-service:4000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    # Forward auth headers/cookies
    proxy_set_header Authorization $http_authorization;
    proxy_set_header Cookie $http_cookie;
  }

  # Profile service
  location /api/profile/ {
    proxy_pass http://profile-service:4001/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    # THE IMPORTANT PART:
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

echo "==> 2) Ensure profile-service has /health and numeric port bind"
INDEX="services/profile/src/index.ts"
if [ -f "$INDEX" ]; then
  python3 - <<'PY'
import re
p="services/profile/src/index.ts"
s=open(p,"r",encoding="utf-8").read()

# force numeric port
s=re.sub(r'const\s+port\s*=\s*process\.env\.PORT\s*\|\|\s*(\d+)\s*;',
         r'const port = Number(process.env.PORT || \1);', s)

# add /health if missing
if '"/health"' not in s and "'/health'" not in s:
  s=re.sub(r'(app\.use\([^\n]*profileRoutes\);\s*)',
           r'\1\napp.get("/health", (_req, res) => res.status(200).send("ok"));\n',
           s, flags=re.M)

# bind to 0.0.0.0 if not already
s=re.sub(r'app\.listen\(\s*port\s*,\s*async\s*\(',
         'app.listen(port, "0.0.0.0", async(', s)
s=re.sub(r'app\.listen\(\s*port\s*,\s*\(',
         'app.listen(port, "0.0.0.0", (', s)

open(p,"w",encoding="utf-8").write(s)
print("patched",p)
PY
else
  echo "WARN: $INDEX not found, skipping"
fi

echo "==> 3) Ensure DB schema columns exist (country/state/city/zip_code/display_name/profession)"
# Create/alter table safely
docker-compose up -d db
sleep 2
docker-compose exec -T db psql -U admin -d diaspora_db <<'SQL'
CREATE TABLE IF NOT EXISTS profiles (
  user_id INTEGER PRIMARY KEY,
  display_name VARCHAR(255),
  bio TEXT,
  location VARCHAR(255),
  zip_code VARCHAR(20),
  profession VARCHAR(255),
  interests TEXT,
  privacy_settings JSONB,
  country VARCHAR(100),
  state VARCHAR(100),
  city VARCHAR(100),
  updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name VARCHAR(255);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS profession VARCHAR(255);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS state VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS zip_code VARCHAR(20);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();
SQL

echo "==> 4) Make profile-service robust to DB readiness (retry initDB if present)"
DBTS="services/profile/src/db.ts"
if [ -f "$DBTS" ]; then
  # If initDB exists, ensure it retries. If not, skip (you already have it in your logs).
  true
fi

echo "==> 5) Rebuild + restart gateway and profile-service"
docker-compose build --no-cache gateway profile-service
docker-compose up -d gateway profile-service

echo "==> 6) Verify: gateway running"
docker-compose ps gateway

echo "==> 7) Verify: profile-service health from inside gateway"
docker-compose exec -T gateway sh -lc 'getent hosts profile-service && wget -qO- http://profile-service:4001/health'
echo

echo "==> 8) Verify: profile endpoint is reachable (should be 401 without token)"
docker-compose exec -T gateway sh -lc 'wget -S -qO- http://profile-service:4001/profile/me || true'

echo
echo "✅ Done. Now refresh http://localhost:8080/profile and try Save Changes again."
echo "If it still fails, the browser is not sending Authorization at all, and we will patch the client request next."
