#!/usr/bin/env bash
# setup-new-machine.sh — one-shot setup for a freshly cloned gbin on a new box.
#
# WHAT IT DOES (each step is idempotent — safe to re-run anytime):
#   1. git identity + global git config            (git/git-setup.sh)
#   2. gitleaks + activate the committed git hooks  (git/setup-githooks.sh)
#   3. make ~/.bashrc source gbin/jacobrc           (so aliases/PATH load on login)
#   4. create ~/.gbin-profile if missing            (machine type for dotfile variants)
#   5. symlink dotfiles into $HOME                  (linux/link-dotfiles.sh)
#   6. install the hourly gbin-pull timer           (git/install-gbin-pull-timer.sh)
#   7. configure Claude Code: shared CLAUDE.md import + qmd MCP + statusline
#                                                    (claude/setup-claude.sh)
#
# OPTIONAL (only on a machine you PUSH from, not consume-only boxes):
#   --push-machine   also point `origin` at both gitea (ssh) and github (https)
#                    so a single `git push` updates both remotes.
#
# WORK MACHINES (no access to the home tailnet or anything on it):
#   --work   skip every step that depends on home-tailnet resources, namely:
#              - the hourly gbin-pull timer (it pulls from gitea over the tailnet)
#              - the Claude Code setup       (its qmd MCP lives on the tailnet, and
#                                             we don't run Claude on work boxes anyway)
#            Everything else (git config, hooks, bashrc, dotfiles) still runs, so
#            you get the shell environment without reaching the home network.
#            On a work box you typically clone from github, e.g.:
#              git clone https://github.com/jacobm3/gbin.git ~/gbin
#
# USAGE
#   git clone ssh://git@gitea.mink-neon.ts.net:2222/jacobm3/gbin.git ~/gbin
#   cd ~/gbin && ./setup-new-machine.sh            # or: --push-machine, or --work
#
# Note: we deliberately do NOT use `set -e` — if one step fails we want to keep
# going and report a summary at the end rather than abort the whole install.
# set -u: treat use of an unset variable as an error (catches typos).
# set -o pipefail: a pipeline fails if ANY command in it fails, not just the last.
# (We deliberately omit -e — see the note above — so a failed step doesn't abort.)
set -uo pipefail

# --- parse args --------------------------------------------------------------
# Default both feature flags to 0 (off); the loop below flips them on if the
# matching option is passed.
PUSH_MACHINE=0
WORK_MACHINE=0   # --work: skip steps that need the home tailnet (pull timer, claude)
# Walk over every command-line argument ("$@" is the full arg list).
for a in "$@"; do
  # Match the argument against the known options.
  case "$a" in
    # Recognized flags just set their variable to 1.
    --push-machine) PUSH_MACHINE=1 ;;
    --work)         WORK_MACHINE=1 ;;
    # Anything else is a typo/unknown flag: complain to stderr (>&2) and exit 2.
    *) echo "setup-new-machine: unknown option '$a'" >&2; exit 2 ;;
  esac
done

# --- locate the repo root from this script's own location (CWD-independent) ---
# ${BASH_SOURCE[0]} is the path to THIS script. dirname strips the filename to
# get its directory, then `cd ... && pwd` turns it into a clean absolute path.
# This makes the script work no matter what directory you run it from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ask git for the top-level directory of the repo containing this script.
# `git -C DIR` runs git as if started in DIR. If that fails (not a git repo),
# the `|| { ... }` block prints an error and exits 1.
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "setup-new-machine: not inside a git repo ($SCRIPT_DIR)" >&2; exit 1
}

# Track which steps fail so we can print a summary at the end.
# FAILED starts as an empty array; run_step appends a label each time a step fails.
FAILED=()

# run_step "label" command args...   -> runs it, records failure, never aborts.
run_step() {
  # First argument is the human-readable label; `shift` drops it so "$@" now
  # holds just the command and its arguments.
  local label="$1"; shift
  # Blank line + a "==>" banner so each step is easy to spot in the output.
  echo
  echo "==> $label"
  # Run the command. "$@" preserves each argument as a separate word (handles
  # spaces safely). If it succeeds (exit 0), print ok; otherwise record failure.
  if "$@"; then
    echo "    ok: $label"
  else
    # Send the failure line to stderr and remember the label for the summary.
    echo "    FAILED: $label" >&2
    FAILED+=("$label")
  fi
}

# --- 1. global git config (identity, credential helper, merge style) ----------
run_step "git config" bash "$REPO/git/git-setup.sh"

# --- 2. gitleaks + activate committed hooks (pre-commit, post-merge) ----------
run_step "gitleaks + git hooks" bash "$REPO/git/setup-githooks.sh"

# --- 3. ensure ~/.bashrc sources jacobrc -------------------------------------
# jacobrc holds the PATH (incl. ~/gbin), aliases, and functions. A fresh box's
# ~/.bashrc won't source it, so add the line once. `grep -qxF` matches the whole
# line exactly so we never add a duplicate.
ensure_bashrc() {
  # The exact line we want present in ~/.bashrc. The leading `. ` means "source"
  # (run jacobrc in the current shell so its aliases/PATH take effect).
  local line='. ~/gbin/jacobrc'
  # grep flags: -q quiet (no output, just exit status), -x match the WHOLE line,
  # -F treat the pattern as a literal string (not a regex). 2>/dev/null hides the
  # error if ~/.bashrc doesn't exist yet. If the line is already there, do nothing.
  if grep -qxF "$line" "$HOME/.bashrc" 2>/dev/null; then
    echo "    ~/.bashrc already sources jacobrc"
  else
    # `>>` appends (never truncates) so we don't clobber the existing ~/.bashrc.
    echo "$line" >> "$HOME/.bashrc"
    echo "    added '$line' to ~/.bashrc"
  fi
}
run_step "bashrc sources jacobrc" ensure_bashrc

