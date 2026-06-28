# Claude Code setup (`gbin/claude`)

Everything needed to configure Claude Code consistently on every machine that
has `gbin` cloned: shared global instructions, a one-shot setup script, and the
status line.

## Contents

| File | What it is |
|------|-----------|
| `CLAUDE-shared.md` | Global guidance imported by every machine's `~/.claude/CLAUDE.md`. Cross-machine facts only. |
| `setup-claude.sh` | One-shot, idempotent configurator for the current machine (import + qmd MCP + status line). |
| `install-statusline.sh` | Installs just the status line into `~/.claude/settings.json`. |
| `cc-statusline.py` | The status-line renderer (stdlib Python). |

## `CLAUDE-shared.md` — shared global guidance

Imported into each machine's `~/.claude/CLAUDE.md` via the first line
`@~/gbin/claude/CLAUDE-shared.md`, and synced everywhere by the hourly `gbin`
pull — so editing it changes Claude's behavior on all machines within the hour.

Put only things true on **every** machine here (qmd memory rules, SSH/Vault/ntfy
access, gitea conventions, comms/coding style). Machine-specific facts (e.g. a
host being a Proxmox hypervisor) go in that machine's own `~/.claude/CLAUDE.md`
below the import, where they can override the shared content.

## `setup-claude.sh` — configure this machine

Idempotent, safe to re-run. Does three things:

1. Ensures `~/.claude/CLAUDE.md` imports `CLAUDE-shared.md` as its first line
   (prepended to any existing file, leaving the rest untouched).
2. Registers the shared qmd memory MCP server (`qmd/setup`).
3. Installs the status line (`install-statusline.sh`).

```sh
~/gbin/claude/setup-claude.sh
```

Steps 2–3 only run if the `claude` CLI is present; a box without Claude Code
still gets the harmless CLAUDE.md import and skips the rest cleanly. Called
automatically by `../setup-new-machine.sh`, but fine to run on its own.

## Status line

`cc-statusline.py` renders a one-line status bar:

```
ml3090a | cpu-upgrade | tok 401.2k | ctx 31k/200k 16% | ses ▕███░░░░░░░░░▏ 24% | wk ▕█████░░░░░░░▏ 41%
```

- **hostname** — which machine you're on
- **project** — basename of the current project dir
- **tok** — total tokens consumed this session (input + cache + output, all turns)
- **ctx** — current context-window fill vs. the active model's limit, with %
  (1M for Fable 5 / Opus 4.8 / Sonnet 4.6, 200k for Haiku and older; derived
  from the model id Claude Code reports, 200k fallback for unknowns)
- **ses** — subscription usage for the current 5-hour session window (the
  `/usage` "current session" gauge)
- **wk** — subscription usage for the current week, across all models

`ses`/`wk` come from `rate_limits` in the status-line JSON — present for
Claude.ai Pro/Max only, after the first API response of a session. The bars are
hidden when that data isn't available (e.g. API-key auth). Gauges are green
below 50%, yellow below 80%, red above.

Token data isn't in the JSON Claude Code passes to the status line, so the
script reads it from the session transcript (`~/.claude/projects/.../*.jsonl`).

### Enable

Usually handled by `setup-claude.sh`. To do just the status line:

```sh
./install-statusline.sh              # configure THIS machine
./install-statusline.sh j@10.0.0.21 j@10.0.0.22   # ...or fan out over ssh
```

It patches `~/.claude/settings.json` (creating it if absent), leaving every
other setting untouched, and is idempotent — re-running just re-asserts the
block. Remote mode pipes the same script over ssh to each target, which already
has `~/gbin` if you ran `../git/add-gitea-dual-push.sh`. No Claude inference
involved. Restart / refresh Claude Code to pick it up.

To wire it up by hand instead, add to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "python3 $HOME/gbin/claude/cc-statusline.py"
}
```

Needs `python3` (stdlib only).
