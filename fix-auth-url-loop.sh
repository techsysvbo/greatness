#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Force client VITE_API_URL to /api (NOT /api/auth)"
python3 - <<'PY'
import yaml
p="docker-compose.yml"
d=yaml.safe_load(open(p,"r",encoding="utf-8"))
svc=d.get("services",{}).get("client",{})
env=svc.get("environment",{})
if isinstance(env,list):
    # list -> dict
    nd={}
    for item in env:
        if "=" in item:
            k,v=item.split("=",1)
            nd[k]=v
    env=nd
env["VITE_API_URL"]="/api"
svc["environment"]=env
d["services"]["client"]=svc
open(p,"w",encoding="utf-8").write(yaml.safe_dump(d,sort_keys=False))
print("Updated client env VITE_API_URL=/api in docker-compose.yml")
PY

echo "==> 2) Patch client source to stop duplicating /api/auth"
# Replace any accidental base usage /api/auth -> /api
python3 - <<'PY'
import pathlib, re

root=pathlib.Path("client/src")
changed=0

for p in root.rglob("*"):
    if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
        s=p.read_text(encoding="utf-8")
        orig=s

        # If code uses base "/api/auth" as API base, normalize to "/api"
        s=s.replace('"/api/auth"', '"/api"')
        s=s.replace("'/api/auth'", "'/api'")
        s=s.replace("`/api/auth`", "`/api`")

        # Fix over-prefixed paths like /api/auth/api/auth/... -> /api/auth/...
        s=re.sub(r"/api/auth(/api/auth)+", "/api/auth", s)

        # Make auth calls use /auth/* (because gateway maps /api/auth/* -> auth-service root)
        # Client should call: /api/auth/auth/register? No—client base should be /api, then endpoint /auth/register.
        # So client should call: ${VITE_API_URL}/auth/register => /api/auth/register through gateway.
        # But since auth-service mount is /auth, we want /api/auth/auth/register at gateway.
        # Therefore endpoint in client should be /auth/register and base should be /api/auth (gateway prefix).
        # To avoid confusion, we standardize: base "/api/auth" and endpoint "/auth/register".
        # However you already use VITE_API_URL for base (/api). So:
        # Base "/api" + endpoint "/auth/register" => /api/auth/register (missing /auth mount).
        # Better: base "/api/auth" + endpoint "/auth/register" => /api/auth/auth/register ✅
        #
        # So we will standardize base as "/api/auth" in api client file, and set VITE_API_URL="/api/auth".
        #
        # BUT your duplication bug came from base "/api/auth" being concatenated multiple times.
        # So we do it the safest way:
        # - Keep VITE_API_URL="/api"
        # - Hardcode auth calls to "/api/auth/auth/register" and "/api/auth/auth/login"
        #
        # Replace common wrong endpoints:
        for pat in ["/api/auth/register","/api/auth/signup","/auth/register","/register","/signup"]:
            s=s.replace(pat, "/api/auth/auth/register")
        for pat in ["/api/auth/login","/api/auth/signin","/auth/login","/login","/signin"]:
            s=s.replace(pat, "/api/auth/auth/login")

        if s!=orig:
            p.write_text(s,encoding="utf-8")
            changed += 1

print("Patched",changed,"client files.")
PY

echo "==> 3) Rebuild and restart client + gateway"
docker-compose build --no-cache client gateway
docker-compose up -d client gateway

echo "==> 4) Quick verification: auth route should NOT be duplicated anymore"
echo "Try in browser: http://localhost:8080 (register page)."
echo "Expected POST target through gateway is /api/auth/auth/register"
