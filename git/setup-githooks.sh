#!/usr/bin/env bash
# Install gitleaks (if missing) and activate this repo's committed git hooks.
#
# Run once per clone:   ./git/setup-githooks.sh
# Idempotent — safe to re-run. Derives the repo root from this script's own
# location, so it works regardless of the current directory (e.g. cloud-init).
set -uo pipefail

GITLEAKS_VERSION="8.30.1"   # pinned; falls back to latest release if this tag is gone

# --- resolve repo root from this script's location (CWD-independent) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "setup-githooks: not inside a git repository ($SCRIPT_DIR)" >&2
  exit 1
}

install_gitleaks() {
  local os arch ver url tmp
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"   # linux | darwin
  case "$(uname -m)" in
    x86_64|amd64)  arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l)        arch="armv7" ;;
    *) echo "setup-githooks: unsupported arch $(uname -m); install gitleaks manually." >&2; return 1 ;;
  esac

  ver="$GITLEAKS_VERSION"
  url="https://github.com/gitleaks/gitleaks/releases/download/v${ver}/gitleaks_${ver}_${os}_${arch}.tar.gz"
  if ! curl -fsIL "$url" >/dev/null 2>&1; then
    echo "setup-githooks: pinned v${ver} unavailable, resolving latest release..." >&2
    ver="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
            | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
    [ -n "$ver" ] || { echo "setup-githooks: could not resolve a gitleaks version." >&2; return 1; }
    url="https://github.com/gitleaks/gitleaks/releases/download/v${ver}/gitleaks_${ver}_${os}_${arch}.tar.gz"
  fi

  echo "setup-githooks: installing gitleaks ${ver} (${os}/${arch})..."
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/gitleaks.tar.gz"
  tar -xzf "$tmp/gitleaks.tar.gz" -C "$tmp" gitleaks
  if sudo -n true 2>/dev/null; then
    sudo install -m0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
  elif [ -w /usr/local/bin ]; then
    install -m0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
  else
    mkdir -p "$HOME/.local/bin"
    install -m0755 "$tmp/gitleaks" "$HOME/.local/bin/gitleaks"
    echo "setup-githooks: installed to ~/.local/bin — ensure it is on your PATH." >&2
  fi
  rm -rf "$tmp"
}

if command -v gitleaks >/dev/null 2>&1; then
  echo "setup-githooks: gitleaks already present ($(gitleaks version 2>/dev/null))."
else
  install_gitleaks || echo "setup-githooks: WARNING — gitleaks not installed; the hook will fail until it is." >&2
fi

# --- activate the committed hooks for THIS clone ---
git -C "$REPO_ROOT" config core.hooksPath .githooks
chmod +x "$REPO_ROOT"/.githooks/* 2>/dev/null || true

echo "setup-githooks: done. core.hooksPath=$(git -C "$REPO_ROOT" config core.hooksPath) in $REPO_ROOT"
