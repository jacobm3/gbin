#!/usr/bin/env bash
# Installs a user systemd timer that exports the previous day's user journal
# to ~/.logs as a daily zstd file (see export-user-journal.sh), and bumps the
# system journald retention to 5 years.
# Run once per machine:  ~/gbin/linux/install-journal-export-timer.sh
#
# PREREQUISITES: a logged-in user session with a systemd --user manager; sudo
#   for the (optional) journald retention + linger steps.
# RISK: low — writes two user unit files and one system journald drop-in.

# Safer bash mode: stop on first error (-e), error on unset vars (-u),
# and fail a pipeline if any stage fails (-o pipefail).
set -euo pipefail

# Find the directory THIS script lives in, no matter where it's called from.
# ${BASH_SOURCE[0]} is this script's own path; dirname strips the filename;
# `cd ... && pwd` turns it into a clean absolute path. We need it so we can
# point the service at the exporter sitting next to this installer.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORTER="$SCRIPT_DIR/export-user-journal.sh"
# Make sure the exporter is executable (systemd ExecStart runs it directly).
chmod +x "$EXPORTER"

# User unit files live under ~/.config/systemd/user (XDG_CONFIG_HOME overrides
# ~/.config if it's set). mkdir -p creates the path if it doesn't exist yet.
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$UNIT_DIR"

# Write the service unit. A "oneshot" service runs a command once and exits
# (as opposed to a long-running daemon) — perfect for a daily batch job.
# The heredoc (<<EOF ... EOF) writes everything between the markers to the file;
# because EOF is unquoted, $EXPORTER below is expanded to its real path.
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

# Tell the user systemd manager to re-scan its unit files so it notices the two
# files we just wrote. ALWAYS needed after creating/editing a unit file.
systemctl --user daemon-reload
# enable = start it automatically going forward; --now = also start it right now.
systemctl --user enable --now journal-export.timer

# Let the timer fire even when not logged in (best effort; needs sudo).
# By default user services only run while you have an active login session.
# "linger" keeps your user manager alive after logout so the daily timer still
# fires on a headless box. sudo -n = non-interactive (never prompt); if sudo
# isn't allowed we just print a hint instead of failing.
sudo -n loginctl enable-linger "$USER" 2>/dev/null || \
  echo "note: run 'loginctl enable-linger $USER' to export while logged out"

# Keep the system journal for 5 years (default rotates much sooner). Use a
# drop-in so we don't clobber the distro's journald.conf.
# This is one big && chain: each step only runs if the previous one succeeded.
#   1. install -d creates the drop-in directory
#   2. tee writes the retention.conf snippet (heredoc is quoted 'EOF' so the
#      [Journal] body is written verbatim, no shell expansion)
#   3. restart systemd-journald so the new retention takes effect
# If any step fails (e.g. no sudo) the || branch prints a note instead.
sudo -n install -d /etc/systemd/journald.conf.d 2>/dev/null && \
sudo -n tee /etc/systemd/journald.conf.d/retention.conf >/dev/null <<'EOF' && \
sudo -n systemctl restart systemd-journald 2>/dev/null && \
  echo "journald retention set to 5y" || \
  echo "note: run with sudo to set journald 5y retention (drop-in not written)"
[Journal]
MaxRetentionSec=5y
EOF

echo "installed. status: systemctl --user list-timers journal-export.timer"
