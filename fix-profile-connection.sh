#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/techs/OneDrive/Desktop/ag-workspace"
cd "$ROOT"

echo "==> 1) Force profile-service to start correctly even if docker-compose.override.yml exists"

# If override exists, rewrite it so it doesn't break profile-service
if [ -f docker-compose.override.yml ]; then
  echo "Found docker-compose.override.yml - patching profile-service command to npm start"
  python3 - <<'PY'
import yaml
p="docker-compose.override.yml"
with open(p,"r",encoding="utf-8") as f:
    d=yaml.safe_load(f) or {}
d.setdefault("services", {})
d["services"].setdefault("profile-service", {})
d["services"]["profile-service"]["command"] = ["npm","start"]
with open(p,"w",encoding="utf-8") as f:
    yaml.safe_dump(d,f,sort_keys=False)
print("patched",p)
PY
else
  echo "No docker-compose.override.yml found (ok)"
fi

echo "==> 2) Ensure profile-service package.json starts dist/index.js"
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

echo "==> 3) Ensure profile-service Dockerfile uses npm start"
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

echo "==> 4) Force Express to bind 0.0.0.0 and add /health"
INDEX="services/profile/src/index.ts"
if [ -f "$INDEX" ]; then
  # add /health if missing
  if ! grep -q '"/health"' "$INDEX" && ! grep -q "'/health'" "$INDEX"; then
    perl -0777 -i -pe 's/(app\.use\([^\n]*profileRoutes\);\s*)/$1\napp.get(\"\\/health\", (_req, res) => res.status(200).send(\"ok\"));\n/s' "$INDEX"
  fi

  # enforce listen(host)
  # Replace: app.listen(port, async () => { ... })
  # With: app.listen(port, "0.0.0.0", async () => { ... })
  perl -0777 -i -pe 's/app\.listen\(\s*(port)\s*,\s*async\s*\(/app.listen($1, \"0.0.0.0\", async(/s' "$INDEX"
  perl -0777 -i -pe 's/app\.listen\(\s*(port)\s*,\s*\(/app.listen($1, \"0.0.0.0\", (/s' "$INDEX"
else
  echo "WARN: $INDEX not found"
fi

echo "==> 5) Rebuild + restart"
docker-compose down -v
docker-compose build --no-cache profile-service gateway
docker-compose up -d

echo "==> 6) Verify containers"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "==> 7) Verify profile-service listens internally"
docker-compose exec -T profile-service sh -lc 'node -e "console.log(\"node up\")" && (netstat -lntp 2>/dev/null || ss -lntp 2>/dev/null || true)'

echo "==> 8) Verify from gateway: DNS + health"
docker-compose exec -T gateway sh -lc 'getent hosts profile-service && wget -qO- http://profile-service:4001/health'
echo
echo "✅ If you see 'ok' above, refresh http://localhost:8080/profile and Save Changes again."
