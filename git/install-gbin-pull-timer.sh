#!/usr/bin/env bash
# Installs a user systemd timer that runs `git pull` on this gbin repo,
# so ~/gbin stays current across all my machines.
# Run once per machine:  ~/gbin/git/install-gbin-pull-timer.sh
# NOTE: the repo's remote must use SSH (ssh://git@gitea.mink-neon.ts.net:2222/...)
# with this machine's ~/.ssh key registered in gitea, or pulls will prompt for a password.
set -euo pipefail

# Repo root = git toplevel of wherever this script lives (handles being in a subdir like git/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
GIT="$(command -v git)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$UNIT_DIR"

# Oneshot service: pull the repo. --ff-only avoids surprise merge commits.
cat > "$UNIT_DIR/gbin-pull.service" <<EOF
[Unit]
Description=Pull latest gbin
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$REPO
ExecStart=$GIT pull --ff-only
EOF

# Timer: run shortly after login and every hour after that.
cat > "$UNIT_DIR/gbin-pull.timer" <<EOF
[Unit]
Description=Pull latest gbin hourly

[Timer]
OnStartupSec=2min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now gbin-pull.timer

# Let the timer fire even when not logged in (best effort; needs sudo).
sudo -n loginctl enable-linger "$USER" 2>/dev/null || \
  echo "note: run 'loginctl enable-linger $USER' to pull while logged out"

echo "installed. status: systemctl --user list-timers gbin-pull.timer"
