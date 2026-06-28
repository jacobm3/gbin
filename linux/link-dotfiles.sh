#!/usr/bin/env bash
# link-dotfiles.sh — symlink this machine's dotfiles out of gbin into $HOME.
#
# WHY THIS EXISTS
#   gbin is a git repo pulled hourly (see git/install-gbin-pull-timer.sh).
#   By symlinking dotfiles INTO gbin, a pull updates them automatically — no
#   copying, no drift. Some configs differ by machine type (e.g. htop's layout
#   for a zfs server vs a laptop), so those point at a per-profile variant.
#
# RUN
#   Once after a fresh clone, then it re-runs itself automatically after every
#   `git pull` via the .githooks/post-merge hook. Idempotent — safe to re-run.
#
# MACHINE PROFILE (which variant this box uses)
#   Resolved in this order:
#     1. ~/.gbin-profile           <- explicit override; one word, e.g. "server-zfs"
#     2. auto-detection            <- best guess from the hardware/OS
#   Valid profiles:  laptop  desktop  server  server-zfs
#
#   Auto-detection cannot always tell a headless server from a desktop, so on
#   ambiguous boxes just create the override file once:
#       echo server > ~/.gbin-profile
set -uo pipefail

# --- locate gbin from this script's own path, so CWD does not matter ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../gbin/linux
GBIN="$(cd "$SCRIPT_DIR/.." && pwd)"                          # .../gbin
DOTDIR="$GBIN/linux/dotfiles"                                 # where the synced configs/variants live

# --- figure out this machine's profile ---------------------------------------
detect_profile() {
  # 1) explicit override wins
  if [ -r "$HOME/.gbin-profile" ]; then
    # read first word of the file, trimming whitespace/newlines
    read -r p _ < "$HOME/.gbin-profile"
    [ -n "$p" ] && { echo "$p"; return; }
  fi

  # 2) auto-detect (best effort)
  #    zfs pools present -> treat as the zfs server profile
  if command -v zpool >/dev/null 2>&1 && [ -n "$(zpool list -H -o name 2>/dev/null)" ]; then
    echo "server-zfs"; return
  fi
  #    a battery means it's a laptop
  if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
    echo "laptop"; return
  fi
  #    boots to a graphical target -> desktop; otherwise assume a server
  if [ "$(systemctl get-default 2>/dev/null)" = "graphical.target" ]; then
    echo "desktop"; return
  fi
  echo "server"
}

PROFILE="$(detect_profile)"

# `--print-profile`: just report the resolved profile and exit (used by the
# new-machine installer to seed ~/.gbin-profile). Does no linking.
if [ "${1:-}" = "--print-profile" ]; then
  echo "$PROFILE"
  exit 0
fi

echo "link-dotfiles: profile = $PROFILE"

# --- helpers -----------------------------------------------------------------
# link_shared SRC DEST       : DEST -> $GBIN/SRC  (same file on every machine)
# link_variant BASE DEST     : DEST -> $GBIN/.../BASE.$PROFILE, falling back to
#                              BASE if no variant exists for this profile.
link() {  # internal: link "$1" (target file in gbin) -> "$2" (path in HOME)
  local src="$1" dest="$2"
  [ -e "$src" ] || { echo "link-dotfiles: MISSING source $src — skipped" >&2; return; }
  mkdir -p "$(dirname "$dest")"
  # ln -sfn: force-replace, treat existing symlink-to-dir as a file (no nesting)
  ln -sfn "$src" "$dest"
  echo "link-dotfiles: $dest -> $src"
}

link_shared()  { link "$GBIN/$1" "$2"; }

link_variant() {
  local base="$1" dest="$2"
  if [ -e "$DOTDIR/$base.$PROFILE" ]; then
    link "$DOTDIR/$base.$PROFILE" "$dest"
  else
    echo "link-dotfiles: no $base.$PROFILE, falling back to $base" >&2
    link "$DOTDIR/$base" "$dest"
  fi
}

# --- the actual dotfiles ------------------------------------------------------
# shared (identical everywhere):
link_shared "jacobrc"                    "$HOME/.jacobrc"
link_shared "linux/dotfiles/digrc" "$HOME/.digrc"
# btop: same config everywhere — the clock_format uses btop's /host token so the
# hostname (plus YY-MM-DD date + time) renders per-machine at runtime.
link_shared "linux/dotfiles/btop.conf" "$HOME/.config/btop/btop.conf"

# machine-specific (one variant per profile):
link_variant "htoprc" "$HOME/.config/htop/htoprc"

echo "link-dotfiles: done."
