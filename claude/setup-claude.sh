#!/usr/bin/env bash
# setup-claude.sh — configure Claude Code on THIS machine from gbin.
#
# Idempotent — safe to re-run. Does four things:
#   1. Make ~/.claude/CLAUDE.md import the shared instructions
#      (@~/gbin/claude/CLAUDE-shared.md) so every project on this box gets the
#      same global guidance (incl. the qmd recall/save memory rules).
#   2. Register the shared qmd memory MCP server   (qmd/setup).
#   3. Install the status line                      (install-statusline.sh).
#   4. Disable fullscreen-TUI mouse click/drag capture so native terminal
#      drag-to-select-and-copy works (settings.json env, wheel-scroll kept).
#
# Steps 2-4 only run if the `claude` CLI is installed — a gbin box without
# Claude Code still gets the CLAUDE.md import (harmless) and skips the rest
# cleanly instead of erroring.
#
# USAGE
#   ~/gbin/claude/setup-claude.sh
#
# Called automatically by ../setup-new-machine.sh, but fine to run on its own.
set -uo pipefail

# Resolve this script's dir so paths work no matter the CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

# Track failures so we can report a summary and exit non-zero for the caller.
FAILED=()
note_fail() { echo "    FAILED: $1" >&2; FAILED+=("$1"); }

# --- 1. ensure ~/.claude/CLAUDE.md imports the shared instructions ------------
# We guarantee the import is the FIRST line, so the shared guidance loads before
# any machine-specific content that overrides it. `grep -qxF` matches the whole
# line exactly, so we never add a duplicate. If the file is new we create it with
# just the import; if it already exists, we prepend the import and keep the rest.
ensure_claude_import() {
  local import='@~/gbin/claude/CLAUDE-shared.md'
  local f="$HOME/.claude/CLAUDE.md"
  mkdir -p "$HOME/.claude"
  if grep -qxF "$import" "$f" 2>/dev/null; then
    echo "    ~/.claude/CLAUDE.md already imports CLAUDE-shared.md"
    return 0
  fi
  if [ -e "$f" ]; then
    # Existing machine-specific CLAUDE.md: prepend the import as the first line,
    # leaving the rest untouched. Write to a temp file then move into place.
    local tmp="$f.tmp.$$"
    { printf '%s\n\n' "$import"; cat "$f"; } > "$tmp" && mv "$tmp" "$f"
    echo "    prepended import to existing ~/.claude/CLAUDE.md"
  else
    # Fresh box: create the file with just the import (machine-specific
    # context can be added below it later).
    printf '%s\n' "$import" > "$f"
    echo "    created ~/.claude/CLAUDE.md with shared import"
  fi
}

echo "==> CLAUDE.md shared import"
ensure_claude_import || note_fail "CLAUDE.md import"

# If Claude Code isn't installed, the remaining steps don't apply. Skip cleanly.
if ! command -v claude >/dev/null 2>&1; then
  echo
  echo "==> 'claude' CLI not found — skipping qmd MCP + statusline."
  echo "    (Install Claude Code, then re-run this script.)"
  # The import step still ran; report its result only.
  if [ "${#FAILED[@]}" -eq 0 ]; then exit 0; else exit 1; fi
fi

# --- 2. register the shared qmd memory MCP server ----------------------------
echo
echo "==> qmd memory MCP server"
bash "$REPO/qmd/setup" || note_fail "qmd MCP setup"

# --- 3. install the status line ----------------------------------------------
echo
echo "==> Claude status line"
bash "$SCRIPT_DIR/install-statusline.sh" || note_fail "statusline"

# --- 4. disable fullscreen-TUI mouse click/drag capture ----------------------
# In fullscreen TUI mode Claude Code grabs mouse click/drag, which breaks the
# terminal's native drag-to-select-and-copy. CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1
# hands click/drag back to the terminal (native selection works again) while
# KEEPING in-app mouse-wheel scrolling. We set it via settings.json "env" so it
# applies no matter which shell launches `claude`. To fully release the mouse
# (also give wheel-scroll back to the terminal) use CLAUDE_CODE_DISABLE_MOUSE=1
# instead. Idempotent: only writes when the value isn't already set.
ensure_mouse_env() {
  command -v python3 >/dev/null 2>&1 || { echo "    ! python3 not found" >&2; return 2; }
  python3 - <<'PY'
import json, os
settings = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(settings), exist_ok=True)
try:
    with open(settings, encoding="utf-8") as fh:
        cfg = json.load(fh)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}
env = cfg.setdefault("env", {})
if env.get("CLAUDE_CODE_DISABLE_MOUSE_CLICKS") == "1":
    print(f"    = mouse-click capture already disabled ({settings})")
else:
    env["CLAUDE_CODE_DISABLE_MOUSE_CLICKS"] = "1"
    with open(settings, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, indent=2)
        fh.write("\n")
    print(f"    + disabled mouse-click capture ({settings})")
PY
}

echo
echo "==> Claude mouse-click capture (disable)"
ensure_mouse_env || note_fail "mouse env"

# --- summary -----------------------------------------------------------------
echo
if [ "${#FAILED[@]}" -eq 0 ]; then
  echo "setup-claude: OK"
  exit 0
else
  echo "setup-claude: ${#FAILED[@]} step(s) FAILED:"
  for f in "${FAILED[@]}"; do echo "  - $f"; done
  exit 1
fi
