#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> 1) Show last auth-service errors (most important)"
docker-compose logs --tail=120 auth-service || true
echo

echo "==> 2) Verify DB is up"
docker-compose up -d db
sleep 2
docker-compose exec -T db psql -U admin -d diaspora_db -c "SELECT 1;" >/dev/null
echo "DB OK"
echo

echo "==> 3) Ensure users table exists (best-effort)"
# If your auth-service already creates schema on startup, this is harmless.
# If not, this unblocks registration.
docker-compose exec -T db psql -U admin -d diaspora_db <<'SQL'
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(80) UNIQUE NOT NULL,
  email VARCHAR(255),
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
SQL
echo

echo "==> 4) Restart auth-service"
docker-compose up -d --build auth-service
sleep 3
docker-compose logs --tail=80 auth-service || true
echo

echo "==> 5) Sanity check: auth endpoint reachable through gateway"
docker-compose up -d gateway
sleep 2
docker-compose exec -T gateway sh -lc 'wget -S -qO- http://auth-service:4000/health || true'
echo

echo "==> 6) Test register endpoint via gateway (adjust path if needed)"
# Try common endpoints. One of these should match your code.
set +e
for path in "/api/auth/register" "/api/auth/signup" "/api/auth/users/register"; do
  echo "--- Testing POST $path"
  docker-compose exec -T gateway sh -lc "wget -S -qO- --header='Content-Type: application/json' --post-data='{\"username\":\"victor_test\",\"password\":\"Passw0rd!\"}' http://localhost${path} || true"
  echo
done
set -e

echo "✅ Done. If registration still fails, auth-service logs above contain the exact reason."
echo "NOTE: If you used 'docker-compose down -v', previous users were deleted and must be re-registered."
