#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Find auth entry file"
ENTRY=""
for f in services/auth/src/index.ts services/auth/src/server.ts services/auth/src/app.ts; do
  if [ -f "$f" ]; then ENTRY="$f"; break; fi
done
if [ -z "$ENTRY" ]; then
  echo "ERROR: could not find services/auth/src/index.ts|server.ts|app.ts"
  exit 1
fi
echo "Auth entry: $ENTRY"

echo "==> 2) Extract app.use mount prefixes that point to auth routes"
# We look for app.use('/something', somethingRoutes/router)
# and collect likely prefixes containing 'auth'
PREFIXES="$(grep -Eo "app\.use\(['\"][^'\"]+['\"],[^)]*\)" "$ENTRY" \
  | sed -E "s/app\.use\(['\"]([^'\"]+)['\"].*/\1/" \
  | sort -u)"

# Add common defaults too
PREFIXES="$PREFIXES
/auth
/api/auth
/v1/auth
"

# de-dup + remove empty
PREFIXES="$(echo "$PREFIXES" | sed '/^\s*$/d' | sort -u)"

echo "Candidate prefixes:"
echo "$PREFIXES"
echo

echo "==> 3) Extract router.post endpoints from auth route files"
ROUTE_POSTS="$(grep -R --no-messages -nE "router\.post\(['\"][^'\"]+['\"]" services/auth/src \
  | sed -E "s/.*router\.post\(['\"]([^'\"]+)['\"].*/\1/" \
  | sort -u)"

# If none found, also scan app.post
if [ -z "$ROUTE_POSTS" ]; then
  ROUTE_POSTS="$(grep -R --no-messages -nE "app\.post\(['\"][^'\"]+['\"]" services/auth/src \
    | sed -E "s/.*app\.post\(['\"]([^'\"]+)['\"].*/\1/" \
    | sort -u)"
fi

if [ -z "$ROUTE_POSTS" ]; then
  echo "ERROR: could not find any router.post or app.post endpoints in services/auth/src"
  exit 1
fi

echo "Candidate POST endpoints (router/app-level):"
echo "$ROUTE_POSTS"
echo

echo "==> 4) Probe combinations of prefix + endpoint on auth-service:4000"
docker-compose up -d db redis auth-service gateway
sleep 2

PAYLOAD='{"username":"victor_test","email":"victor_test@example.com","password":"Passw0rd!"}'

WORKING_REGISTER=""
WORKING_LOGIN=""

set +e
for prefix in $PREFIXES; do
  for ep in $ROUTE_POSTS; do
    full="$prefix$ep"
    # normalize double slashes
    full="$(echo "$full" | sed -E 's#//#/#g')"
    echo "--- PROBE POST $full"
    OUT="$(docker-compose exec -T gateway sh -lc \
      "wget -S -qO- --header='Content-Type: application/json' --post-data='$PAYLOAD' http://auth-service:4000$full 2>&1")"
    echo "$OUT" | head -n 6
    echo

    # Identify likely register/login based on path name + status not 404
    if echo "$OUT" | grep -qE "HTTP/1\.1 (200|201|400|409|422)" && ! echo "$OUT" | grep -q "404 Not Found"; then
      if echo "$full" | grep -qiE "register|signup"; then
        WORKING_REGISTER="$full"
      fi
      if echo "$full" | grep -qiE "login|signin"; then
        WORKING_LOGIN="$full"
      fi
    fi

    # stop early if we found register and login
    if [ -n "$WORKING_REGISTER" ] && [ -n "$WORKING_LOGIN" ]; then
      break 2
    fi
  done
done
set -e

echo "Detected register endpoint: ${WORKING_REGISTER:-NONE}"
echo "Detected login endpoint:    ${WORKING_LOGIN:-NONE}"

if [ -z "$WORKING_REGISTER" ] && [ -z "$WORKING_LOGIN" ]; then
  echo
  echo "ERROR: No working auth endpoints found."
  echo "This usually means auth-service routes are not mounted or the server is only serving health."
  echo "Next: print auth-service route wiring from dist/index.js."
  exit 1
fi

echo "==> 5) Patch client to use detected endpoints (through gateway /api/auth/*)"
# Gateway currently proxies /api/auth/* -> auth-service root /
# So client should call /api/auth + (path after /api/auth).
# If your WORKING_REGISTER already starts with /api/auth, strip it.
python3 - <<PY
import pathlib

reg="${WORKING_REGISTER}"
log="${WORKING_LOGIN}"

def to_gateway(path: str) -> str:
  if not path: return path
  # if already /api/auth/... keep it
  if path.startswith("/api/auth/"): return path
  # otherwise map to /api/auth + path
  return "/api/auth" + path

reg_target = to_gateway(reg) if reg else ""
log_target = to_gateway(log) if log else ""

root = pathlib.Path("client/src")
patterns_reg = ["/api/auth/register","/api/auth/signup","/auth/register","/auth/signup","/register","/signup"]
patterns_log = ["/api/auth/login","/api/auth/signin","/auth/login","/auth/signin","/login","/signin"]

changed=0
for p in root.rglob("*"):
  if p.suffix.lower() in [".ts",".tsx",".js",".jsx"]:
    s=p.read_text(encoding="utf-8")
    orig=s
    if reg_target:
      for pat in patterns_reg:
        s=s.replace(pat, reg_target)
    if log_target:
      for pat in patterns_log:
        s=s.replace(pat, log_target)
    if s!=orig:
      p.write_text(s,encoding="utf-8")
      changed+=1

print("Patched client files:", changed)
print("Register endpoint =>", reg_target or "UNCHANGED")
print("Login endpoint    =>", log_target or "UNCHANGED")
PY

echo "==> 6) Rebuild client + gateway and restart"
docker-compose build --no-cache client gateway
docker-compose up -d client gateway

echo "✅ Done. Try Register/Login in the browser again."
