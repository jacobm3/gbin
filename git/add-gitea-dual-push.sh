#!/usr/bin/env bash
#
# add-gitea-dual-push.sh
#
# Update LAN machines that already have ~j/gbin cloned from GitHub so they
# match this host's setup:
#   - ~/.ssh/config gets a block for the Gitea host (port 2222, git user, ed25519 key)
#   - github remote -> https  (fetch + push)
#   - gitea  remote -> ssh    (fetch + push)
#   - origin        -> fetch from gitea(ssh); dual push to github(https) + gitea(ssh)
#
# Idempotent: re-running just re-asserts the desired state.
#
# Usage:
#   ./add-gitea-dual-push.sh j@10.0.0.21 j@10.0.0.22 ...
#   # or edit the HOSTS=() list below and run with no args
#
# Notes:
#   * Run this FROM this machine; it SSHes to each target as the user you give
#     (must be the user that owns ~/gbin, normally j).
#   * Each target needs ~/.ssh/id_ed25519 present AND that key registered in
#     Gitea, or the gitea SSH legs will fail (the script warns if the key is
#     missing and verifies reachability at the end).

# Safer bash: -u errors on unset variables; -o pipefail propagates pipeline
# failures. No -e, so the host loop can keep going past one bad host.
set -uo pipefail

# ---- edit this list, or pass hosts as arguments ----------------------------
# Default list of targets (user@host). Left commented so the script requires you
# to either fill these in or pass hosts on the command line.
HOSTS=(
  # "j@10.0.0.21"
  # "j@10.0.0.22"
)
# ----------------------------------------------------------------------------

# If any command-line arguments were given ($# > 0), use them as the host list,
# overriding the array above. "$@" is all the args.
[ "$#" -gt 0 ] && HOSTS=("$@")
# If after that the host list is still empty, print usage and exit non-zero.
# ${#HOSTS[@]} is the number of elements in the array.
if [ "${#HOSTS[@]}" -eq 0 ]; then
  echo "Usage: $0 user@host [user@host ...]   (or fill in HOSTS= at the top)" >&2
  exit 1
fi

# The payload that runs ON each target. Quoted heredoc: nothing expands locally.
# Build the remote script into the PAYLOAD variable.
#   read -r        don't treat backslashes specially.
#   -d ''          read until a NUL byte (i.e. the whole heredoc, including
#                  newlines) rather than stopping at the first newline.
#   <<'EOF'        the QUOTED delimiter means $vars/$(...) are NOT expanded here
#                  on the local machine — they'll expand later on each target.
#   || true        `read` returns non-zero at EOF; ignore that so the script
#                  doesn't abort right after capturing the payload.
read -r -d '' PAYLOAD <<'EOF' || true
# (Everything from here to EOF runs on the REMOTE host via `bash -s`.)
# Same safety flags as the outer script, now on the target.
set -uo pipefail

# Gitea connection details and the two remote URLs we want each repo to use.
GITEA_HOST="gitea.mink-neon.ts.net"
GITEA_PORT="2222"
# SSH push/fetch URL for the gitea copy of the repo.
GITEA_SSH_URL="ssh://git@${GITEA_HOST}:${GITEA_PORT}/jacobm3/gbin.git"
# HTTPS URL for the github copy of the repo.
GITHUB_URL="https://github.com/jacobm3/gbin.git"
# On the target we always operate on the logged-in user's ~/gbin.
REPO="$HOME/gbin"

# Print which host/user/repo we're configuring (shows up in the per-host output).
echo "host: $(hostname)   user: $(id -un)   repo: $REPO"

# --- ~/.ssh/config block (idempotent) ---
# Ensure ~/.ssh exists with tight perms (ssh refuses world-readable dirs/files).
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
# Ensure the config file exists and is private.
CFG="$HOME/.ssh/config"; touch "$CFG"; chmod 600 "$CFG"
# Add the gitea Host stanza only if it isn't already present (idempotent).
# Regex matches "Host gitea.mink-neon.ts.net" with optional leading whitespace
# and a boundary (space or end-of-line) after the hostname.
if grep -qiE "^[[:space:]]*Host[[:space:]]+${GITEA_HOST}([[:space:]]|\$)" "$CFG"; then
  echo "  = ssh config: Host ${GITEA_HOST} already present"
