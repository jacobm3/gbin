#!/usr/bin/env bash
# setup-claude.sh — configure Claude Code on THIS machine from gbin.
#
# Idempotent — safe to re-run. Does three things:
#   1. Make ~/.claude/CLAUDE.md import the shared instructions
#      (@~/gbin/claude/CLAUDE-shared.md) so every project on this box gets the
#      same global guidance (incl. the qmd recall/save memory rules).
#   2. Register the shared qmd memory MCP server   (qmd/setup).
#   3. Install the status line                      (install-statusline.sh).
#
# Steps 2 and 3 only run if the `claude` CLI is installed — a gbin box without
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
