#!/bin/bash
#
# setup.sh — install all of Jacob's Chrome workstation bits on a new machine.
#
# Installs three things, all into the *user's* home (no root needed):
#
#   1. chrome-wait-online  -> ~/.local/bin/chrome-wait-online
#        Waits for real network connectivity at login, then launches Chrome
#        with a fixed set of work tabs (gmail, slack, claude, etc).
#
#   2. chrome.desktop      -> ~/.config/autostart/chrome.desktop
#        XFCE autostart entry that runs chrome-wait-online when you log in.
#
#   3. chrome-tab-reaper   -> ~/.local/bin/chrome-tab-reaper  (+ systemd timer)
#        Hourly per-user systemd timer that kills any Chrome renderer ("tab")
#        using more than a RAM threshold. See README.md for details.
#
# Usage (run as your normal user, NOT root):
#   ~/gbin/chrome/setup.sh
#
# Uninstall everything:
#   ~/gbin/chrome/setup.sh --uninstall
#
set -euo pipefail

# Directory this script lives in (so it works no matter where it's called from).
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- install destinations -------------------------------------------------
BIN_DIR="$HOME/.local/bin"
AUTOSTART_DIR="$HOME/.config/autostart"
UNIT_DIR="$HOME/.config/systemd/user"
REAPER_LOG_DIR="$HOME/.local/state/chrome-tab-reaper"

WAIT_ONLINE_DST="$BIN_DIR/chrome-wait-online"
REAPER_DST="$BIN_DIR/chrome-tab-reaper"
DESKTOP_DST="$AUTOSTART_DIR/chrome.desktop"

# Must run as the normal user, not root. Everything lands in your home and your
# user systemd instance; a root install would land in root's home instead.
if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, NOT root." >&2
    exit 1
fi

# --- uninstall ------------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
    echo "==> Disabling tab-reaper timer"
    systemctl --user disable --now chrome-tab-reaper.timer 2>/dev/null || true
    rm -f "$UNIT_DIR/chrome-tab-reaper.timer" "$UNIT_DIR/chrome-tab-reaper.service"
    systemctl --user daemon-reload 2>/dev/null || true

    echo "==> Removing installed scripts and autostart entry"
    rm -f "$REAPER_DST" "$WAIT_ONLINE_DST" "$DESKTOP_DST"

    echo "==> Done. Reaper logs left in place: $REAPER_LOG_DIR"
    exit 0
fi

# --- prerequisites --------------------------------------------------------
# The reaper is pure Python 3 stdlib; chrome-wait-online needs nmcli + curl and
# of course google-chrome. We warn (not fail) on the chrome bits so the reaper
# still installs on a box where Chrome isn't set up yet.
command -v python3 >/dev/null || { echo "python3 not found; install it first." >&2; exit 1; }
command -v google-chrome >/dev/null || echo "WARNING: google-chrome not found — chrome-wait-online won't launch until it's installed."
command -v nmcli       >/dev/null || echo "WARNING: nmcli not found — chrome-wait-online's connectivity check needs NetworkManager."

# --- 1. chrome-wait-online launcher --------------------------------------
echo "==> Installing chrome-wait-online -> $WAIT_ONLINE_DST"
install -D -m 0755 "$SRC_DIR/chrome-wait-online" "$WAIT_ONLINE_DST"

# --- 2. autostart entry ---------------------------------------------------
echo "==> Installing autostart entry -> $DESKTOP_DST"
install -D -m 0644 "$SRC_DIR/chrome.desktop" "$DESKTOP_DST"

# --- 3. chrome-tab-reaper + systemd user timer ---------------------------
echo "==> Installing chrome-tab-reaper -> $REAPER_DST"
install -D -m 0755 "$SRC_DIR/chrome-tab-reaper.py" "$REAPER_DST"

echo "==> Creating reaper log directory -> $REAPER_LOG_DIR"
install -d -m 0750 "$REAPER_LOG_DIR"

echo "==> Installing systemd user units -> $UNIT_DIR"
install -D -m 0644 "$SRC_DIR/chrome-tab-reaper.service" "$UNIT_DIR/chrome-tab-reaper.service"
install -D -m 0644 "$SRC_DIR/chrome-tab-reaper.timer"   "$UNIT_DIR/chrome-tab-reaper.timer"

echo "==> Enabling hourly reaper timer"
systemctl --user daemon-reload
systemctl --user enable --now chrome-tab-reaper.timer

# --- summary --------------------------------------------------------------
echo
echo "Done. Installed:"
echo "  $WAIT_ONLINE_DST"
echo "  $DESKTOP_DST   (Chrome launches at next XFCE login)"
echo "  $REAPER_DST   (hourly RAM reaper via systemd user timer)"
echo
systemctl --user list-timers --no-pager chrome-tab-reaper.timer || true
cat <<EOF

  Run reaper now:  systemctl --user start chrome-tab-reaper.service
  Reaper logs:     $REAPER_LOG_DIR/reaper.log
  Launch tabs now: $WAIT_ONLINE_DST

  The reaper timer runs only while you have a login session (Chrome only exists
  then). To run it with no session open: sudo loginctl enable-linger $USER
EOF
