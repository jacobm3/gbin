#!/bin/bash
#
# Install chrome-tab-reaper into the *user* systemd instance (no root needed).
# The reaper only ever touches this user's own Chrome renderers, so it runs
# unprivileged: install under ~/.local and enable a per-user hourly timer.
#
#   ~/gbin/linux/chrome/install.sh
#
# Uninstall:
#   ~/gbin/linux/chrome/install.sh --uninstall
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DST="$HOME/.local/bin/chrome-tab-reaper"
LOG_DIR="$HOME/.local/state/chrome-tab-reaper"
UNIT_DIR="$HOME/.config/systemd/user"

# Must run as the normal user, not root — a root install would land in
# root's home and root's systemd user instance, not yours.
if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, NOT root (it installs into your" >&2
    echo "user systemd instance, not the system one)." >&2
    exit 1
fi

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "==> Disabling timer"
    systemctl --user disable --now chrome-tab-reaper.timer 2>/dev/null || true
    rm -f "$UNIT_DIR/chrome-tab-reaper.timer" "$UNIT_DIR/chrome-tab-reaper.service"
    systemctl --user daemon-reload
    rm -f "$BIN_DST"
    echo "==> Removed units and script."
    echo "    Logs left in place: $LOG_DIR"
    exit 0
fi

# python3 is all that's needed (stdlib only); no logrotate, journald handles
# rotation and the file log is one short line per hour.
command -v python3 >/dev/null || { echo "python3 not found; install it first." >&2; exit 1; }

echo "==> Installing reaper script -> $BIN_DST"
install -D -m 0755 "$SRC_DIR/chrome-tab-reaper.py" "$BIN_DST"

echo "==> Creating log directory -> $LOG_DIR"
install -d -m 0750 "$LOG_DIR"

echo "==> Installing systemd user units -> $UNIT_DIR"
install -D -m 0644 "$SRC_DIR/chrome-tab-reaper.service" "$UNIT_DIR/chrome-tab-reaper.service"
install -D -m 0644 "$SRC_DIR/chrome-tab-reaper.timer"   "$UNIT_DIR/chrome-tab-reaper.timer"

echo "==> Enabling hourly timer"
systemctl --user daemon-reload
systemctl --user enable --now chrome-tab-reaper.timer

echo
echo "Done."
systemctl --user list-timers --no-pager chrome-tab-reaper.timer || true
cat <<EOF

  Run now:       systemctl --user start chrome-tab-reaper.service
  File logs:     $LOG_DIR/reaper.log
  Journal logs:  journalctl --user -u chrome-tab-reaper.service
  Safe test:     DRY_RUN=1 THRESHOLD_GB=0 $BIN_DST
  Change limit:  systemctl --user edit chrome-tab-reaper.service   # set THRESHOLD_GB

  The timer runs only while you have a login session. Chrome only exists when
  you're logged in, so that's usually fine. To run it even with no session
  open, enable lingering once:  sudo loginctl enable-linger $USER
EOF
