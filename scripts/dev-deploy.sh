#!/usr/bin/env bash
# Deploy specified web/ files (paths relative to web/) to the test Pi.
# Usage: scripts/dev-deploy.sh assets/css/main.css login.php ...
#        scripts/dev-deploy.sh --all          # deploy the whole web/ tree (no media symlink)
set -euo pipefail
PI="${PI:-pi@192.168.1.92}"
ROOT=/opt/pisignage/web
cd "$(dirname "$0")/../web"

if [ "${1:-}" = "--all" ]; then
  tar --exclude='media' -czf /tmp/pisig-deploy.tgz .
else
  tar -czf /tmp/pisig-deploy.tgz "$@"
fi

scp -q /tmp/pisig-deploy.tgz "$PI:/tmp/pisig-deploy.tgz"
ssh "$PI" "sudo tar -xzf /tmp/pisig-deploy.tgz -C $ROOT && sudo chown -R www-data:www-data $ROOT && rm -f /tmp/pisig-deploy.tgz"
rm -f /tmp/pisig-deploy.tgz
echo "✓ deployed to $PI:$ROOT"
