#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Patch client: UI navigation must NEVER point to /api/*"
python3 - <<'PY'
import pathlib, re

root = pathlib.Path("client/src")
if not root.exists():
    raise SystemExit("ERROR: client/src not found")

# Replace any UI link destinations that mistakenly use API URLs
# This fixes navbar links, Link to=, navigate(), hrefs, etc.
ui_rewrites = [
    (r'(["\'])/api/auth/auth/login\1', r'\1/login\1'),
    (r'(["\'])/api/auth/auth/register\1', r'\1/register\1'),
    (r'(["\'])/api/auth/auth/signup\1', r'\1/register\1'),
    (r'(["\'])/api/auth/auth/signin\1', r'\1/login\1'),

    (r'(["\'])/api/auth/login\1', r'\1/login\1'),
    (r'(["\'])/api/auth/register\1', r'\1/register\1'),
    (r'(["\'])/api/auth/signup\1', r'\1/register\1'),
    (r'(["\'])/api/auth/signin\1', r'\1/login\1'),

    (r'(["\'])/auth/login\1', r'\1/login\1'),
    (r'(["\'])/auth/register\1', r'\1/register\1'),
]

# Also fix React Router route definitions if they were accidentally changed to API paths
route_rewrites = [
    (r'path=\s*["\']/api/auth/auth/login["\']', 'path="/login"'),
    (r'path=\s*["\']/api/auth/auth/register["\']', 'path="/register"'),
    (r'path=\s*["\']/api/auth/login["\']', 'path="/login"'),
    (r'path=\s*["\']/api/auth/register["\']', 'path="/register"'),
    (r'path=\s*["\']/auth/login["\']', 'path="/login"'),
    (r'path=\s*["\']/auth/register["\']', 'path="/register"'),
]

patched_files = []

for p in root.rglob("*"):
    if p.suffix.lower() not in [".ts",".tsx",".js",".jsx"]:
        continue
    s = p.read_text(encoding="utf-8")
    orig = s

    for pat, rep in ui_rewrites:
        s = re.sub(pat, rep, s)

    for pat, rep in route_rewrites:
        s = re.sub(pat, rep, s)

    # If a file contains repeated /api/auth/.../api/auth/... fix the duplication
    s = re.sub(r"/api/auth(/api/auth)+", "/api/auth", s)

    if s != orig:
        p.write_text(s, encoding="utf-8")
        patched_files.append(str(p))

print(f"Patched {len(patched_files)} files.")
if patched_files:
    print("Examples:")
    for f in patched_files[:15]:
        print(" -", f)
PY

echo "==> 2) Ensure the API calls remain correct (do NOT change API endpoints)"
# We DO NOT touch API endpoints here; they’re already correct.
# Your backend expects:
#   POST /api/auth/auth/login
#   POST /api/auth/auth/register
#   PUT  /api/profile/profile/me

echo "==> 3) Rebuild + restart client and gateway"
docker-compose build --no-cache client gateway
docker-compose up -d client gateway

echo
echo "✅ Done."
echo "Now test ONLY these UI routes in browser:"
echo "  http://localhost:8080/login"
echo "  http://localhost:8080/register"
echo "  http://localhost:8080/profile"
echo
echo "Do NOT browse to API endpoints in the address bar (/api/auth/...)."
