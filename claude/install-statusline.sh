#!/usr/bin/env bash
#
# install-statusline.sh
#
# Wire cc-statusline.py into this machine's Claude Code config. The script
# itself arrives via `gbin` (cloned/pulled on every machine), so all that's
# left per-machine is pointing ~/.claude/settings.json at it.
#
# Idempotent: re-running just re-asserts the statusLine block, leaving every
# other setting untouched. No Claude inference involved.
#
# Usage:
#   ./install-statusline.sh                 # configure THIS machine
#   ./install-statusline.sh j@10.0.0.21 ... # configure remote machines over ssh
#
# Remote mode assumes each target already has ~/gbin (it does, if you ran
# add-gitea-dual-push.sh) and python3.

# Safety flags: -u errors on use of an unset variable; pipefail makes a pipeline
# fail if ANY stage fails (not just the last). (No -e here on purpose, so the
# remote loop below can keep going and report per-host failures.)
set -uo pipefail

# Absolute path to the directory holding this script, regardless of where it was
# invoked from. The "cd ... && pwd" idiom resolves it portably.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- the actual install step, run locally on whichever machine we're on ------
install_here() {
  # Require python3 (we use it to edit settings.json as JSON). "|| { ...; }"
  # prints an error and returns if python3 isn't found.
  command -v python3 >/dev/null 2>&1 || { echo "  ! python3 not found" >&2; return 2; }

  # Run an inline Python program (the heredoc between <<'PY' and PY). The single
  # quotes around 'PY' mean the shell does NOT expand $variables inside it.
  python3 - "$@" <<'PY'
import json, os, sys

settings = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(settings), exist_ok=True)

try:
    with open(settings, encoding="utf-8") as fh:
        cfg = json.load(fh)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

desired = {
    "type": "command",
    # $HOME expands at run time, so this line is identical on every machine.
    "command": "python3 $HOME/gbin/claude/cc-statusline.py",
}

if cfg.get("statusLine") == desired:
    print(f"  = statusLine already configured ({settings})")
else:
    cfg["statusLine"] = desired
    with open(settings, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, indent=2)
        fh.write("\n")
    print(f"  + statusLine configured ({settings})")
PY
}

# --- remote fan-out (optional) ----------------------------------------------
# With no arguments ($# is the argument count), just configure THIS machine.
if [ "$#" -eq 0 ]; then
  echo "==================== $(hostname) (local) ===================="
  install_here
  echo "  restart / refresh Claude Code to pick it up"
  # "$?" is the exit status of the last command (install_here); pass it through.
  exit $?
fi

# Otherwise each argument is an ssh target. Ship this whole script over ssh and
# run it there with no args, so the remote copy takes the "local" branch above.
# rc remembers if any host failed so we can exit nonzero at the end.
rc=0
for host in "$@"; do
  echo "==================== $host ===================="
  # BatchMode=yes never prompts for a password (fail fast if keys don't work);
  # ConnectTimeout caps how long we wait to connect. "bash -s" reads the script
  # from stdin, which we feed from this file via "< ...".
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
