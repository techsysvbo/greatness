#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Fix client navigation: NEVER link to /api/* for pages"
python3 - <<'PY'
import pathlib, re
root = pathlib.Path("client/src")
changed = 0

# Replace any Link/to/href that points to API endpoints with UI routes
repls = [
  (r'(["\'])/api/auth/auth/login\1', r'\1/login\1'),
  (r'(["\'])/api/auth/auth/register\1', r'\1/register\1'),
  (r'(["\'])/api/auth/[^"\']*login\1', r'\1/login\1'),
  (r'(["\'])/api/auth/[^"\']*register\1', r'\1/register\1'),
  (r'(["\'])/auth/login\1', r'\1/login\1'),
  (r'(["\'])/auth/register\1', r'\1/register\1'),
]

for p in root.rglob("*"):
  if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
    s = p.read_text(encoding="utf-8")
    orig = s
    for pat, rep in repls:
      s = re.sub(pat, rep, s)
    if s != orig:
      p.write_text(s, encoding="utf-8")
      changed += 1

print("Patched UI navigation in", changed, "files")
PY

echo "==> 2) Fix client API endpoints (auth + profile)"
python3 - <<'PY'
import pathlib
root = pathlib.Path("client/src")

AUTH_LOGIN="/api/auth/auth/login"
AUTH_REGISTER="/api/auth/auth/register"
PROFILE_ME="/api/profile/profile/me"

reg_pats=["/api/auth/register","/api/auth/signup","/auth/register","/register","/signup"]
log_pats=["/api/auth/login","/api/auth/signin","/auth/login","/login","/signin"]
profile_pats=["/api/profile/me","/profile/me","/api/profile/profile/me"]

changed=0
for p in root.rglob("*"):
  if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
    s=p.read_text(encoding="utf-8")
    orig=s
    for pat in reg_pats: s=s.replace(pat, AUTH_REGISTER)
    for pat in log_pats: s=s.replace(pat, AUTH_LOGIN)
    for pat in profile_pats: s=s.replace(pat, PROFILE_ME)
    if s!=orig:
      p.write_text(s,encoding="utf-8")
      changed+=1

print("Patched API endpoints in",changed,"files")
print("Auth register:",AUTH_REGISTER)
print("Auth login:   ",AUTH_LOGIN)
print("Profile me:   ",PROFILE_ME)
PY

echo "==> 3) Fix profile-service auth middleware to accept JWT {userId}"
MW="services/profile/src/middleware/authMiddleware.ts"
if [ ! -f "$MW" ]; then
  echo "ERROR: $MW not found"
  exit 1
fi

python3 - <<'PY'
import re
p="services/profile/src/middleware/authMiddleware.ts"
s=open(p,"r",encoding="utf-8").read()

# Force mapping decoded.userId -> id
# Replace any line like: const id = decoded.id ?? decoded.userId;
# If not present, inject a robust mapping.
if "decoded.userId" not in s:
    # Very defensive insertion near decode
    s=re.sub(r'(const\s+decoded[^;]*;\s*)',
             r'\1\n    const uid = (decoded as any).userId ?? (decoded as any).id;\n',
             s, count=1)
# Ensure we set req.user.id from uid
if "req.user" in s and "Number(id)" in s:
    s=s.replace("Number(id)", "Number((decoded as any).userId ?? (decoded as any).id)")
elif "req.user" in s and "id:" in s and "decoded" in s:
    s=re.sub(r'id\s*:\s*Number\([^)]+\)', 'id: Number((decoded as any).userId ?? (decoded as any).id)', s)

# Also improve the error message so you see token claims if missing
if "token missing id/userId" not in s:
    s=s.replace("Unauthorized: token missing id/userId",
                "Unauthorized: token missing userId (expected JWT payload {userId})")

open(p,"w",encoding="utf-8").write(s)
print("Patched:",p)
PY

echo "==> 4) Rebuild + restart client, profile-service, gateway"
docker-compose build --no-cache client profile-service gateway
docker-compose up -d client profile-service gateway

echo "==> 5) Verify: login works and profile PUT works (using your test user)"
EMAIL="tech3ceo2026@proton.me"
PASS="Passw0rd1237"

TOKEN="$(curl -s -X POST http://localhost:8080/api/auth/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token',''))")"

if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not obtain token via login API."
  exit 1
fi
echo "Got token (length ${#TOKEN})"

echo "==> Profile update test"
curl -i -X PUT http://localhost:8080/api/profile/profile/me \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"display_name":"Victor Otu","profession":"Software Engineer","country":"United States","state":"MD","city":"Bethesda","zip_code":"20815"}' \
  | head -n 30

echo
echo "✅ If you see HTTP/1.1 200 OK above, profile updates are fixed."
echo "Now use UI routes:"
echo "  http://localhost:8080/login"
echo "  http://localhost:8080/register"
echo "  http://localhost:8080/profile"
