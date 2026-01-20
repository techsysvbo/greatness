#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/techs/OneDrive/Desktop/ag-workspace"
cd "$ROOT"

echo "==> Enable nginx debug access log to show Authorization presence (not full token)"
cat > services/gateway/nginx.conf <<'NGINX'
log_format with_auth '$remote_addr - $request '
                    'status=$status '
                    'auth_present=$http_authorization '
                    'ref="$http_referer" ua="$http_user_agent"';

access_log /var/log/nginx/access.log with_auth;

server {
  listen 80;

  location /api/auth/ {
    proxy_pass http://auth-service:4000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Authorization $http_authorization;
    proxy_set_header Cookie $http_cookie;
  }

  location /api/profile/ {
    proxy_pass http://profile-service:4001/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Authorization $http_authorization;
    proxy_set_header Cookie $http_cookie;
  }

  location / {
    proxy_pass http://client:3000/;
    proxy_set_header Host $host;
  }
}
NGINX

echo "==> Rebuild + restart gateway"
docker-compose build --no-cache gateway
docker-compose up -d gateway

echo "==> Tail gateway access log (click Save Changes in UI, then run this script again or wait 5s)"
sleep 2
docker-compose exec -T gateway sh -lc 'tail -n 30 /var/log/nginx/access.log || true'