else
  # Append the stanza telling ssh the port/user/key to use for gitea.
  printf '\nHost %s\n    Port %s\n    User git\n    IdentityFile ~/.ssh/id_ed25519\n' \
    "$GITEA_HOST" "$GITEA_PORT" >> "$CFG"
  echo "  + ssh config: added Host ${GITEA_HOST}"
fi

# --- key sanity ---
# Warn (don't abort) if the private key is missing; gitea SSH auth needs it.
[ -f "$HOME/.ssh/id_ed25519" ] || \
  echo "  ! WARNING: $HOME/.ssh/id_ed25519 missing — Gitea SSH auth will fail until the key is present and registered in Gitea"

# --- trust the gitea host key non-interactively ---
# One throwaway connection to record gitea's host key in known_hosts now, so a
# later git push doesn't stop to prompt.
# -n: read stdin from /dev/null so ssh doesn't swallow the rest of this
# piped script once key auth succeeds and a session opens.
#   StrictHostKeyChecking=accept-new  auto-accept a first-seen host key.
#   BatchMode=yes                     never prompt; fail instead.
#   ConnectTimeout=8                  give up after 8s.
#   `true` is the remote command; `|| true` keeps going if it fails.
ssh -n -p "$GITEA_PORT" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
  -o ConnectTimeout=8 git@"$GITEA_HOST" true 2>/dev/null || true

# --- repo remotes ---
# Skip this host if ~/gbin isn't a git repo.
if [ ! -d "$REPO/.git" ]; then
  echo "  ! ERROR: $REPO is not a git repo — skipping this host"
  exit 3
fi
# Run the git commands below inside the repo.
cd "$REPO"

# Helper: create-or-update a remote so it ends up with the wanted URL either way.
# get-url succeeds only if the remote exists; if so, set-url updates it,
# otherwise add creates it. Idempotent.
ensure_remote() {  # name url
  if git remote get-url "$1" >/dev/null 2>&1; then
    git remote set-url "$1" "$2"
  else
    git remote add "$1" "$2"
  fi
}

# Single-purpose remotes: github over https, gitea over ssh.
ensure_remote github "$GITHUB_URL"
ensure_remote gitea  "$GITEA_SSH_URL"

# origin: fetch = gitea(ssh); push = github(https) + gitea(ssh)
# Point origin's fetch URL at gitea (ssh).
ensure_remote origin "$GITEA_SSH_URL"
# Wipe any existing push URLs so re-runs don't accumulate duplicates.
git config --unset-all remote.origin.pushurl 2>/dev/null || true
# Give origin two push URLs so one `git push origin` mirrors to BOTH github and
# gitea (the "dual push").
git remote set-url --add --push origin "$GITHUB_URL"
git remote set-url --add --push origin "$GITEA_SSH_URL"

# Show the resulting remotes, indented for readability.
echo "  remotes:"
git remote -v | sed 's/^/    /'

# --- verify gitea reachable over ssh ---
# `git ls-remote gitea` only works if ssh auth + network to gitea both work, so
# it doubles as a connectivity smoke test.
if git ls-remote gitea >/dev/null 2>&1; then
  echo "  ok: gitea reachable over SSH"
else
  echo "  ! WARNING: 'git ls-remote gitea' failed — check key is registered in Gitea / host is on the tailnet"
fi
EOF

# Track overall exit code: stays 0 only if every host succeeds.
rc=0
# Loop over each target host and run the payload on it.
for host in "${HOSTS[@]}"; do
  echo "==================== $host ===================="
  # SSH to the host and feed the payload to a remote bash via stdin.
  #   BatchMode=yes      never prompt for a password (key auth only).
  #   ConnectTimeout=10  fail fast if the host is unreachable.
  #   'bash -s'          run bash reading the script from stdin.
  #   <<<"$PAYLOAD"      here-string: send the payload variable as that stdin.
  if ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" 'bash -s' <<<"$PAYLOAD"; then
    echo "  done: $host"
  else
    # Record that at least one host failed so the final exit code is non-zero.
    echo "  ! FAILED on $host (ssh/setup error above)"
    rc=1
  fi
  echo
done

# Exit non-zero if any host failed, so callers/automation can detect problems.
exit "$rc"
