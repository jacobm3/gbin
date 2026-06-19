#!/usr/bin/env bash
#
# install-nvim.sh — idempotent, one-command Neovim deployment.
#
#   1. Installs/updates the latest Neovim (user-local, no sudo).
#   2. Installs/updates the tree-sitter CLI separately (release binary).
#   3. Deploys ~/nvim-bundle.tar.gz (config + plugins + precompiled parsers),
#      backing up any existing config/data to timestamped dirs first.
#
# Usage:   ./install-nvim.sh [--skip-nvim] [--skip-ts] [--skip-bundle] [-h]
#
# Env:
#   NVIM_VERSION   latest (default) | nightly | explicit tag (e.g. v0.12.3)
#   NVIM_BUNDLE    path to the bundle tarball (default: ~/nvim-bundle.tar.gz)
#
set -euo pipefail

# --- config ---------------------------------------------------------------
NVIM_PREFIX="$HOME/.local/nvim"
BIN_DIR="$HOME/.local/bin"
BUNDLE="${NVIM_BUNDLE:-$HOME/nvim-bundle.tar.gz}"
NVIM_VERSION="${NVIM_VERSION:-latest}"
NVIM_ASSET="nvim-linux-x86_64.tar.gz"
TS_ASSET="tree-sitter-linux-x64.gz"

DO_NVIM=1 DO_TS=1 DO_BUNDLE=1

# --- helpers --------------------------------------------------------------
log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

gh_latest_tag() {  # repo -> tag_name of the newest stable release
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" | jq -r '.tag_name'
}

# --- arg parsing ----------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --skip-nvim)   DO_NVIM=0 ;;
    --skip-ts)     DO_TS=0 ;;
    --skip-bundle) DO_BUNDLE=0 ;;
    -h|--help)     usage ;;
    *) die "unknown argument: $arg (try --help)" ;;
  esac
done

# --- scratch dir ----------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- phase 0: preflight ---------------------------------------------------
log "Preflight checks"
[ "$(uname -s)" = "Linux" ]   || die "this installer targets Linux"
[ "$(uname -m)" = "x86_64" ]  || die "this installer targets x86_64 (got $(uname -m))"
for t in curl jq tar gzip git; do
  command -v "$t" >/dev/null 2>&1 || die "missing required tool: $t"
done
command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 \
  || warn "no C compiler (cc/gcc) found — tree-sitter parser compilation may fail"

mkdir -p "$BIN_DIR"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on your PATH. Add this to your shell rc:"
     info "export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# --- phase 1: neovim ------------------------------------------------------
if [ "$DO_NVIM" -eq 1 ]; then
  log "Neovim (channel: $NVIM_VERSION)"

  case "$NVIM_VERSION" in
    latest)  target_tag="$(gh_latest_tag neovim/neovim)" ;;
    *)       target_tag="$NVIM_VERSION" ;;
  esac
  [ -n "$target_tag" ] && [ "$target_tag" != "null" ] || die "could not resolve Neovim tag"
  info "target: $target_tag"

  installed_tag=""
  if [ -x "$BIN_DIR/nvim" ]; then
    installed_tag="$("$BIN_DIR/nvim" --version 2>/dev/null | head -1 | awk '{print $2}')"
    info "installed: ${installed_tag:-none}"
  fi

  # For an explicit/stable tag we can compare directly. "nightly" reuses the same
  # tag string every release, so always reinstall it to be safe.
  if [ "$NVIM_VERSION" != "nightly" ] && [ "$installed_tag" = "$target_tag" ]; then
    info "already current — skipping download"
  else
    url="https://github.com/neovim/neovim/releases/download/$target_tag/$NVIM_ASSET"
    info "downloading $url"
    curl -fSL --retry 3 -o "$TMP/$NVIM_ASSET" "$url" || die "Neovim download failed"
    tar tzf "$TMP/$NVIM_ASSET" >/dev/null 2>&1 || die "downloaded Neovim tarball is corrupt"

    rm -rf "$NVIM_PREFIX"
    mkdir -p "$NVIM_PREFIX"
    tar xzf "$TMP/$NVIM_ASSET" -C "$NVIM_PREFIX" --strip-components=1
    ln -sfn "$NVIM_PREFIX/bin/nvim" "$BIN_DIR/nvim"
    info "installed -> $BIN_DIR/nvim"
  fi
  "$BIN_DIR/nvim" --version | head -1
fi

