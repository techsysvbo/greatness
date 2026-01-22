#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Patch AuthContext to store token under a known key and attach it to axios"
CTX="client/src/context/AuthContext.tsx"
if [ ! -f "$CTX" ]; then
  echo "ERROR: $CTX not found"
  exit 1
fi

python3 - <<'PY'
import re
p="client/src/context/AuthContext.tsx"
s=open(p,"r",encoding="utf-8").read()
orig=s

# Ensure token is stored in localStorage as "token"
# Look for localStorage.setItem(...) and normalize key
s=re.sub(r'localStorage\.setItem\(\s*["\'].*?["\']\s*,\s*token\s*\)', 'localStorage.setItem("token", token)', s)

# If no setItem exists at all, add after successful login extraction (best-effort)
if "localStorage.setItem" not in s and "token" in s:
    # Insert near "const token = response.data.token" if present
    s=re.sub(r'(const\s+token\s*=\s*response\.data\.token\s*;)',
             r'\1\n        localStorage.setItem("token", token);\n', s)

# Ensure axios api client attaches Authorization header if token exists
# If api.ts exists, patch there (preferred). Otherwise patch in AuthContext.
open(p,"w",encoding="utf-8").write(s)
print("Patched token storage in", p)
PY

API="client/src/services/api.ts"
if [ -f "$API" ]; then
  echo "==> 2) Patch api.ts axios client to always attach Authorization header"
  python3 - <<'PY'
import re
p="client/src/services/api.ts"
s=open(p,"r",encoding="utf-8").read()
orig=s

# Ensure baseURL is /api (so /profile/... maps to gateway)
# Only patch if baseURL exists and isn't /api
s=re.sub(r'baseURL\s*:\s*["\'][^"\']+["\']', 'baseURL: "/api"', s)

# Add interceptor if missing
if "interceptors.request.use" not in s:
    m=re.search(r'(const\s+(\w+)\s*=\s*axios\.create\([^;]*\);)', s, re.S)
    if m:
        full=m.group(1); var=m.group(2)
        insert=f"""{full}

{var}.interceptors.request.use((config) => {{
  const token = localStorage.getItem("token");
  if (token) {{
    config.headers = config.headers || {{}};
    config.headers.Authorization = `Bearer ${{token}}`;
  }}
  return config;
}});
"""
        s=s.replace(full, insert)

open(p,"w",encoding="utf-8").write(s)
print("Patched axios interceptor in", p)
PY
else
  echo "WARN: client/src/services/api.ts not found; profile page may use fetch instead."
fi

echo "==> 3) Force Profile page to call correct endpoint and show real error message"
PROF="client/src/pages/Profile.tsx"
if [ ! -f "$PROF" ]; then
  echo "ERROR: $PROF not found"
  exit 1
fi

python3 - <<'PY'
import re
p="client/src/pages/Profile.tsx"
s=open(p,"r",encoding="utf-8").read()
orig=s

# Ensure profile endpoint is correct
s=s.replace("/api/profile/me", "/api/profile/profile/me")
s=s.replace("/profile/me", "/api/profile/profile/me")

# If using api.put with wrong path, normalize
s=s.replace("'/api/profile/me'", "'/api/profile/profile/me'")
s=s.replace('"/api/profile/me"', '"/api/profile/profile/me"')

# Improve error handling: show response body
# Replace generic alert('Failed to update profile') if present
s=s.replace('alert("Failed to update profile")',
            'alert(data?.message || data?.error || data?.detail || JSON.stringify(data) || "Failed to update profile")')

# If using fetch, ensure Authorization header is attached as fallback
if "fetch(" in s and "Authorization" not in s:
    s=re.sub(r'headers\s*:\s*\{\s*["\']Content-Type["\']\s*:\s*["\']application/json["\']\s*\}',
             'headers: { "Content-Type": "application/json", ...(localStorage.getItem("token") ? { Authorization: `Bearer ${localStorage.getItem("token")}` } : {}) }',
             s)

open(p,"w",encoding="utf-8").write(s)
print("Patched", p)
PY

echo "==> 4) Rebuild and restart client + gateway"
docker-compose build --no-cache client gateway
docker-compose up -d --force-recreate client gateway

echo
echo "✅ Done."
echo "Now: login in UI, then go to /profile and Save Changes."
echo "If it fails, the alert will now show the real backend error."
