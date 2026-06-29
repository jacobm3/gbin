#!/usr/bin/env python3
"""Claude Code status line: hostname, dir, 'cc', model, session token burn, context fill.

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
    # Lower-case the id (and treat a missing id as "") so substring matches below
    # are case-insensitive.
    m = (model_id or "").lower()
    # Haiku is the small/cheap model with a 200k window.
    if "haiku" in m:
        return 200_000
    # The big models that ship a 1M-token window. We match by family name so a
    # version-suffixed id like "claude-opus-4-8-2026" still matches "opus-4-8".
    if any(fam in m for fam in ("fable", "mythos", "opus-4-8", "opus-4-7",
                                "opus-4-6", "sonnet-4-6")):
        return 1_000_000
    # Unknown model: assume the conservative 200k floor.
    return 200_000


def human(n):
    """1234 -> 1.2k, 1_200_000 -> 1.2M."""
    # Try millions first, then thousands. For each, if the number is at least
    # that big, divide and tack on the unit letter.
    for unit, size in (("M", 1_000_000), ("k", 1_000)):
        if n >= size:
            # Format to one decimal, then strip a trailing ".0" or trailing zero
            # so 1.0k shows as "1k" and 1.20k shows as "1.2k".
            return f"{n / size:.1f}".rstrip("0").rstrip(".") + unit
    # Smaller than 1000: just show the plain number.
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
    # Clamp the percent into 0..100 so a bad value can't over/under-fill the bar.
    pct = max(0.0, min(100.0, float(pct)))
    # How many of the `width` cells should be the solid "filled" block.
    filled = round(pct / 100 * width)
    # Pick the gauge color (grey/yellow/red) based on how full it is.
    color = usage_color(pct)
    # Build the gauge: colored solid blocks for the filled part, then dim light
    # blocks for the empty part, then reset the color.
    gauge = color + "█" * filled + DIM + "░" * (width - filled) + RESET
    # Wrap it in dim end-caps ▕ ▏ and append the numeric percent in the same color.
    return f"{DIM}▕{RESET}{gauge}{DIM}▏{RESET} {color}{round(pct)}%{RESET}"


def parse_transcript(path):
    """Return (total_tokens_consumed, current_context_tokens).

    total: every token billed this session (input + cache + output, all turns,
           including subagent sidechains) -- the real burn.
    context: input side of the latest main-chain request -- how full the window is.
    """
    # Running totals we will return.
    total = 0
    context = 0
    # No transcript yet (e.g. brand-new session): return zeros instead of erroring.
    if not path or not os.path.exists(path):
        return total, context
    # The transcript is JSON Lines: one JSON object per line. Read it line by line.
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            # Drop surrounding whitespace/newline.
            line = line.strip()
            # Skip blank lines.
            if not line:
                continue
            try:
                # Parse this line into a Python dict.
                rec = json.loads(line)
            except json.JSONDecodeError:
                # A half-written or malformed line: skip it rather than crash.
                continue
            # Only message records carry token usage; skip anything else.
            msg = rec.get("message")
            if not isinstance(msg, dict):
                continue
            usage = msg.get("usage")
            if not isinstance(usage, dict):
                continue
            # Pull the four token counters this turn reported (defaulting to 0).
            # inp = fresh input, cc = tokens written to cache, cr = tokens read
            # from cache, out = tokens the model generated.
            inp = usage.get("input_tokens", 0)
            cc = usage.get("cache_creation_input_tokens", 0)
            cr = usage.get("cache_read_input_tokens", 0)
            out = usage.get("output_tokens", 0)
            # Add everything to the lifetime burn for this session.
            total += inp + cc + cr + out
            # Context = input side of the most recent real (non-subagent) turn.
            # Subagent ("sidechain") turns have their own separate context, so we
            # ignore them here and keep overwriting with the latest main turn.
            if not rec.get("isSidechain"):
                context = inp + cc + cr
    return total, context


def main():
    try:
        # Claude Code pipes a JSON blob to us on stdin; parse it into a dict.
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        # If stdin is empty or not valid JSON, fall back to an empty dict so the
        # rest of the code can use .get(...) without crashing.
        data = {}

    # This machine's hostname, shown first in the status line.
    host = socket.gethostname()

    # Current directory name (just the basename, not the full path). Claude Code
    # puts the working dir in workspace.current_dir; fall back to top-level cwd.
    workspace = data.get("workspace") or {}
    cwd = workspace.get("current_dir") or data.get("cwd") or os.getcwd()
    dirname = os.path.basename(cwd.rstrip("/")) or cwd

    # Model name to display; prefer the friendly display_name, fall back to id.
    model = data.get("model") or {}
    model_name = model.get("display_name") or model.get("id") or "?"

    # How big the context window is for this model (e.g. 200k or 1M).
    limit = context_limit(model.get("id"))
    # Read lifetime burn and current context size out of the session transcript.
    total, context = parse_transcript(data.get("transcript_path"))
    # Percent of the context window currently used (guard against divide-by-zero).
    pct = round(context / limit * 100) if limit else 0

    # The separator drawn between each segment: a dim "|" with spaces around it.
    sep = f" {DIM}|{RESET} "
    # Build the list of colored segments left-to-right. join() stitches them with
    # `sep` at the end.
    parts = [
        f"{CYAN}{host}{RESET}",
        f"{YELLOW}{dirname}{RESET}",
        f"{DIM}cc{RESET}",
        f"{GREEN}{model_name}{RESET}",
        f"{DIM}tok{RESET} {human(total)}",
        f"{DIM}ctx{RESET} {human(context)}/{human(limit)} {YELLOW}{pct}%{RESET}",
    ]

    # Subscription usage (Pro/Max only; present after the first API response).
    # five_hour = the rolling session window /usage calls "current session";
    # seven_day = current week across all models. Each may be independently absent.
    # rate_limits holds the subscription usage. Each "... or {}" guards against a
    # missing/None section so the chained .get(...) never throws.
    rl = data.get("rate_limits") or {}
    # The rolling 5-hour session usage percentage (may be absent early on).
    session = (rl.get("five_hour") or {}).get("used_percentage")
    # The 7-day (weekly) usage percentage.
    week = (rl.get("seven_day") or {}).get("used_percentage")
    # Only show each gauge when its data is actually present, so we never draw a
    # misleading empty/zero bar before the first API response arrives.
    if session is not None:
        parts.append(f"{DIM}ses{RESET} {bar(session)}")
    if week is not None:
        parts.append(f"{DIM}wk{RESET} {bar(week)}")

    # Print the whole line with no trailing newline (end=""), because Claude Code
    # places this string into its single-line status bar.
    print(sep.join(parts), end="")


if __name__ == "__main__":
    main()
