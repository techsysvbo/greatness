#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

MW="services/profile/src/middleware/authMiddleware.ts"

if [ ! -f "$MW" ]; then
  echo "ERROR: $MW not found"
  exit 1
fi

echo "==> Patching profile auth middleware to allow DISABLE_AUTH=true"
python3 - <<'PY'
import re
p="services/profile/src/middleware/authMiddleware.ts"
s=open(p,"r",encoding="utf-8").read()

# If already has DISABLE_AUTH, skip
if "DISABLE_AUTH" in s:
    print("Already patched:", p)
else:
    # Insert bypass at start of middleware function
    # Works for: export const authMiddleware = (req, res, next) => { ... }
    s=re.sub(
        r'(export\s+const\s+authMiddleware\s*=\s*\(\s*req\s*:\s*AuthRequest\s*,\s*res\s*:\s*Response\s*,\s*next\s*:\s*NextFunction\s*\)\s*=>\s*\{)',
        r'\1\n  if (process.env.DISABLE_AUTH === "true") {\n    // Dev bypass: attach a fake user\n    req.user = req.user || { id: 1, email: "dev@local" };\n    return next();\n  }\n',
        s
    )
    # Also handle non-typed versions
    s=re.sub(
        r'(export\s+const\s+authMiddleware\s*=\s*\(\s*req\s*,\s*res\s*,\s*next\s*\)\s*=>\s*\{)',
        r'\1\n  if (process.env.DISABLE_AUTH === "true") {\n    req.user = req.user || { id: 1 };\n    return next();\n  }\n',
        s
    )

    open(p,"w",encoding="utf-8").write(s)
    print("Patched:", p)
PY

echo "==> Enabling DISABLE_AUTH=true for profile-service in docker-compose.override.yml"
python3 - <<'PY'
import yaml, os
p="docker-compose.override.yml"
d={}
if os.path.exists(p):
    d=yaml.safe_load(open(p,"r",encoding="utf-8")) or {}
d.setdefault("services", {})
d["services"].setdefault("profile-service", {})
env=d["services"]["profile-service"].get("environment", {})
if isinstance(env, list):
    # convert list->dict
    new={}
    for item in env:
        if "=" in item:
            k,v=item.split("=",1)
            new[k]=v
    env=new
env["DISABLE_AUTH"]="true"
d["services"]["profile-service"]["environment"]=env
open(p,"w",encoding="utf-8").write(yaml.safe_dump(d,sort_keys=False))
print("Wrote",p)
PY

echo "==> Rebuild + restart profile-service (only)"
docker-compose build --no-cache profile-service
docker-compose up -d profile-service

echo "✅ Dev auth bypass enabled for profile-service."
echo "Now refresh http://localhost:8080/profile and Save Changes should work."
