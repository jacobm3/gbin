#!/bin/bash
#
# Install chrome-tab-reaper from the gbin repo onto a Debian/Ubuntu system.
# Installs the reaper script, an hourly systemd timer, and log rotation.
#
#   sudo ~/gbin/linux/chrome/install.sh
#
# Uninstall:
#   sudo ~/gbin/linux/chrome/install.sh --uninstall
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DST=/usr/local/sbin/chrome-tab-reaper
LOG_DIR=/var/log/chrome-tab-reaper
LOGROTATE_DST=/etc/logrotate.d/chrome-tab-reaper
UNIT_DIR=/etc/systemd/system

# Re-exec under sudo if needed.
if [[ $EUID -ne 0 ]]; then
    echo "==> Elevating with sudo"
    exec sudo "$0" "$@"
fi

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "==> Disabling timer"
    systemctl disable --now chrome-tab-reaper.timer 2>/dev/null || true
    rm -f "$UNIT_DIR/chrome-tab-reaper.timer" "$UNIT_DIR/chrome-tab-reaper.service"
    systemctl daemon-reload
    rm -f "$BIN_DST" "$LOGROTATE_DST"
    echo "==> Removed units, script, and logrotate config."
    echo "    Logs left in place: $LOG_DIR"
    exit 0
fi

echo "==> Installing dependencies (python3, logrotate)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y python3 logrotate

echo "==> Installing reaper script -> $BIN_DST"
install -m 0755 "$SRC_DIR/chrome-tab-reaper.py" "$BIN_DST"

echo "==> Creating log directory -> $LOG_DIR"
install -d -m 0750 "$LOG_DIR"

echo "==> Installing logrotate config -> $LOGROTATE_DST"
install -m 0644 "$SRC_DIR/chrome-tab-reaper.logrotate" "$LOGROTATE_DST"

echo "==> Installing systemd units -> $UNIT_DIR"
install -m 0644 "$SRC_DIR/chrome-tab-reaper.service" "$UNIT_DIR/chrome-tab-reaper.service"
install -m 0644 "$SRC_DIR/chrome-tab-reaper.timer"   "$UNIT_DIR/chrome-tab-reaper.timer"

echo "==> Enabling hourly timer"
systemctl daemon-reload
systemctl enable --now chrome-tab-reaper.timer

echo
echo "Done."
systemctl list-timers --no-pager chrome-tab-reaper.timer || true
cat <<EOF

  Run now:       sudo systemctl start chrome-tab-reaper.service
  File logs:     $LOG_DIR/reaper.log   (rotated weekly, 8 kept, compressed)
  Journal logs:  journalctl -u chrome-tab-reaper.service
  Safe test:     sudo DRY_RUN=1 THRESHOLD_GB=0 $BIN_DST
  Change limit:  systemctl edit chrome-tab-reaper.service   # set THRESHOLD_GB
EOF
