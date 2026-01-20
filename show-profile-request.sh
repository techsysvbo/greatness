#!/usr/bin/env bash
set -euo pipefail

cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> Last 200 gateway log lines filtered to profile API calls"
docker-compose logs --tail=200 gateway | grep -E "(/api/profile/| /api/profile/)" || true

echo
echo "==> Last 200 profile-service log lines (auth/db errors show here)"
docker-compose logs --tail=200 profile-service || true
