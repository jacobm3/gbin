#!/usr/bin/env python3
"""Claude Code status line: hostname, project, session token burn, context fill.

Claude Code feeds this script a JSON blob on stdin (session_id, transcript_path,
workspace, model, ...). Per-turn token usage isn't in that blob, so we read it
from the session transcript (.jsonl) that Claude Code keeps appending to.

Wire it up in ~/.claude/settings.json:
  "statusLine": { "type": "command", "command": "python3 $HOME/gbin/claude/cc-statusline.py" }
"""
import json
import os
import socket
import sys

# Context window for the model family. exceeds_200k_tokens in the input blob
# confirms 200k is the meaningful threshold Claude Code itself watches.
CONTEXT_LIMIT = 200_000


def human(n):
    """1234 -> 1.2k, 1_200_000 -> 1.2M."""
    for unit, size in (("M", 1_000_000), ("k", 1_000)):
        if n >= size:
            return f"{n / size:.1f}".rstrip("0").rstrip(".") + unit
    return str(n)


def parse_transcript(path):
    """Return (total_tokens_consumed, current_context_tokens).

    total: every token billed this session (input + cache + output, all turns,
           including subagent sidechains) -- the real burn.
    context: input side of the latest main-chain request -- how full the window is.
    """
    total = 0
    context = 0
    if not path or not os.path.exists(path):
        return total, context
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg = rec.get("message")
            if not isinstance(msg, dict):
                continue
            usage = msg.get("usage")
            if not isinstance(usage, dict):
                continue
            inp = usage.get("input_tokens", 0)
            cc = usage.get("cache_creation_input_tokens", 0)
            cr = usage.get("cache_read_input_tokens", 0)
            out = usage.get("output_tokens", 0)
            total += inp + cc + cr + out
            # Context = input side of the most recent real (non-subagent) turn.
            if not rec.get("isSidechain"):
                context = inp + cc + cr
    return total, context


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        data = {}

    host = socket.gethostname()
    ws = data.get("workspace") or {}
    project_dir = ws.get("project_dir") or ws.get("current_dir") or data.get("cwd") or os.getcwd()
    project = os.path.basename(project_dir.rstrip("/")) or project_dir

    total, context = parse_transcript(data.get("transcript_path"))
    pct = round(context / CONTEXT_LIMIT * 100) if CONTEXT_LIMIT else 0

    # ANSI colors; degrade gracefully if the terminal ignores them.
    dim, cyan, green, yellow, reset = "\033[2m", "\033[36m", "\033[32m", "\033[33m", "\033[0m"
    sep = f" {dim}|{reset} "
    print(
        f"{cyan}{host}{reset}"
        f"{sep}{green}{project}{reset}"
        f"{sep}{dim}tok{reset} {human(total)}"
        f"{sep}{dim}ctx{reset} {human(context)}/{human(CONTEXT_LIMIT)} {yellow}{pct}%{reset}",
        end="",
    )


if __name__ == "__main__":
    main()
