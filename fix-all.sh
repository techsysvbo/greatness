#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/techs/OneDrive/Desktop/ag-workspace"
cd "$ROOT"

echo "==> Ensuring profile-service starts dist/index.js"
python3 - <<'PY'
import json
p="services/profile/package.json"
with open(p,"r",encoding="utf-8") as f:
    data=json.load(f)
scripts=data.get("scripts",{})
scripts["build"]=scripts.get("build","tsc")
scripts["start"]="node dist/index.js"
data["scripts"]=scripts
with open(p,"w",encoding="utf-8") as f:
    json.dump(data,f,indent=2)
print("patched",p)
PY

cat > services/profile/Dockerfile <<'DOCKER'
FROM node:18-alpine
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

EXPOSE 4001
CMD ["npm","start"]
DOCKER

echo "==> Ensure /health exists in profile service"
PROFILE_INDEX="services/profile/src/index.ts"
if [ -f "$PROFILE_INDEX" ]; then
  if ! grep -q '"/health"' "$PROFILE_INDEX" && ! grep -q "'/health'" "$PROFILE_INDEX"; then
    # Insert before app.listen
    perl -0777 -i -pe 's/(app\.use\([^\n]*profileRoutes\);\s*)/$1\napp.get(\"\\/health\", (_req, res) => res.status(200).send(\"ok\"));\n/s' "$PROFILE_INDEX"
  fi
fi

echo "==> Fix gateway nginx config (default.conf must be server{} only)"
# Your gateway Dockerfile copies "nginx.conf" to /etc/nginx/conf.d/default.conf
# So nginx.conf MUST contain only a server{} block.
cat > services/gateway/nginx.conf <<'NGINX'
server {
  listen 80;

  # Auth
  location /api/auth/ {
    proxy_pass http://auth-service:4000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  # Profile
  location /api/profile/ {
    proxy_pass http://profile-service:4001/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  # Frontend
  location / {
    proxy_pass http://client:3000/;
    proxy_set_header Host $host;
  }
}
NGINX

echo "==> Ensure docker-compose has profile-service under services and on same network"
python3 - <<'PY'
import yaml
p="docker-compose.yml"
with open(p,"r",encoding="utf-8") as f:
    d=yaml.safe_load(f)

d.setdefault("services",{})
d.setdefault("networks",{})
d["networks"].setdefault("diaspora-network", {"driver":"bridge"})

svc=d["services"]

# profile-service
ps=svc.get("profile-service",{})
ps.setdefault("build", {"context":"./services/profile"})
ps.setdefault("ports", ["4001:4001"])
env=ps.get("environment",{})
if isinstance(env,list):
    new={}
    for item in env:
        if "=" in item:
            k,v=item.split("=",1)
            new[k]=v
    env=new
env.setdefault("DATABASE_URL","postgres://admin:password@db:5432/diaspora_db")
env.setdefault("JWT_SECRET","dev_secret_key_change_me")
env.setdefault("PORT","4001")
ps["environment"]=env
ps.setdefault("depends_on", ["db"])
ps["networks"]=["diaspora-network"]
ps.pop("container_name", None)
svc["profile-service"]=ps

# gateway must be on same network and depend on profile-service
gw=svc.get("gateway",{})
gw.setdefault("depends_on",[])
if isinstance(gw["depends_on"],list) and "profile-service" not in gw["depends_on"]:
    gw["depends_on"].append("profile-service")
gw["networks"]=["diaspora-network"]
svc["gateway"]=gw

d["services"]=svc

with open(p,"w",encoding="utf-8") as f:
    yaml.safe_dump(d,f,sort_keys=False)
PY

echo "==> Validate compose"
docker-compose config >/dev/null

echo "==> Rebuild + restart stack"
docker-compose down -v
docker-compose build --no-cache gateway profile-service
docker-compose up -d

echo "==> Show status"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "==> Verify gateway is running"
docker-compose ps gateway || true
docker-compose logs --tail=30 gateway || true

echo "==> Verify DNS + health from inside gateway"
docker-compose exec -T gateway sh -lc 'getent hosts profile-service && wget -qO- http://profile-service:4001/health'
echo
echo "✅ All good. Open: http://localhost:8080/profile"
