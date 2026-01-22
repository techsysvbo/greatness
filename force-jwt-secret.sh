#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

JWT_SECRET_VALUE="dev_secret_key_change_me1010"

python3 - <<PY
import yaml
p="docker-compose.yml"
d=yaml.safe_load(open(p,"r",encoding="utf-8"))
svc=d["services"]

for name in ["auth-service","profile-service"]:
    env=svc[name].get("environment", {})
    if isinstance(env, list):
        new={}
        for item in env:
            if "=" in item:
                k,v=item.split("=",1)
                new[k]=v
        env=new
    env["JWT_SECRET"]="${JWT_SECRET_VALUE}"
    svc[name]["environment"]=env

d["services"]=svc
open(p,"w",encoding="utf-8").write(yaml.safe_dump(d,sort_keys=False))
print("Set JWT_SECRET in docker-compose.yml for auth-service + profile-service")
PY

docker-compose down
docker-compose up -d --build auth-service profile-service gateway

echo "==> Verify JWT_SECRET now:"
docker-compose exec -T auth-service sh -lc 'echo "auth JWT_SECRET=$JWT_SECRET"'
docker-compose exec -T profile-service sh -lc 'echo "profile JWT_SECRET=$JWT_SECRET"'
