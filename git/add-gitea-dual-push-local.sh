#!/usr/bin/env bash
#
# add-gitea-dual-push-local.sh
#
# Local counterpart to add-gitea-dual-push.sh. Run this ON the machine you are
# sitting at (no SSH fan-out) to point its gbin clone at Gitea using the local
# ~/.ssh/id_ed25519 key:
#   - ~/.ssh/config gets a block for the Gitea host (port 2222, git user, ed25519 key)
#   - github remote -> https  (fetch + push)
#   - gitea  remote -> ssh    (fetch + push)
#   - origin        -> fetch from gitea(ssh); dual push to github(https) + gitea(ssh)
#
# Idempotent: re-running just re-asserts the desired state.
#
# Usage:
#   ./add-gitea-dual-push-local.sh            # operates on ~/gbin
#   ./add-gitea-dual-push-local.sh /path/repo # operates on a different clone
#
# Notes:
#   * Run as the user that owns the repo (normally j) — not via sudo/root.
#   * This machine needs ~/.ssh/id_ed25519 present AND that key registered in
#     Gitea, or the gitea SSH legs will fail (the script warns if the key is
#     missing and verifies reachability at the end).

# Safer bash: -u errors on use of an unset variable; -o pipefail makes a
# pipeline fail if ANY stage fails (not just the last). Note: no -e here, so the
# script keeps going past individual failures and reports warnings instead.
set -uo pipefail

# Gitea connection details and the two remote URLs we want this repo to use.
GITEA_HOST="gitea.mink-neon.ts.net"
GITEA_PORT="2222"
# SSH push/fetch URL for the gitea copy of the repo (uses the ssh:// + :port form).
GITEA_SSH_URL="ssh://git@${GITEA_HOST}:${GITEA_PORT}/jacobm3/gbin.git"
# HTTPS URL for the github copy of the repo.
GITHUB_URL="https://github.com/jacobm3/gbin.git"
# Which clone to operate on: first argument if given, else ~/gbin.
# ${1:-default} means "use $1, but fall back to the default if $1 is unset".
REPO="${1:-$HOME/gbin}"

# Print what we're about to act on, so the operator can sanity-check it.
echo "host: $(hostname)   user: $(id -un)   repo: $REPO"

# --- ~/.ssh/config block (idempotent) ---
# Ensure ~/.ssh exists with correct (private) perms; ssh refuses loose perms.
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
# Ensure the config file exists (touch is a no-op if present) and is 0600.
CFG="$HOME/.ssh/config"; touch "$CFG"; chmod 600 "$CFG"
# Only add our Host block if it's not already there (keeps re-runs clean).
#   grep -q  quiet, just sets exit status; -i case-insensitive; -E extended regex.
#   The regex matches a line like "Host gitea.mink-neon.ts.net" with optional
#   leading whitespace and a word boundary after the host (space or end-of-line).
if grep -qiE "^[[:space:]]*Host[[:space:]]+${GITEA_HOST}([[:space:]]|\$)" "$CFG"; then
  echo "  = ssh config: Host ${GITEA_HOST} already present"
else
  # Append a Host stanza telling ssh which port, user, and key to use for gitea,
  # so plain `ssh gitea...` / git-over-ssh just work. printf expands the \n into
  # real newlines and indentation.
  printf '\nHost %s\n    Port %s\n    User git\n    IdentityFile ~/.ssh/id_ed25519\n' \
    "$GITEA_HOST" "$GITEA_PORT" >> "$CFG"
  echo "  + ssh config: added Host ${GITEA_HOST}"
fi

# --- key sanity ---
# Warn (don't abort) if the private key is missing; gitea SSH auth needs it.
# `[ -f file ] || echo ...` = "if the file does NOT exist, print the warning".
[ -f "$HOME/.ssh/id_ed25519" ] || \
  echo "  ! WARNING: $HOME/.ssh/id_ed25519 missing — Gitea SSH auth will fail until the key is present and registered in Gitea"

# --- trust the gitea host key non-interactively ---
# Make one throwaway ssh connection so gitea's host key gets recorded in
# known_hosts now, instead of prompting later during a git operation.
#   -n                      read stdin from /dev/null (don't consume the script).
#   StrictHostKeyChecking=accept-new  auto-accept a first-seen host key.
#   BatchMode=yes           never prompt (fail instead) — safe for automation.
#   ConnectTimeout=8        give up after 8s instead of hanging.
#   `true` is the remote command; `|| true` keeps the script alive if it fails.
ssh -n -p "$GITEA_PORT" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
  -o ConnectTimeout=8 git@"$GITEA_HOST" true 2>/dev/null || true

# --- repo remotes ---
# Bail if the target path isn't actually a git repo (no .git dir).
if [ ! -d "$REPO/.git" ]; then
  echo "  ! ERROR: $REPO is not a git repo"
  exit 3
fi
# All git commands below operate on this repo.
cd "$REPO"

# Helper: set a remote to a URL whether or not it already exists.
#   $1 = remote name, $2 = URL.
#   `git remote get-url` succeeds only if the remote exists; if so we update it
#   with set-url, otherwise we create it with add. Net effect is idempotent.
ensure_remote() {  # name url
  if git remote get-url "$1" >/dev/null 2>&1; then
    git remote set-url "$1" "$2"
  else
    git remote add "$1" "$2"
  fi
}

# Plain single-purpose remotes: github over https, gitea over ssh.
ensure_remote github "$GITHUB_URL"
ensure_remote gitea  "$GITEA_SSH_URL"

# origin: fetch = gitea(ssh); push = github(https) + gitea(ssh)
# Point origin's fetch URL at gitea (ssh).
ensure_remote origin "$GITEA_SSH_URL"
# Clear any pre-existing push URLs so re-runs don't pile up duplicates. The
# `2>/dev/null || true` swallows the error when there are none to unset.
git config --unset-all remote.origin.pushurl 2>/dev/null || true
# Add TWO push URLs to origin. With multiple pushurls, one `git push origin`
# sends commits to BOTH github and gitea — this is the "dual push" mirror.
git remote set-url --add --push origin "$GITHUB_URL"
git remote set-url --add --push origin "$GITEA_SSH_URL"

# Show the resulting remote configuration, indented 4 spaces for readability.
echo "  remotes:"
git remote -v | sed 's/^/    /'

# --- verify gitea reachable over ssh ---
# `git ls-remote gitea` lists the remote's refs; it only works if SSH auth and
# network reach to gitea are both good. Use it as a connectivity smoke test.
if git ls-remote gitea >/dev/null 2>&1; then
  echo "  ok: gitea reachable over SSH"
else
  echo "  ! WARNING: 'git ls-remote gitea' failed — check key is registered in Gitea / host is on the tailnet"
fi
