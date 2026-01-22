#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Ensure DB columns exist (zip_code, country, state, city, display_name, profession)"
docker-compose up -d db
sleep 2
docker-compose exec -T db psql -U admin -d diaspora_db <<'SQL'
CREATE TABLE IF NOT EXISTS profiles (
  user_id INTEGER PRIMARY KEY,
  display_name VARCHAR(255),
  bio TEXT,
  location VARCHAR(255),
  zip_code VARCHAR(20),
  profession VARCHAR(255),
  interests TEXT,
  privacy_settings JSONB,
  country VARCHAR(100),
  state VARCHAR(100),
  city VARCHAR(100),
  updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name VARCHAR(255);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS profession VARCHAR(255);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS state VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS zip_code VARCHAR(20);
SQL

echo "==> 2) Patch Profile UI: correct endpoint + always attach Authorization + show real error"
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

# Ensure correct endpoint is used
s=s.replace("/api/profile/me", "/api/profile/profile/me")
s=s.replace('"/profile/me"', '"/api/profile/profile/me"')
s=s.replace("'/profile/me'", "'/api/profile/profile/me'")

# Ensure token is attached for fetch flows (fallback)
if "fetch(" in s:
    # add token variable near handleSubmit (best-effort)
    if "handleSubmit" in s and "localStorage.getItem(\"token\")" not in s:
        s=re.sub(r'(async\s+function\s+handleSubmit\([^\)]*\)\s*\{)',
                 r'\1\n    const token = localStorage.getItem("token");\n',
                 s)
    # inject Authorization header into JSON headers block
    s=re.sub(r'headers\s*:\s*\{\s*["\']Content-Type["\']\s*:\s*["\']application/json["\']\s*\}',
             'headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }',
             s)

# Upgrade alert/error message to show backend response
s=s.replace('alert("Failed to update profile")',
            'alert(data?.message || data?.error || data?.detail || JSON.stringify(data) || "Failed to update profile")')

open(p,"w",encoding="utf-8").write(s)
print("Patched", p)
PY

echo "==> 3) Add request logging in profile-service so we can SEE the requests arrive"
INDEX="services/profile/src/index.ts"
if [ -f "$INDEX" ]; then
  python3 - <<'PY'
import re
p="services/profile/src/index.ts"
s=open(p,"r",encoding="utf-8").read()
if "[REQ]" not in s:
    s=re.sub(r'(app\.use\(express\.json\(\)\);\s*)',
             r'\1\napp.use((req, _res, next) => {\n  console.log(`[REQ] ${req.method} ${req.url} auth=${req.headers.authorization ? "yes" : "no"}`);\n  next();\n});\n',
             s)
open(p,"w",encoding="utf-8").write(s)
print("Patched request logger in", p)
PY
fi

echo "==> 4) Rebuild + restart (client + profile-service + gateway)"
docker-compose build --no-cache client profile-service gateway
docker-compose up -d --force-recreate client profile-service gateway

echo
echo "✅ Done."
echo "Now: login in the UI, go to /profile, click Save Changes."
echo "Then run: docker-compose logs --tail=120 profile-service"
