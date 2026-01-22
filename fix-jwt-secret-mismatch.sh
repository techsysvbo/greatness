#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

# Choose ONE secret for dev (same for all services)
JWT_SECRET_VALUE="dev_secret_key_change_me1010"

echo "==> 1) Set JWT_SECRET for auth-service + profile-service in docker-compose.override.yml"
python3 - <<PY
import yaml, os

p="docker-compose.override.yml"
d={}
if os.path.exists(p):
    d=yaml.safe_load(open(p,"r",encoding="utf-8")) or {}
d.setdefault("services", {})

for svc in ["auth-service","profile-service"]:
    d["services"].setdefault(svc, {})
    env=d["services"][svc].get("environment", {})
    if isinstance(env, list):
        # list -> dict
        new={}
        for item in env:
            if "=" in item:
                k,v=item.split("=",1)
                new[k]=v
        env=new
    env["JWT_SECRET"]="${JWT_SECRET_VALUE}"
    d["services"][svc]["environment"]=env

open(p,"w",encoding="utf-8").write(yaml.safe_dump(d,sort_keys=False))
print("Wrote",p)
PY

echo "==> 2) Rebuild + restart auth-service and profile-service"
docker-compose down
docker-compose up -d --build auth-service profile-service gateway

echo "==> 3) Verify: login -> token -> profile PUT should be 200"
EMAIL="tech3ceo2026@proton.me"
PASS="Passw0rd1237"

TOKEN="$(curl -s http://localhost:8080/api/auth/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"

echo "TOKEN length: ${#TOKEN}"
if [ "${#TOKEN}" -lt 50 ]; then
  echo "ERROR: Could not obtain token from login response."
  exit 1
fi

echo "==> Profile update test"
curl -i -X PUT http://localhost:8080/api/profile/profile/me \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"display_name":"Victor Otu","profession":"Software Engineer","country":"United States","state":"MD","city":"Bethesda","zip_code":"20815"}' \
  | head -n 25