# --- phase 2: tree-sitter cli ---------------------------------------------
# The tree-sitter CLI is OPTIONAL: it only compiles *new* parsers. The bundle
# already ships precompiled parsers, so nothing here may abort the install.
# Notably, recent release binaries are built against newer glibc than some
# stable distros provide (e.g. Debian 12 / glibc 2.36), so the binary may
# download fine yet fail to exec. We detect that and warn rather than die.
install_tree_sitter() {  # returns nonzero on any problem; never aborts the script
  ts_tag="$(gh_latest_tag tree-sitter/tree-sitter)"
  [ -n "$ts_tag" ] && [ "$ts_tag" != "null" ] || { warn "could not resolve tree-sitter tag — skipping"; return 1; }
  ts_target="${ts_tag#v}"
  info "target: $ts_tag"

  ts_installed=""
  if [ -x "$BIN_DIR/tree-sitter" ]; then
    ts_installed="$("$BIN_DIR/tree-sitter" --version 2>/dev/null | awk '{print $2}')"
    info "installed: ${ts_installed:-none}"
  fi

  if [ "$ts_installed" = "$ts_target" ]; then
    info "already current — skipping download"
  else
    url="https://github.com/tree-sitter/tree-sitter/releases/download/$ts_tag/$TS_ASSET"
    info "downloading $url"
    curl -fSL --retry 3 -o "$TMP/$TS_ASSET" "$url" || { warn "tree-sitter download failed — skipping"; return 1; }
    gunzip -c "$TMP/$TS_ASSET" > "$TMP/tree-sitter" || { warn "tree-sitter extract failed — skipping"; return 1; }
    chmod +x "$TMP/tree-sitter"
    # Verify it actually runs (catches glibc mismatches) before installing it.
    if ! ver="$("$TMP/tree-sitter" --version 2>&1)"; then
      warn "tree-sitter binary will not run on this system — skipping:"
      info "$ver"
      info "(usually a glibc mismatch; the bundle's precompiled parsers still work.)"
      return 1
    fi
    mv "$TMP/tree-sitter" "$BIN_DIR/tree-sitter"
    info "installed -> $BIN_DIR/tree-sitter"
  fi
  "$BIN_DIR/tree-sitter" --version
}

if [ "$DO_TS" -eq 1 ]; then
  log "tree-sitter CLI"
  install_tree_sitter || warn "tree-sitter CLI not installed (optional) — continuing"
fi

# --- phase 3: deploy bundle -----------------------------------------------
if [ "$DO_BUNDLE" -eq 1 ]; then
  log "Deploy bundle"
  [ -f "$BUNDLE" ] || die "bundle not found: $BUNDLE (set NVIM_BUNDLE to override)"
  info "bundle: $BUNDLE"

  ts="$(date +%Y%m%d-%H%M%S)"
  backed_up=0
  for d in "$HOME/.config/nvim" "$HOME/.local/share/nvim" \
           "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    if [ -e "$d" ]; then
      mv "$d" "$d.bak.$ts"
      info "backed up $d -> $d.bak.$ts"
      backed_up=1
    fi
  done
  [ "$backed_up" -eq 1 ] || info "no existing nvim dirs to back up (clean install)"

  # Bundle is rooted at ./ with ./.config and ./.local; land it in $HOME.
  # Exclude the stale bundled nvim binary — phase 1 provides the latest.
  tar xzf "$BUNDLE" -C "$HOME" --exclude='./.local/nvim-linux-x86_64'
  info "extracted bundle into $HOME"
fi

# --- phase 4: verify ------------------------------------------------------
log "Verify"
if command -v "$BIN_DIR/nvim" >/dev/null 2>&1; then
  "$BIN_DIR/nvim" --version | head -1
  "$BIN_DIR/nvim" --headless "+lua print('config dir: '..vim.fn.stdpath('config'))" +qa 2>&1 || \
    warn "nvim reported errors loading the config (see above)"
  parser_count="$("$BIN_DIR/nvim" --headless \
    "+lua io.write(#(vim.fn.globpath(vim.fn.stdpath('data')..'/site/parser','*.so',0,1)))" +qa 2>/dev/null || echo '?')"
  info "precompiled tree-sitter parsers in data dir: $parser_count"
fi
if [ -x "$BIN_DIR/tree-sitter" ]; then
  "$BIN_DIR/tree-sitter" --version || warn "tree-sitter installed but not runnable (optional)"
fi
exit 0

log "Done."
info "Refresh plugins offline:  nvim '+lua vim.pack.update(nil, { offline = true })'"
info "Refresh plugins online:   nvim  (then  :lua vim.pack.update())"
