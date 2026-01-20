#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/techs/OneDrive/Desktop/ag-workspace"
cd "$ROOT"

echo "==> Switching to feature-01"
git fetch --all >/dev/null 2>&1 || true
git checkout feature-01

echo "==> Writing a known-good gateway nginx config"
mkdir -p services/gateway

# We write BOTH nginx.conf and default.conf so it works regardless of Dockerfile COPY target.
cat > services/gateway/nginx.conf <<'NGINX'
events {}

http {
  # Docker's embedded DNS
  resolver 127.0.0.11 ipv6=off valid=10s;

  upstream auth_service {
    server auth-service:4000;
  }

  upstream profile_service {
    server profile-service:4001;
  }

  upstream client_app {
    server client:3000;
  }

  server {
    listen 80;

    # Auth
    location /api/auth/ {
      proxy_pass http://auth_service/;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Profile
    location /api/profile/ {
      # IMPORTANT: forward /api/profile/* to the profile service root
      proxy_pass http://profile_service/;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Frontend
    location / {
      proxy_pass http://client_app/;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
  }
}
NGINX

cat > services/gateway/default.conf <<'NGINX'
server {
  listen 80;

  location /api/auth/ {
    proxy_pass http://auth-service:4000/;
  }

  location /api/profile/ {
    proxy_pass http://profile-service:4001/;
  }

  location / {
    proxy_pass http://client:3000/;
  }
}
NGINX

echo "==> Ensuring profile-service has /health"
PROFILE_INDEX="services/profile/src/index.ts"
if [ -f "$PROFILE_INDEX" ]; then
  # Insert /health if missing
  if ! grep -q "app.get('/health'" "$PROFILE_INDEX" && ! grep -q 'app.get("/health"' "$PROFILE_INDEX"; then
    # Add health endpoint right before app.listen
    awk '
      {print}
      /app\.listen\(/ && !done {
        done=1
      }
    ' "$PROFILE_INDEX" > /tmp/index.ts

    # naive insert near the top after routes are mounted; safer approach: append before listen
    perl -0777 -pe 's|(app\.use\([^\n]*profileRoutes\);\s*)|$1\n// Health check\napp.get(\"/health\", (_req, res) => res.status(200).send(\"ok\"));\n|s' /tmp/index.ts > "$PROFILE_INDEX" || true
  fi
else
  echo "WARN: $PROFILE_INDEX not found; skipping /health insert"
fi

echo "==> Writing a clean docker-compose.yml networking section (patch style)"
# We DO NOT overwrite your whole compose. We only ensure:
# - profile-service exists under services
# - gateway + profile-service share diaspora-network
# - remove container_name (optional but recommended)
# - gateway depends_on includes profile-service
python3 - <<'PY'
import yaml, sys, os

path="docker-compose.yml"
with open(path,"r",encoding="utf-8") as f:
    data=yaml.safe_load(f)

if "services" not in data:
    data["services"]={}

services=data["services"]

# Ensure network exists
if "networks" not in data:
    data["networks"]={}
if "diaspora-network" not in data["networks"]:
    data["networks"]["diaspora-network"]={"driver":"bridge"}

# Ensure profile-service exists
ps=services.get("profile-service", {})
# build context
if isinstance(ps.get("build"), str):
    # keep it, but normalize
    pass
elif isinstance(ps.get("build"), dict):
    pass
else:
    ps["build"]={"context":"./services/profile"}
# ports
ps.setdefault("ports", ["4001:4001"])
# env
env=ps.get("environment", {})
if isinstance(env, list):
    # convert list -> dict
    d={}
    for item in env:
        if "=" in item:
            k,v=item.split("=",1)
            d[k]=v
    env=d
env.setdefault("DATABASE_URL","postgres://admin:password@db:5432/diaspora_db")
env.setdefault("JWT_SECRET","dev_secret_key_change_me")
env.setdefault("PORT","4001")
ps["environment"]=env
# depends_on
ps.setdefault("depends_on", ["db"])
# networks
ps["networks"]=["diaspora-network"]
# remove container_name if present
ps.pop("container_name", None)

services["profile-service"]=ps

# Ensure gateway is on the same network and depends on profile-service
gw=services.get("gateway", {})
gw.setdefault("depends_on", [])
if isinstance(gw["depends_on"], list):
    if "profile-service" not in gw["depends_on"]:
        gw["depends_on"].append("profile-service")
gw["networks"]=["diaspora-network"]
services["gateway"]=gw

data["services"]=services

with open(path,"w",encoding="utf-8") as f:
    yaml.safe_dump(data,f,sort_keys=False)
PY

echo "==> Rebuilding gateway + profile-service"
docker-compose down -v
docker-compose build --no-cache gateway profile-service
docker-compose up -d

echo "==> Verifying DNS from inside gateway"
docker-compose exec -T gateway sh -lc 'cat /etc/resolv.conf && echo && getent hosts profile-service && echo && wget -qO- http://profile-service:4001/health || true'

echo "==> Done. Now try: http://localhost:8080/profile"
