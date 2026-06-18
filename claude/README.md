# Claude Code status line

`cc-statusline.py` renders a one-line status bar:

```
pve3 | cc-status-line | tok 401.2k | ctx 31k/200k 16%
```

- **hostname** — which machine you're on
- **project** — basename of the current project dir
- **tok** — total tokens consumed this session (input + cache + output, all turns)
- **ctx** — current context-window fill vs. the active model's limit, with %
  (1M for Fable 5 / Opus 4.8 / Sonnet 4.6, 200k for Haiku and older; derived
  from the model id Claude Code reports, 200k fallback for unknowns)

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
