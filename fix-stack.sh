#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/techs/OneDrive/Desktop/ag-workspace"
cd "$ROOT"

echo "==> Fixing profile-service start command (server.js -> index.js)"

# Patch package.json start script
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

# Write a known-good Dockerfile
cat > services/profile/Dockerfile <<'DOCKER'
FROM node:18-alpine
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

EXPOSE 4001
CMD ["npm", "start"]
DOCKER

echo "==> Rebuilding and restarting full stack"
docker-compose down -v
docker-compose build --no-cache profile-service gateway
docker-compose up -d

echo "==> Show container status"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "==> Tail logs (gateway + profile-service)"
docker-compose logs --tail=50 gateway || true
docker-compose logs --tail=80 profile-service || true

echo "==> Verify profile-service is listening internally"
docker-compose exec -T profile-service sh -lc 'ls -la dist && node -e "console.log(\"node ok\")"'

echo "==> Verify gateway can resolve profile-service (DNS) and reach /health"
docker-compose exec -T gateway sh -lc 'getent hosts profile-service && wget -qO- http://profile-service:4001/health || true'

echo "==> Done. Now test in browser: http://localhost:8080/profile"
