#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/techs/OneDrive/Desktop/ag-workspace"
cd "$ROOT"

INDEX="services/profile/src/index.ts"
if [ ! -f "$INDEX" ]; then
  echo "ERROR: $INDEX not found"
  exit 1
fi

echo "==> Fixing TypeScript port type (string -> number) in $INDEX"

# Ensure a numeric port and bind to 0.0.0.0
python3 - <<'PY'
import re
p="services/profile/src/index.ts"
s=open(p,"r",encoding="utf-8").read()

# Replace common patterns:
# const port = process.env.PORT || 4001;
s=re.sub(r'const\s+port\s*=\s*process\.env\.PORT\s*\|\|\s*4001\s*;',
         'const port = Number(process.env.PORT || 4001);', s)

# If PORT is something else, still enforce number conversion
s=re.sub(r'const\s+port\s*=\s*process\.env\.PORT\s*\|\|\s*(\d+)\s*;',
         r'const port = Number(process.env.PORT || \1);', s)

# Ensure health endpoint exists
if '/health' not in s:
  s=re.sub(r'(app\.use\([^\n]*profileRoutes\);\s*)',
           r'\1\napp.get("/health", (_req, res) => res.status(200).send("ok"));\n',
           s, flags=re.M)

# Ensure listen binds to 0.0.0.0 (only if it isn't already)
if ',"0.0.0.0"' not in s and ', "0.0.0.0"' not in s:
  s=re.sub(r'app\.listen\(\s*port\s*,\s*async\s*\(',
           'app.listen(port, "0.0.0.0", async(', s)
  s=re.sub(r'app\.listen\(\s*port\s*,\s*\(',
           'app.listen(port, "0.0.0.0", (', s)

open(p,"w",encoding="utf-8").write(s)
print("patched",p)
PY

echo "==> Rebuild and restart stack"
docker-compose down -v
docker-compose build --no-cache profile-service gateway
docker-compose up -d

echo "==> Verify containers"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "==> Verify /health from inside gateway"
docker-compose exec -T gateway sh -lc 'getent hosts profile-service && wget -qO- http://profile-service:4001/health'
echo
echo "✅ If you see 'ok' above, refresh http://localhost:8080/profile and try Save Changes."
