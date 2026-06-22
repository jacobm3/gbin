#!/usr/bin/env python3
"""Claude Code status line: hostname, 'cc', model, session token burn, context fill.

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

def context_limit(model_id):
    """Context window for the active model, derived from its id.

    Current Fable/Opus/Sonnet ship a 1M window; Haiku and older models are 200k.
    Match by family substring so version-suffixed ids still resolve; default to
    200k (the conservative floor, matching Claude Code's exceeds_200k_tokens flag).
    """
    m = (model_id or "").lower()
    if "haiku" in m:
        return 200_000
    if any(fam in m for fam in ("fable", "mythos", "opus-4-8", "opus-4-7",
                                "opus-4-6", "sonnet-4-6")):
        return 1_000_000
    return 200_000


def human(n):
    """1234 -> 1.2k, 1_200_000 -> 1.2M."""
    for unit, size in (("M", 1_000_000), ("k", 1_000)):
        if n >= size:
            return f"{n / size:.1f}".rstrip("0").rstrip(".") + unit
    return str(n)


# ANSI; degrade gracefully if the terminal ignores them. GREY is a 256-color
# light grey for the gauge's healthy state — quiet, so it doesn't pull the eye.
DIM, CYAN, GREEN, YELLOW, RED, GREY, RESET = (
    "\033[2m", "\033[36m", "\033[32m", "\033[33m", "\033[31m", "\033[38;5;243m", "\033[0m")


def usage_color(pct):
    """Light grey under 50%, yellow under 80%, red at/above — a quiet quota gauge."""
    return GREY if pct < 50 else YELLOW if pct < 80 else RED


def bar(pct, width=12):
    """Render a quota gauge like ▕███░░░░░▏ 42%, colored by fill level."""
    pct = max(0.0, min(100.0, float(pct)))
    filled = round(pct / 100 * width)
    color = usage_color(pct)
    gauge = color + "█" * filled + DIM + "░" * (width - filled) + RESET
    return f"{DIM}▕{RESET}{gauge}{DIM}▏{RESET} {color}{round(pct)}%{RESET}"


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

    # Model name to display; prefer the friendly display_name, fall back to id.
    model = data.get("model") or {}
    model_name = model.get("display_name") or model.get("id") or "?"

    limit = context_limit(model.get("id"))
    total, context = parse_transcript(data.get("transcript_path"))
    pct = round(context / limit * 100) if limit else 0

    sep = f" {DIM}|{RESET} "
    parts = [
        f"{CYAN}{host}{RESET}",
        f"{DIM}cc{RESET}",
        f"{GREEN}{model_name}{RESET}",
        f"{DIM}tok{RESET} {human(total)}",
        f"{DIM}ctx{RESET} {human(context)}/{human(limit)} {YELLOW}{pct}%{RESET}",
    ]

    # Subscription usage (Pro/Max only; present after the first API response).
    # five_hour = the rolling session window /usage calls "current session";
    # seven_day = current week across all models. Each may be independently absent.
    rl = data.get("rate_limits") or {}
    session = (rl.get("five_hour") or {}).get("used_percentage")
    week = (rl.get("seven_day") or {}).get("used_percentage")
    if session is not None:
        parts.append(f"{DIM}ses{RESET} {bar(session)}")
    if week is not None:
        parts.append(f"{DIM}wk{RESET} {bar(week)}")

    print(sep.join(parts), end="")


if __name__ == "__main__":
    main()
