#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> Patching client routes and links to use UI paths (/login, /register)"
# 1) Fix App.tsx routes + redirects + navbar links
python3 - <<'PY'
from pathlib import Path
import re

p = Path("client/src/App.tsx")
s = p.read_text(encoding="utf-8")

# Redirect to UI login
s = s.replace('return <Navigate to="/api/auth/auth/login" />;', 'return <Navigate to="/login" />;')

# Navbar links
s = s.replace('<Link to="/api/auth/auth/login">Login</Link>', '<Link to="/login">Login</Link>')
s = s.replace('<Link to="/api/auth/auth/register">Register</Link>', '<Link to="/register">Register</Link>')

# Routes
s = s.replace('<Route path="/api/auth/auth/login" element={<Login />} />', '<Route path="/login" element={<Login />} />')
s = s.replace('<Route path="/api/auth/auth/register" element={<Register />} />', '<Route path="/register" element={<Register />} />')

p.write_text(s, encoding="utf-8")
print("Patched", p)
PY

echo "==> Fix Login/Register page links (UI links, not API paths)"
python3 - <<'PY'
from pathlib import Path

login = Path("client/src/pages/Login.tsx")
if login.exists():
    s = login.read_text(encoding="utf-8")
    s = s.replace('to="/api/auth/auth/register"', 'to="/register"')
    login.write_text(s, encoding="utf-8")
    print("Patched", login)

reg = Path("client/src/pages/Register.tsx")
if reg.exists():
    s = reg.read_text(encoding="utf-8")
    s = s.replace('to="/api/auth/auth/login"', 'to="/login"')
    reg.write_text(s, encoding="utf-8")
    print("Patched", reg)
PY

echo "==> Fix Home page CTA links"
python3 - <<'PY'
from pathlib import Path
home = Path("client/src/pages/Home.tsx")
if home.exists():
    s = home.read_text(encoding="utf-8")
    s = s.replace('to="/api/auth/auth/register"', 'to="/register"')
    s = s.replace('to="/api/auth/auth/login"', 'to="/login"')
    home.write_text(s, encoding="utf-8")
    print("Patched", home)
PY

echo "==> Fix AuthContext: use correct API paths (relative to gateway /api)"
# Best practice: AuthContext should call /api/auth/auth/login and /api/auth/auth/register using fetch
# so it doesn't double-prefix through api.ts.
python3 - <<'PY'
from pathlib import Path
import re

p = Path("client/src/context/AuthContext.tsx")
s = p.read_text(encoding="utf-8")

# Replace api.post('/api/auth/auth/login' ...) with fetch('/api/auth/auth/login' ...)
# Minimal patch: keep axios api client if you want, but make path correct and consistent.
s = s.replace("api.post('/api/auth/auth/login'", "api.post('/auth/auth/login'")
s = s.replace("api.post('/api/auth/auth/register'", "api.post('/auth/auth/register'")

# This assumes your axios baseURL is /api (as in docker-compose env).
# /auth/auth/login => /api/auth/auth/login ✅

p.write_text(s, encoding="utf-8")
print("Patched", p)
PY

echo "==> Rebuild + restart client + gateway (force new bundle)"
docker-compose build --no-cache client gateway
docker-compose up -d --force-recreate client gateway

echo
echo "✅ Client routing fixed."
echo "Now open:"
echo "  http://localhost:8080/login"
echo "  http://localhost:8080/register"
echo
echo "Important: Hard refresh your browser (Ctrl+Shift+R)."
