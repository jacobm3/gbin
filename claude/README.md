# Claude Code status line

`cc-statusline.py` renders a one-line status bar:

```
pve3 | cc-status-line | tok 401.2k | ctx 31k/200k 16%
```

- **hostname** — which machine you're on
- **project** — basename of the current project dir
- **tok** — total tokens consumed this session (input + cache + output, all turns)
- **ctx** — current context-window fill vs. the 200k limit, with %

Token data isn't in the JSON Claude Code passes to the status line, so the
script reads it from the session transcript (`~/.claude/projects/.../*.jsonl`).

## Enable

Add to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "python3 $HOME/gbin/claude/cc-statusline.py"
}
```

Needs `python3` (stdlib only). Restart / refresh Claude Code to pick it up.
