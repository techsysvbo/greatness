#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

FILE=$(grep -R --no-messages -n "jwt\.sign" services/auth/src | head -n 1 | cut -d: -f1)
if [ -z "$FILE" ]; then
  echo "ERROR: jwt.sign not found in services/auth/src"
  exit 1
fi

echo "Patching JWT expiry in: $FILE"

python3 - <<PY
import re
p="$FILE"
s=open(p,"r",encoding="utf-8").read()
orig=s

# Replace existing expiresIn if present
s=re.sub(r'expiresIn\s*:\s*[\'"][^\'"]+[\'"]', 'expiresIn: "7d"', s)

# If no expiresIn anywhere, try to add options to jwt.sign(payload, secret)
if "expiresIn" not in s:
    s=re.sub(r'jwt\.sign\(\s*([^\),]+)\s*,\s*([^\),]+)\s*\)',
             r'jwt.sign(\1, \2, { expiresIn: "7d" })', s)

open(p,"w",encoding="utf-8").write(s)

print("Updated" if s!=orig else "No change made (jwt.sign pattern may differ)")
PY

docker-compose build --no-cache auth-service
docker-compose up -d auth-service gateway profile-service
echo "Done."
