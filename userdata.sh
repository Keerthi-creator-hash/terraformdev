#!/bin/bash
set -euo pipefail

# Simple bootstrap for Ubuntu: install nginx and serve a page on `/`
# so the ALB health check (health_check_path = "/") returns HTTP 200.

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y nginx

cat > /var/www/html/index.html <<'EOF'
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>OK</title></head>
  <body>OK</body>
</html>
EOF

chmod 0644 /var/www/html/index.html

systemctl enable nginx
systemctl restart nginx

