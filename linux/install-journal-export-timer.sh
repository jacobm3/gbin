#!/usr/bin/env bash
# Installs a user systemd timer that exports the previous day's user journal
# to ~/.logs as a daily zstd file (see export-user-journal.sh), and bumps the
# system journald retention to 5 years.
# Run once per machine:  ~/gbin/linux/install-journal-export-timer.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORTER="$SCRIPT_DIR/export-user-journal.sh"
chmod +x "$EXPORTER"

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$UNIT_DIR"

# Oneshot service: run the daily exporter.
cat > "$UNIT_DIR/journal-export.service" <<EOF
[Unit]
Description=Export previous day's user journal to ~/.logs

[Service]
Type=oneshot
ExecStart=$EXPORTER
EOF

# Timer: once a day, shortly after midnight so "yesterday" is fully complete.
#   OnCalendar=daily    fires at 00:00 wall-clock.
#   Persistent=true     catches up with one run on resume/boot if we were
#                       asleep across the midnight mark (laptop-friendly).
#   RandomizedDelaySec  small jitter; nothing else cares about the exact time.
cat > "$UNIT_DIR/journal-export.timer" <<EOF
[Unit]
Description=Export user journal daily

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=15min

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now journal-export.timer

# Let the timer fire even when not logged in (best effort; needs sudo).
sudo -n loginctl enable-linger "$USER" 2>/dev/null || \
  echo "note: run 'loginctl enable-linger $USER' to export while logged out"

# Keep the system journal for 5 years (default rotates much sooner). Use a
# drop-in so we don't clobber the distro's journald.conf.
sudo -n install -d /etc/systemd/journald.conf.d 2>/dev/null && \
sudo -n tee /etc/systemd/journald.conf.d/retention.conf >/dev/null <<'EOF' && \
sudo -n systemctl restart systemd-journald 2>/dev/null && \
  echo "journald retention set to 5y" || \
  echo "note: run with sudo to set journald 5y retention (drop-in not written)"
[Journal]
MaxRetentionSec=5y
EOF

echo "installed. status: systemctl --user list-timers journal-export.timer"
