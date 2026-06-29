#!/usr/bin/env bash
# Install gitleaks (if missing) and activate this repo's committed git hooks.
#
# Run once per clone:   ./git/setup-githooks.sh
# Idempotent — safe to re-run. Derives the repo root from this script's own
# location, so it works regardless of the current directory (e.g. cloud-init).
# -u error on unset vars, -o pipefail propagate pipeline failures. No -e, so we
# can handle individual failures (like a missing gitleaks) with our own warnings.
set -uo pipefail

GITLEAKS_VERSION="8.30.1"   # pinned; falls back to latest release if this tag is gone

# --- resolve repo root from this script's location (CWD-independent) ---
# Absolute dir of this script (works no matter the current directory).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ask git for the repo's top-level dir, starting from this script's location.
# If git fails (not a repo), the `|| { ... }` block prints an error and exits.
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "setup-githooks: not inside a git repository ($SCRIPT_DIR)" >&2
  exit 1
}

# Function: download and install the gitleaks binary for this OS/arch.
install_gitleaks() {
  # `local` keeps these variables scoped to the function.
  local os arch ver url tmp
  # OS name lowercased to match the release asset naming (linux / darwin).
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"   # linux | darwin
  # Map the machine's CPU architecture to gitleaks' release naming.
  case "$(uname -m)" in
    x86_64|amd64)  arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l)        arch="armv7" ;;
    # Unknown arch: we can't pick an asset, so bail out of the function.
    *) echo "setup-githooks: unsupported arch $(uname -m); install gitleaks manually." >&2; return 1 ;;
  esac

  # Try the pinned version first; build its download URL.
  ver="$GITLEAKS_VERSION"
  url="https://github.com/gitleaks/gitleaks/releases/download/v${ver}/gitleaks_${ver}_${os}_${arch}.tar.gz"
  # Probe whether that URL exists before committing to it.
  #   curl -f fail on HTTP errors, -s silent, -I HEAD request (no body),
  #   -L follow redirects. If the HEAD fails, the pinned release is gone.
  if ! curl -fsIL "$url" >/dev/null 2>&1; then
    echo "setup-githooks: pinned v${ver} unavailable, resolving latest release..." >&2
    # Ask GitHub's API for the latest release and scrape its tag.
    #   grep -m1 '"tag_name"'  take the first line with the tag field.
    #   sed -E '.../\1/'       extract just the version, dropping a leading "v".
    ver="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
            | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
    # If we still couldn't determine a version, give up.
    [ -n "$ver" ] || { echo "setup-githooks: could not resolve a gitleaks version." >&2; return 1; }
    # Rebuild the URL with the resolved latest version.
    url="https://github.com/gitleaks/gitleaks/releases/download/v${ver}/gitleaks_${ver}_${os}_${arch}.tar.gz"
  fi

  echo "setup-githooks: installing gitleaks ${ver} (${os}/${arch})..."
  # Temp working dir for the download/extract; cleaned up at the end.
  tmp="$(mktemp -d)"
  # Download the tarball (-f fail on error, -s silent, -S show errors, -L follow
  # redirects) to the temp dir.
  curl -fsSL "$url" -o "$tmp/gitleaks.tar.gz"
  # Extract just the `gitleaks` binary from the archive into the temp dir.
  tar -xzf "$tmp/gitleaks.tar.gz" -C "$tmp" gitleaks
  # Install the binary to the best location we have rights to:
  # 1) if we can sudo without a password, put it system-wide in /usr/local/bin.
  if sudo -n true 2>/dev/null; then
    sudo install -m0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
  # 2) else if /usr/local/bin is writable by us, install there directly.
  elif [ -w /usr/local/bin ]; then
    install -m0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
  # 3) otherwise fall back to a per-user location and remind about PATH.
  else
    mkdir -p "$HOME/.local/bin"
    install -m0755 "$tmp/gitleaks" "$HOME/.local/bin/gitleaks"
    echo "setup-githooks: installed to ~/.local/bin — ensure it is on your PATH." >&2
  fi
  # Remove the temp dir and its contents.
  rm -rf "$tmp"
}

# Install gitleaks only if it isn't already on PATH.
if command -v gitleaks >/dev/null 2>&1; then
  echo "setup-githooks: gitleaks already present ($(gitleaks version 2>/dev/null))."
else
  # Try to install; if that fails, warn but keep going (hooks just won't pass yet).
  install_gitleaks || echo "setup-githooks: WARNING — gitleaks not installed; the hook will fail until it is." >&2
fi

# --- activate the committed hooks for THIS clone ---
# Tell git to run hooks from the repo's tracked .githooks dir instead of the
# default (untracked) .git/hooks. This is what makes the committed hooks active.
git -C "$REPO_ROOT" config core.hooksPath .githooks
# Make the hook scripts executable so git can run them. `|| true` so a missing
# dir / no matches doesn't abort the script.
chmod +x "$REPO_ROOT"/.githooks/* 2>/dev/null || true

# Confirm the result by echoing back the configured hooksPath.
echo "setup-githooks: done. core.hooksPath=$(git -C "$REPO_ROOT" config core.hooksPath) in $REPO_ROOT"
