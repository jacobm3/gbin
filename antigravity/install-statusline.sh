#!/usr/bin/env bash
#
# install-statusline.sh
#
# Install agy-statusline.py for the Antigravity CLI (`agy`) on this machine.
# The script itself arrives via `gbin` (cloned/pulled on every machine); this
# installer copies it into agy's config dir and points settings.json at it.
#
# Two steps per machine:
#   1. copy  ~/gbin/antigravity/agy-statusline.py
#         -> ~/.gemini/antigravity-cli/agy-statusline.py   (chmod +x)
#   2. set the "statusLine" block in ~/.gemini/antigravity-cli/settings.json
#      to run that copy, replacing any existing statusLine and leaving every
#      other setting untouched.
#
# Idempotent: re-running just re-asserts the copy and the statusLine block.
# No agy/Claude inference involved -- plain python json editing.
#
# Usage:
#   ./install-statusline.sh                 # configure THIS machine
#   ./install-statusline.sh j@10.0.0.21 ... # configure remote machines over ssh
#
# Remote mode pipes this script over ssh to each target and runs it there. Each
# target must already have ~/gbin (the agy-statusline.py source) and python3.

# -u errors on unset variables; pipefail makes a pipeline fail if any stage does.
# (No -e, so the remote loop below can keep going and report per-host failures.)
set -uo pipefail

# Source (in the repo) and install destination for the python script.
SRC="$HOME/gbin/antigravity/agy-statusline.py"
DEST_DIR="$HOME/.gemini/antigravity-cli"
DEST="$DEST_DIR/agy-statusline.py"
SETTINGS="$DEST_DIR/settings.json"

# --- the actual install step, run locally on whichever machine we're on ------
install_here() {
  # Require python3; we use it below to edit settings.json as JSON.
  command -v python3 >/dev/null 2>&1 || { echo "  ! python3 not found" >&2; return 2; }

  if [ ! -f "$SRC" ]; then
    echo "  ! source script not found: $SRC" >&2
    echo "    (does this machine have ~/gbin checked out?)" >&2
    return 2
  fi

  # Step 1: copy the status line script into agy's config dir, make it runnable.
  mkdir -p "$DEST_DIR"
  if cp "$SRC" "$DEST" && chmod +x "$DEST"; then
    echo "  + script installed ($DEST)"
  else
    echo "  ! failed to install script to $DEST" >&2
    return 1
  fi

  # Step 2: point settings.json's statusLine block at the installed copy.
  # $HOME expands at run time, so the stored command is identical on every machine.
  SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os, sys

settings = os.environ["SETTINGS"]
os.makedirs(os.path.dirname(settings), exist_ok=True)

# Load existing settings; start fresh if missing or corrupt.
try:
    with open(settings, encoding="utf-8") as fh:
        cfg = json.load(fh)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

desired = {
    "type": "command",
    "command": "python3 $HOME/.gemini/antigravity-cli/agy-statusline.py",
}

if cfg.get("statusLine") == desired:
    print(f"  = statusLine already configured ({settings})")
else:
    # Replaces any existing statusLine section; all other keys are preserved.
    cfg["statusLine"] = desired
    with open(settings, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, indent=2)
        fh.write("\n")
    print(f"  + statusLine configured ({settings})")
PY
}

# --- remote fan-out (optional) ----------------------------------------------
# No arguments ($# = arg count) means: just configure THIS machine.
if [ "$#" -eq 0 ]; then
  echo "==================== $(hostname) (local) ===================="
  install_here
  echo "  restart / refresh agy to pick it up"
  # Pass through install_here's exit status ($? = status of last command).
  exit $?
fi

# Otherwise each argument is an ssh target. Pipe this whole script over ssh and
# run it with no args there, so the remote copy takes the "local" branch above.
# rc remembers whether any host failed, for a nonzero exit at the end.
rc=0
for host in "$@"; do
  echo "==================== $host ===================="
  # BatchMode=yes = never prompt for a password; ConnectTimeout caps the wait.
  # "bash -s" runs the script piped in via "< ${BASH_SOURCE[0]}".
  if ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" \
       'bash -s' < "${BASH_SOURCE[0]}"; then
    echo "  done: $host"
  else
    echo "  ! FAILED on $host"
    rc=1
  fi
  echo
done
exit "$rc"
