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

set -uo pipefail

# ---- edit this list, or pass hosts as arguments ----------------------------
HOSTS=(
  # "j@10.0.0.21"
  # "j@10.0.0.22"
)
# ----------------------------------------------------------------------------

[ "$#" -gt 0 ] && HOSTS=("$@")
if [ "${#HOSTS[@]}" -eq 0 ]; then
  echo "Usage: $0 user@host [user@host ...]   (or fill in HOSTS= at the top)" >&2
  exit 1
fi

# The payload that runs ON each target. Quoted heredoc: nothing expands locally.
read -r -d '' PAYLOAD <<'EOF' || true
set -uo pipefail

GITEA_HOST="gitea.mink-neon.ts.net"
GITEA_PORT="2222"
GITEA_SSH_URL="ssh://git@${GITEA_HOST}:${GITEA_PORT}/jacobm3/gbin.git"
GITHUB_URL="https://github.com/jacobm3/gbin.git"
REPO="$HOME/gbin"

echo "host: $(hostname)   user: $(id -un)   repo: $REPO"

# --- ~/.ssh/config block (idempotent) ---
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
CFG="$HOME/.ssh/config"; touch "$CFG"; chmod 600 "$CFG"
if grep -qiE "^[[:space:]]*Host[[:space:]]+${GITEA_HOST}([[:space:]]|\$)" "$CFG"; then
  echo "  = ssh config: Host ${GITEA_HOST} already present"
else
  printf '\nHost %s\n    Port %s\n    User git\n    IdentityFile ~/.ssh/id_ed25519\n' \
    "$GITEA_HOST" "$GITEA_PORT" >> "$CFG"
  echo "  + ssh config: added Host ${GITEA_HOST}"
fi

# --- key sanity ---
[ -f "$HOME/.ssh/id_ed25519" ] || \
  echo "  ! WARNING: $HOME/.ssh/id_ed25519 missing — Gitea SSH auth will fail until the key is present and registered in Gitea"

# --- trust the gitea host key non-interactively ---
# -n: read stdin from /dev/null so ssh doesn't swallow the rest of this
# piped script once key auth succeeds and a session opens.
ssh -n -p "$GITEA_PORT" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
  -o ConnectTimeout=8 git@"$GITEA_HOST" true 2>/dev/null || true

# --- repo remotes ---
if [ ! -d "$REPO/.git" ]; then
  echo "  ! ERROR: $REPO is not a git repo — skipping this host"
  exit 3
fi
cd "$REPO"

ensure_remote() {  # name url
  if git remote get-url "$1" >/dev/null 2>&1; then
    git remote set-url "$1" "$2"
  else
    git remote add "$1" "$2"
  fi
}

ensure_remote github "$GITHUB_URL"
ensure_remote gitea  "$GITEA_SSH_URL"

# origin: fetch = gitea(ssh); push = github(https) + gitea(ssh)
ensure_remote origin "$GITEA_SSH_URL"
git config --unset-all remote.origin.pushurl 2>/dev/null || true
git remote set-url --add --push origin "$GITHUB_URL"
git remote set-url --add --push origin "$GITEA_SSH_URL"

echo "  remotes:"
git remote -v | sed 's/^/    /'

# --- verify gitea reachable over ssh ---
if git ls-remote gitea >/dev/null 2>&1; then
  echo "  ok: gitea reachable over SSH"
else
  echo "  ! WARNING: 'git ls-remote gitea' failed — check key is registered in Gitea / host is on the tailnet"
fi
EOF

rc=0
for host in "${HOSTS[@]}"; do
  echo "==================== $host ===================="
  if ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" 'bash -s' <<<"$PAYLOAD"; then
    echo "  done: $host"
  else
    echo "  ! FAILED on $host (ssh/setup error above)"
    rc=1
  fi
  echo
done

exit "$rc"
