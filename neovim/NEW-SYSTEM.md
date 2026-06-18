# Deploying to a new system

How to get your full Neovim setup onto a fresh machine with one command.

## 1. Requirements

- **Linux on x86_64** (the installer asserts both).
- These tools on `PATH`: `curl`, `jq`, `tar`, `gzip`, `git`.
  On Debian/Ubuntu: `sudo apt install -y curl jq tar gzip git`.
- A **C compiler** (`gcc`/`cc`) for compiling new tree-sitter parsers. The script only
  warns if it's missing, but you'll want it: `sudo apt install -y build-essential`.
- `~/.local/bin` on your `PATH`. If it isn't, the script prints the line to add; put it
  in your shell rc:
  ```bash
  export PATH="$HOME/.local/bin:$PATH"
  ```

No `sudo` is needed for the installer itself — everything lands under `~/.local`.

## 2. Copy two files to the new machine

1. `install-nvim.sh` (this repo).
2. Your bundle, placed at `~/nvim-bundle.tar.gz` (or anywhere, then point `NVIM_BUNDLE` at it).

```bash
# from a machine that has them, e.g.:
scp install-nvim.sh you@newhost:~/
scp nvim-bundle.tar.gz you@newhost:~/
```

## 3. Run it

```bash
chmod +x install-nvim.sh
./install-nvim.sh
```

That installs the latest Neovim, the tree-sitter CLI, and deploys your config + plugins +
precompiled parsers. Open `nvim` to confirm.

## 4. Refresh plugins (optional)

The bundle ships working plugins. To update them once online:

```bash
nvim                       # then run:  :lua vim.pack.update()
```

Or stay on the bundled revisions offline:

```bash
nvim '+lua vim.pack.update(nil, { offline = true })'
```

## Common variations

```bash
# bundle lives somewhere else
NVIM_BUNDLE=/mnt/usb/nvim-bundle.tar.gz ./install-nvim.sh

# pin a specific Neovim, or track nightly
NVIM_VERSION=v0.12.3 ./install-nvim.sh
NVIM_VERSION=nightly ./install-nvim.sh

# only install the tools, skip deploying the bundle
./install-nvim.sh --skip-bundle
```

## Notes

- Re-running is safe: Neovim and tree-sitter update only when a newer release exists; the
  bundle re-deploys after backing up any existing config/data to `*.bak.<timestamp>` dirs.
- Backups are never auto-deleted. Prune them when confident:
  `rm -rf ~/.config/nvim.bak.* ~/.local/share/nvim.bak.*`
- Other architectures (e.g. arm64): the install URLs are hard-coded to `linux-x86_64` /
  `linux-x64`. Swap the `NVIM_ASSET` / `TS_ASSET` names in the script for the arm64 assets.