# --- 4. create ~/.gbin-profile if missing ------------------------------------
# The dotfile linker auto-detects machine type, but writing the result to a file
# makes it explicit and durable (and lets you correct a wrong guess by editing
# one word). We only create it if absent — never overwrite your choice.
ensure_profile() {
  # If the profile file already exists (-e = exists), keep the user's choice and
  # just print it. `return 0` exits the function successfully without rewriting it.
  if [ -e "$HOME/.gbin-profile" ]; then
    echo "    ~/.gbin-profile exists: $(cat "$HOME/.gbin-profile")"
    return 0
  fi
  # `local p` declares a function-local variable so we don't leak it globally.
  local p
  # Ask the dotfile linker to auto-detect the machine type and print it. If that
  # command fails, `|| return 1` reports this step as failed (run_step sees it).
  p="$(bash "$REPO/linux/link-dotfiles.sh" --print-profile)" || return 1
  # Save the detected profile word to the file (`>` creates/overwrites; safe here
  # because we already returned above if the file existed).
  echo "$p" > "$HOME/.gbin-profile"
  echo "    auto-detected profile '$p' -> ~/.gbin-profile"
  echo "    (edit that file if wrong; valid: laptop desktop server server-zfs)"
}
run_step "machine profile" ensure_profile

# --- 5. symlink dotfiles into $HOME ------------------------------------------
run_step "link dotfiles" bash "$REPO/linux/link-dotfiles.sh"

# --- 6. install hourly gbin-pull timer ---------------------------------------
# The timer pulls from the gitea remote, which only exists on the home tailnet,
# so skip it on work machines (you'll update gbin manually with `git pull`).
if [ "$WORK_MACHINE" -eq 1 ]; then
  echo
  echo "==> gbin-pull timer: skipped (--work, no home tailnet). Update with 'git -C ~/gbin pull'."
else
  run_step "gbin-pull timer" bash "$REPO/git/install-gbin-pull-timer.sh"
fi

# --- 7. configure Claude Code (shared CLAUDE.md import, qmd MCP, statusline) --
# Idempotent; the qmd/statusline parts self-skip if the `claude` CLI is absent,
# so this is safe on gbin boxes that don't run Claude Code. Skipped entirely on
# work machines: its qmd MCP lives on the home tailnet, and we don't run Claude
# there (only the approved work tooling).
if [ "$WORK_MACHINE" -eq 1 ]; then
  echo
  echo "==> claude code setup: skipped (--work, no Claude on work machines)."
else
  run_step "claude code setup" bash "$REPO/claude/setup-claude.sh"
fi

# --- OPTIONAL: dual-remote push (push machines only) -------------------------
# Make `origin` fetch from gitea (ssh) and push to BOTH gitea and github, so one
# `git push` mirrors to both. Reset push URLs first so re-running stays clean
# (otherwise --add would keep stacking duplicate URLs).
setup_dual_remote() {
  # The two remote URLs we want `origin` to use: gitea over ssh (home tailnet)
  # and github over https (public mirror).
  local gitea="ssh://git@gitea.mink-neon.ts.net:2222/jacobm3/gbin.git"
  local github="https://github.com/jacobm3/gbin.git"
  # Set the single FETCH url (what `git pull` reads from) to gitea.
  git -C "$REPO" remote set-url origin "$gitea"                 # fetch url = gitea
  # Clear any existing push URLs first. `set-url --push` refuses to run when
  # several already exist, so unset them all, then add our two cleanly. This is
  # what makes the step safe to re-run without stacking duplicates.
  git -C "$REPO" config --unset-all remote.origin.pushurl 2>/dev/null || true
  git -C "$REPO" remote set-url --add --push origin "$gitea"    # 1st push target = gitea
  git -C "$REPO" remote set-url --add --push origin "$github"   # 2nd push target = github
  echo "    origin now fetches gitea, pushes to gitea + github"
}
if [ "$PUSH_MACHINE" -eq 1 ]; then
  run_step "dual-remote push" setup_dual_remote
else
  echo
  echo "==> dual-remote push: skipped (consume-only). Re-run with --push-machine to enable."
fi

# --- summary -----------------------------------------------------------------
echo
echo "============================================================"
# ${#FAILED[@]} is the number of elements in the FAILED array. Zero means every
# step succeeded.
if [ "${#FAILED[@]}" -eq 0 ]; then
  echo "setup-new-machine: ALL STEPS OK"
  echo "open a new shell (or 'source ~/.bashrc') to pick up jacobrc."
else
  # Otherwise, report how many failed and list each label, then exit non-zero so
  # callers (and CI) can tell the run wasn't fully clean.
  echo "setup-new-machine: ${#FAILED[@]} step(s) FAILED:"
  for f in "${FAILED[@]}"; do echo "  - $f"; done
  exit 1
fi
