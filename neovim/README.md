# nvim-install-reusable

One command to stand up a complete Neovim setup on this machine (or refresh it):
latest Neovim, the tree-sitter CLI, and your personal config/plugins bundle.

```bash
./install-nvim.sh
```

The script is **idempotent** — re-running it updates Neovim and tree-sitter only when
a newer release exists, and re-deploys your bundle after backing up the current state.

## What it does

1. **Neovim** — fetches the latest release `nvim-linux-x86_64.tar.gz`, extracts to
   `~/.local/nvim`, and symlinks `~/.local/bin/nvim`. No sudo. Skips the download if the
   installed version already matches the target tag.
2. **tree-sitter CLI** — installs the latest `tree-sitter-linux-x64.gz` release binary to
   `~/.local/bin/tree-sitter` (deliberately *not* via npm/cargo, which has been unreliable).
   Skips if already current.
3. **Bundle** — deploys `~/nvim-bundle.tar.gz` (config + plugins + precompiled parsers).
   Existing `~/.config/nvim`, `~/.local/share/nvim`, `~/.local/state/nvim`, and `~/.cache/nvim`
   are moved to `*.bak.<timestamp>` first, then the bundle is extracted into `$HOME`.
   The stale Neovim binary inside the bundle is excluded — step 1 provides the latest.

## Options

| Flag             | Effect                                  |
| ---------------- | --------------------------------------- |
| `--skip-nvim`    | don't install/update Neovim             |
| `--skip-ts`      | don't install/update the tree-sitter CLI|
| `--skip-bundle`  | don't deploy the bundle                 |
| `-h`, `--help`   | show usage                              |

| Env var        | Default               | Purpose                                          |
| -------------- | --------------------- | ------------------------------------------------ |
| `NVIM_VERSION` | `latest`              | `latest`, `nightly`, or an explicit tag (`v0.12.3`) |
| `NVIM_BUNDLE`  | `~/nvim-bundle.tar.gz`| path to the bundle tarball                       |

## Notes

- `~/.local/bin` must be on your `PATH`. If it isn't, the script prints the line to add.
- Backups are never deleted automatically. Remove old ones with
  `rm -rf ~/.config/nvim.bak.* ~/.local/share/nvim.bak.*` when you're confident.
- Refresh plugins after deploy:
  - offline (from bundled revisions): `nvim '+lua vim.pack.update(nil, { offline = true })'`
  - online (pull newest): open `nvim`, then `:lua vim.pack.update()`
