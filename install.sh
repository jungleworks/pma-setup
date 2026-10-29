#!/bin/bash
set -euo pipefail

# Must run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

# Always work from the repo folder, wherever the script is called from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f docker-compose.yml ]; then
    echo "docker-compose.yml not found in $SCRIPT_DIR"
    exit 1
fi

# Check architecture (x86_64 or aarch64/Graviton)
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|aarch64) ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# 1. Install Docker and start it now + on every boot
yum install -y docker
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl enable --now docker
else
    # No systemd (e.g. Amazon Linux 1 / SysV init): fall back to service
    service docker start
    if command -v chkconfig >/dev/null 2>&1; then
        chkconfig docker on
    fi
fi

# 2. Install the latest Docker Compose plugin (system-wide)
PLUGIN_DIR=/usr/local/lib/docker/cli-plugins
mkdir -p "$PLUGIN_DIR"
curl -fSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}" \
    -o "$PLUGIN_DIR/docker-compose"
chmod +x "$PLUGIN_DIR/docker-compose"
docker compose version

# 3. Start phpMyAdmin
docker compose up -d

# 4. Show the PHP version so you can confirm it's patched
sleep 3
docker exec pma php -v
echo "phpMyAdmin is running on http://$(hostname -I | awk '{print $1}'):444"
