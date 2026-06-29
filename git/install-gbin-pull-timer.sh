#!/usr/bin/env bash
# Installs a user systemd timer that runs `git pull` on this gbin repo,
# so ~/gbin stays current across all my machines.
# Run once per machine:  ~/gbin/git/install-gbin-pull-timer.sh
# NOTE: the repo's remote must use SSH (ssh://git@gitea.mink-neon.ts.net:2222/...)
# with this machine's ~/.ssh key registered in gitea, or pulls will prompt for a password.
# Strict mode: -e exit on any error, -u error on unset vars, -o pipefail fail a
# pipeline if any stage fails. Together they make the install abort on trouble
# rather than half-finishing.
set -euo pipefail

# Repo root = git toplevel of wherever this script lives (handles being in a subdir like git/).
# ${BASH_SOURCE[0]} is THIS script's path; dirname strips the filename, and
# `cd ... && pwd` resolves it to an absolute directory regardless of how we were
# invoked or what the current directory is.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ask git for the repository's top-level directory, starting from SCRIPT_DIR
# (-C runs git as if from that dir). This is the WorkingDirectory we'll pull in.
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
# Absolute path to the git binary; baked into the unit so systemd doesn't depend
# on a particular PATH at service-run time.
GIT="$(command -v git)"
# Where user (not system) systemd units live. Honor XDG_CONFIG_HOME if set, else
# default to ~/.config.
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
# Make sure that directory exists before we write unit files into it.
mkdir -p "$UNIT_DIR"

# Oneshot service: pull the repo.
#   --ff-only   avoids surprise merge commits.
#   --autostash stashes any local scribbles before pulling and reapplies them
#               after. Needed because htop rewrites ~/.config/htop/htoprc (a
#               symlink into this repo) on exit, leaving the worktree dirty; a
#               plain --ff-only pull would refuse to run on a dirty tree.
# Write the service unit. Unquoted EOF here means $REPO and $GIT expand NOW, so
# the absolute paths get baked into the file on disk.
cat > "$UNIT_DIR/gbin-pull.service" <<EOF
[Unit]
Description=Pull latest gbin
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$REPO
ExecStart=$GIT pull --ff-only --autostash
EOF

# Timer: pull every hour on the wall clock.
#   OnCalendar=hourly   fires at the top of each hour by wall-clock time, unlike
#                       the monotonic OnUnitActiveSec= which pauses during
#                       suspend (CLOCK_MONOTONIC stops), so on a laptop it would
#                       almost never accumulate a full hour of uptime.
#   Persistent=true     catches up with ONE run on resume/boot if we were asleep
#                       across one or more hour marks. (Persistent= only has any
#                       effect with OnCalendar=, which is why it did nothing
#                       alongside the old monotonic-only config.)
#   RandomizedDelaySec  jitters the fire so all machines don't hammer gitea at :00.
# Write the timer unit that schedules the service above.
cat > "$UNIT_DIR/gbin-pull.timer" <<EOF
[Unit]
Description=Pull latest gbin hourly

[Timer]
OnCalendar=hourly
Persistent=true
RandomizedDelaySec=5min

[Install]
WantedBy=timers.target
EOF

# Reload systemd's user manager so it notices the new unit files we just wrote.
systemctl --user daemon-reload
# Enable the timer (start at every boot/login) AND start it right now (--now).
systemctl --user enable --now gbin-pull.timer

# Let the timer fire even when not logged in (best effort; needs sudo).
# "Linger" keeps this user's systemd instance running with no active login.
#   sudo -n           non-interactive; fail instead of prompting for a password.
#   `|| echo ...`     if we can't sudo, just tell the user how to do it manually.
sudo -n loginctl enable-linger "$USER" 2>/dev/null || \
  echo "note: run 'loginctl enable-linger $USER' to pull while logged out"

# Final hint: how to confirm the timer is scheduled and see its next run time.
echo "installed. status: systemctl --user list-timers gbin-pull.timer"
