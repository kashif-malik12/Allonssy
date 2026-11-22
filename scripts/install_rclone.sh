#!/usr/bin/env bash
set -euo pipefail

echo "==> Downloading rclone binary..."
curl -fsSL https://downloads.rclone.org/rclone-current-linux-amd64.zip -o /tmp/rclone.zip

python3 -c "import zipfile; zipfile.ZipFile('/tmp/rclone.zip').extractall('/tmp')"
cp /tmp/rclone-*-linux-amd64/rclone /home/deploy/bin/rclone
chmod +x /home/deploy/bin/rclone
rm -rf /tmp/rclone*

echo "==> rclone installed successfully:"
/home/deploy/bin/rclone version | head -n 2
