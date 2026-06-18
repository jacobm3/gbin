#!/usr/bin/env bash
# Build a self-contained, offline nvim bundle (config + plugins + parsers +
# official portable nvim binary) for deploying to fresh linux x86_64 boxes,
# including ones where GitHub / your home network are blocked.
#
#   Usage:  nvim-bundle-build.sh [output.tar.gz]
#   Then:   aws s3 cp nvim-bundle.tar.gz s3://YOUR-BUCKET/ --acl public-read
#     (GCS)  gcloud storage cp nvim-bundle.tar.gz gs://YOUR-BUCKET/ && \
#            gcloud storage objects update gs://YOUR-BUCKET/nvim-bundle.tar.gz --add-acl-grant=entity=allUsers,role=READER
#
# .git dirs are kept on purpose so plugins can still be updated later.
set -euo pipefail

OUT="${1:-$HOME/nvim-bundle.tar.gz}"
NVIM_VER="v0.12.2"                       # keep in sync with your installed nvim
NVIM_TARBALL="nvim-linux-x86_64.tar.gz"
CACHE="$HOME/.cache/$NVIM_TARBALL"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# 1. Official portable nvim (cached after first download; needs GitHub once).
if [ ! -s "$CACHE" ]; then
  echo ">> fetching portable nvim $NVIM_VER"
  curl -fL --retry 2 -o "$CACHE" \
    "https://github.com/neovim/neovim/releases/download/$NVIM_VER/$NVIM_TARBALL"
fi
mkdir -p "$STAGE/.local"
tar xzf "$CACHE" -C "$STAGE/.local"      # -> .local/nvim-linux-x86_64/

# 2. Your config + downloaded plugins + compiled treesitter parsers (with .git).
mkdir -p "$STAGE/.config" "$STAGE/.local/share/nvim/site"
cp -a "$HOME/.config/nvim"                       "$STAGE/.config/"
cp -a "$HOME/.local/share/nvim/site/pack"        "$STAGE/.local/share/nvim/site/"
[ -d "$HOME/.local/share/nvim/site/parser" ] && \
  cp -a "$HOME/.local/share/nvim/site/parser"    "$STAGE/.local/share/nvim/site/"

# 3. One tarball, rooted at $HOME so it extracts in place with `tar xz -C ~`.
tar czf "$OUT" -C "$STAGE" .
echo ">> built $OUT ($(du -h "$OUT" | cut -f1))"
