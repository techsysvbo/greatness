#!/usr/bin/env bash
set -euo pipefail

cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 0) Ensure ripgrep exists"
command -v rg >/dev/null 2>&1 || { echo "ripgrep (rg) not found. Install it: sudo apt-get update && sudo apt-get install -y ripgrep"; exit 1; }

echo "==> 1) Fix Navbar/UI links (never link to /api/*)"
# Replace any href/to pointing to API endpoints with UI routes
python3 - <<'PY'
import pathlib, re

root = pathlib.Path("client/src")
patched = 0

def patch_text(s: str) -> str:
    # UI navigation must be /login and /register only
    s = re.sub(r'(["\'])/api/auth[^"\']*/login\1', r'\1/login\1', s)
    s = re.sub(r'(["\'])/api/auth[^"\']*/register\1', r'\1/register\1', s)
    s = re.sub(r'(["\'])/api/auth[^"\']*/signin\1', r'\1/login\1', s)
    s = re.sub(r'(["\'])/api/auth[^"\']*/signup\1', r'\1/register\1', s)

    # Also stop linking to /auth/* (server mount) as UI
    s = re.sub(r'(["\'])/auth/login\1', r'\1/login\1', s)
    s = re.sub(r'(["\'])/auth/register\1', r'\1/register\1', s)

    # Prevent accidental duplicated prefixes in any string literal
    s = re.sub(r'/api/auth(/api/auth)+', '/api/auth', s)
    return s

for p in root.rglob("*"):
    if p.suffix.lower() not in [".ts",".tsx",".js",".jsx"]:
        continue
    txt = p.read_text(encoding="utf-8")
    out = patch_text(txt)
    if out != txt:
        p.write_text(out, encoding="utf-8")
        patched += 1

print("Patched UI links in", patched, "files")
PY

echo "==> 2) Force login/register API endpoints in client source"
python3 - <<'PY'
import pathlib, re

root = pathlib.Path("client/src")
AUTH_LOGIN = "/api/auth/auth/login"
AUTH_REGISTER = "/api/auth/auth/register"

patched = 0

def patch_api(s: str) -> str:
    # Replace any register endpoints with correct one
    for pat in ["/api/auth/register","/api/auth/signup","/auth/register","/register","/signup"]:
        s = s.replace(pat, AUTH_REGISTER)
    # Replace any login endpoints with correct one
    for pat in ["/api/auth/login","/api/auth/signin","/auth/login","/login","/signin"]:
        s = s.replace(pat, AUTH_LOGIN)
    # Deduplicate
    s = re.sub(r'/api/auth(/api/auth)+', '/api/auth', s)
    return s

for p in root.rglob("*"):
    if p.suffix.lower() not in [".ts",".tsx",".js",".jsx"]:
        continue
    txt = p.read_text(encoding="utf-8")
    out = patch_api(txt)
    if out != txt:
        p.write_text(out, encoding="utf-8")
        patched += 1

print("Patched API endpoints in", patched, "files")
PY

echo "==> 3) Improve Register UX: treat 409 as 'account exists' not generic failure"
# Patch Register page to show meaningful message for 409
REG=""
if [ -f client/src/pages/Register.tsx ]; then REG="client/src/pages/Register.tsx"; fi
if [ -z "$REG" ] && [ -f client/src/pages/Register.jsx ]; then REG="client/src/pages/Register.jsx"; fi

if [ -n "$REG" ]; then
  python3 - <<PY
import re
p="${REG}"
s=open(p,"r",encoding="utf-8").read()
orig=s

# If code does fetch/axios and then "Registration failed", add 409 handling best-effort
# We look for `if (!res.ok)` patterns in fetch flows
s=re.sub(
r'if\s*\(\s*!\s*res\.ok\s*\)\s*\{[^}]*Registration failed[^}]*\}',
"""if (!res.ok) {
        if (res.status === 409) {
          setError("Account already exists. Please login instead.");
          return;
        }
        const msg = data?.message || data?.error || "Registration failed. Check console for details.";
        setError(msg);
        return;
      }""",
s,
flags=re.S
)

# If axios, handle err.response.status === 409
if "axios" in s and "setError" in s and "409" not in s:
    s=s.replace(
        'setError("Registration failed. Check console for details.");',
        'if (err?.response?.status === 409) { setError("Account already exists. Please login instead."); } else { setError("Registration failed. Check console for details."); }'
    )

if s != orig:
    open(p,"w",encoding="utf-8").write(s)
    print("Patched 409 handling in", p)
else:
    print("No changes needed or pattern not found in", p)
PY
else
  echo "WARN: Register page not found at client/src/pages/Register.(tsx|jsx)"
fi

echo "==> 4) Rebuild + restart client + gateway (force new bundle)"
docker-compose build --no-cache client gateway
docker-compose up -d --force-recreate client gateway

echo
echo "✅ DONE."
echo "Now use ONLY these UI URLs:"
echo "  http://localhost:8080/login"
echo "  http://localhost:8080/register"
echo
echo "Do NOT browse to API URLs like /api/auth/auth/login in the address bar."
