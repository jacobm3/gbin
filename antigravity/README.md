# Antigravity CLI (agy) status line

`agy-statusline.py` renders a one-line status bar for the Antigravity CLI:

```
pve3 | antigravity | Gemini 3.5 Flash (High) | tok 401.2k | ctx 31k/1M 3% | ses ▕███░░░░░░░░░▏ 24% | wk ▕█████░░░░░░░▏ 41%
```

- **hostname** — which machine you're on
- **project** — basename of agy's current working dir
- **model** — the active model's display name
- **tok** — total tokens consumed this session (input + cache + output, all turns)
- **ctx** — current context-window fill vs. the active model's limit, with %
  (1M for Gemini / Fable 5 / Opus 4.8 / Sonnet 4.6, 200k for Haiku and older,
  ~1M fallback for unknowns)
- **ses** — quota used for the current 5-hour window
- **wk** — quota used for the current week

`ses`/`wk` come from the `rate_limits` / `quota` fields in the status-line JSON.
Each gauge is hidden when its data isn't available (e.g. on the first load,
before the first API response), rather than showing an empty/misleading bar.
Gauges are grey below 50%, yellow below 80%, red above.

Token data isn't always in the JSON agy passes to the status line, so the
script reads it from the session transcript (`.jsonl`) when a path is provided,
falling back to the payload fields otherwise.

## Install

The script ships with this repo, so on any machine that has `gbin` cloned the
only step is running the installer:

```sh
./install-statusline.sh              # configure THIS machine
./install-statusline.sh j@10.0.0.21 j@10.0.0.22   # ...or fan out over ssh
```

It does two things, both idempotent:

1. Copies `agy-statusline.py` into `~/.gemini/antigravity-cli/agy-statusline.py`
   and makes it executable.
2. Parses `~/.gemini/antigravity-cli/settings.json` and sets the `statusLine`
   block to run that copy. It **only** touches `statusLine` — every other
   setting (model, colorScheme, permissions, …) is preserved. An existing
   `statusLine` is replaced; if there's none, one is added. The file is created
   if it doesn't exist.

Remote mode pipes the same script over ssh to each target, which must already
have `~/gbin` checked out and `python3` installed. Restart / refresh agy to
pick it up.

To wire it up by hand instead, copy the script where you like and add to
`~/.gemini/antigravity-cli/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "python3 $HOME/.gemini/antigravity-cli/agy-statusline.py"
}
```

Needs `python3` (stdlib only).
