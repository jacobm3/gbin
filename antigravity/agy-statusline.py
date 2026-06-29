#!/usr/bin/env python3
"""Antigravity CLI (agy) status line: hostname, directory, "agy", model, token burn, context fill, quota.

agy feeds this script a JSON blob on stdin (cwd/workspace, model, transcript_path,
context_window, tokens, rate_limits/quota, ...). Per-turn token usage isn't always
in that blob, so when a transcript path is provided we read usage straight from the
session transcript (.jsonl) that agy keeps appending to.

Wire it up in ~/.gemini/antigravity-cli/settings.json:
  "statusLine": { "type": "command", "command": "python3 $HOME/.gemini/antigravity-cli/agy-statusline.py" }
"""
import sys
import json
import os
import socket

# ANSI colors and formatting. Degrade gracefully if the terminal ignores them.
# GREY is a 256-color light grey used for the gauge's healthy state.
DIM, CYAN, GREEN, YELLOW, RED, GREY, MAGENTA, BLUE, RESET = (
    "\033[2m", "\033[36m", "\033[32m", "\033[33m", "\033[31m", "\033[38;5;243m", "\033[35m", "\033[34m", "\033[0m")


def format_tokens(num):
    """1234 -> 1.2k, 1_200_000 -> 1.2M."""
    # Treat a missing value as zero rather than crashing.
    if num is None:
        return "0"
    # Millions get an "M" suffix...
    if num >= 1_000_000:
        return f"{num / 1_000_000:.1f}M"
    # ...thousands get a "k" suffix...
    elif num >= 1_000:
        return f"{num / 1_000:.1f}k"
    # ...anything smaller is shown as the plain number.
    return str(num)


def context_limit(model_id):
    """Context window for the active model, derived from its id.

    Match by family substring so version-suffixed ids still resolve. Gemini and the
    current Fable/Opus/Sonnet families ship a 1M window; Haiku and older models are
    200k. Default to 1,048,576 (Gemini's native limit) for unknowns.
    """
    # Lower-case the id (treating a missing id as "") for case-insensitive matching.
    m = (model_id or "").lower()
    # Haiku is the small model with a 200k window.
    if "haiku" in m:
        return 200_000
    # Big 1M-window families, matched by name substring so version suffixes
    # still resolve. Gemini is included since this is the Antigravity CLI.
    if any(fam in m for fam in ("fable", "mythos", "opus-4-8", "opus-4-7",
                                "opus-4-6", "sonnet-4-6", "gemini")):
        return 1_000_000
    # Unknown model: default to Gemini's native 1,048,576-token limit.
    return 1_048_576


def usage_color(pct):
    """Light grey under 50%, yellow under 80%, red at/above -- a quiet quota gauge."""
    return GREY if pct < 50 else YELLOW if pct < 80 else RED


def bar(pct, width=12):
    """Render a quota gauge like ▕███░░░░░▏ 42%, colored by fill level."""
    # Clamp into 0..100 so a stray value can't over/under-fill the gauge.
    pct = max(0.0, min(100.0, float(pct)))
    # Number of solid cells to draw out of `width`.
    filled = round(pct / 100 * width)
    # Color chosen from fill level (grey/yellow/red).
    color = usage_color(pct)
    # Solid colored blocks for the used part, dim light blocks for the rest.
    gauge = color + "█" * filled + DIM + "░" * (width - filled) + RESET
    # Add dim end-caps and the numeric percent in the same color.
    return f"{DIM}▕{RESET}{gauge}{DIM}▏{RESET} {color}{round(pct)}%{RESET}"


def parse_transcript(path):
    """Return (total_tokens_consumed, current_context_tokens) from a session .jsonl.

    total: every token billed this session (input + cache + output, all turns,
           including subagent sidechains) -- the real burn.
    context: input side of the latest main-chain request -- how full the window is.
    """
    total = 0
    context = 0
    if not path:
        return total, context

    # agy sometimes reports the path under '/.gemini/antigravity/brain/' while the
    # file actually lives under '/.gemini/antigravity-cli/brain/'. Correct it.
    if not os.path.exists(path) and "/.gemini/antigravity/brain/" in path:
        alt_path = path.replace("/.gemini/antigravity/brain/", "/.gemini/antigravity-cli/brain/")
        if os.path.exists(alt_path):
            path = alt_path

    if not os.path.exists(path):
        return total, context

    try:
        # The transcript is JSON Lines: one JSON object per line.
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                # Trim whitespace/newline and skip blank lines.
                line = line.strip()
                if not line:
                    continue
                try:
                    # Parse the line into a dict.
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    # Skip a malformed/half-written line instead of crashing.
                    continue
                # Only message records carry token usage; skip everything else.
                msg = rec.get("message")
                if not isinstance(msg, dict):
                    continue
                usage = msg.get("usage")
                if not isinstance(usage, dict):
                    continue
                # The four token counters for this turn (default to 0 if absent):
                # fresh input, cache-write, cache-read, generated output.
                inp = usage.get("input_tokens", 0)
                cc = usage.get("cache_creation_input_tokens", 0)
                cr = usage.get("cache_read_input_tokens", 0)
                out = usage.get("output_tokens", 0)
                # Add all of it to the session-long burn total.
                total += inp + cc + cr + out
                # Context = input side of the most recent real (non-subagent) turn.
                # Subagent ("sidechain") turns have separate context, so skip them
                # and keep overwriting with the latest main-chain turn.
                if not rec.get("isSidechain"):
                    context = inp + cc + cr
    except Exception:
        # Any unexpected read/parse error: return whatever we have so far rather
        # than break the status line.
        pass
    return total, context


def main():
    try:
        # Load the status-line state agy hands us on stdin.
        input_data = sys.stdin.read().strip()
        data = json.loads(input_data) if input_data else {}
    except Exception:
        data = {}

    # Dump the raw payload to a file when DEBUG_STATUSLINE is set -- handy for
    # discovering which fields agy actually populates on a given version.
    if os.environ.get("DEBUG_STATUSLINE"):
        with open("/tmp/statusline_debug.log", "a") as f:
            f.write(json.dumps(data, indent=2) + "\n---\n")

    # Hostname (short form, no domain).
    hostname = socket.gethostname().split('.')[0]

    # Project directory -- basename of wherever agy is working.
    cwd = data.get("cwd") or data.get("workspace", {}).get("current_dir") or os.getcwd()
    project = os.path.basename(cwd.rstrip("/")) or cwd

    # Token and context-window metrics. Prefer the transcript (most accurate),
    # then fall back to whatever the payload exposes.
    ctx_info = data.get("context_window", {})
    tokens_info = data.get("tokens", {})
    model_id = (data.get("model") or {}).get("id")

    total_tokens, input_tokens = parse_transcript(data.get("transcript_path"))

    # Fallback to payload fields if transcript parsing returned nothing.
    if input_tokens == 0:
        input_tokens = (
            ctx_info.get("total_input_tokens") or
            ctx_info.get("used_tokens") or
            tokens_info.get("input") or
            0
        )

    if total_tokens == 0:
        total_tokens = input_tokens + (ctx_info.get("total_output_tokens") or tokens_info.get("output") or 0)

    # Context window limit, with model-derived fallback.
    limit_tokens = (
        ctx_info.get("context_window_size") or
        ctx_info.get("limit") or
        tokens_info.get("limit") or
        (context_limit(model_id) if model_id else 1_048_576)
    )

    # Used percentage of the context window.
    ctx_percent = (input_tokens / limit_tokens) * 100.0 if limit_tokens > 0 else 0.0

    # Model name to display; prefer the friendly display_name, fall back to id.
    model_info = data.get("model") or {}
    model_name = model_info.get("display_name") or model_info.get("id") or "Unknown"

    # Subscription/quota usage. agy has exposed this under a few different schemas
    # across versions, so try each: rate_limits.{five_hour,session,seven_day,weekly}
    # then the newer quota.{gemini-5h,gemini-weekly,3p-5h,3p-weekly} schema.
    rate_limits = data.get("rate_limits") or {}
    five_hour = rate_limits.get("five_hour") or {}
    session = rate_limits.get("session") or {}

    # Find the 5-hour ("session") used-percentage, trying each known field name
    # in priority order. This is a chained ternary: use five_hour.used_percentage
    # if present, else session.used_percentage if present, else the flat
    # five_hour_used_percent field. Ends up None if none of them exist.
    ses_percent = (
        five_hour.get("used_percentage")
        if five_hour.get("used_percentage") is not None
        else session.get("used_percentage")
        if session.get("used_percentage") is not None
        else rate_limits.get("five_hour_used_percent")
    )

    seven_day = rate_limits.get("seven_day") or {}
    weekly = rate_limits.get("weekly") or {}
    # Same chained-fallback idea for the weekly used-percentage: seven_day, then
    # weekly, then the two flat field names, settling on None if all are absent.
    wk_percent = (
        seven_day.get("used_percentage")
        if seven_day.get("used_percentage") is not None
        else weekly.get("used_percentage")
        if weekly.get("used_percentage") is not None
        else rate_limits.get("seven_day_used_percent")
        if rate_limits.get("seven_day_used_percent") is not None
        else rate_limits.get("weekly_used_percent")
    )

    # Newer quota schema (Antigravity CLI / agy). Values are remaining fractions,
    # so used% = (1 - remaining) * 100. Gemini quota first, then 3rd-party models.
    quota = data.get("quota") or {}
    if quota:
        # Pull out the four quota buckets (each may be missing -> empty dict).
        # gemini-* are Gemini's own quotas; 3p-* are third-party model quotas.
        gemini_5h = quota.get("gemini-5h") or {}
        gemini_wk = quota.get("gemini-weekly") or {}
        tp_5h = quota.get("3p-5h") or {}
        tp_wk = quota.get("3p-weekly") or {}

        # 5-hour remaining fraction: prefer Gemini's, fall back to third-party.
        rem_5h = gemini_5h.get("remaining_fraction")
        if rem_5h is None:
            rem_5h = tp_5h.get("remaining_fraction")

        # Weekly remaining fraction: same Gemini-then-third-party preference.
        rem_wk = gemini_wk.get("remaining_fraction")
        if rem_wk is None:
            rem_wk = tp_wk.get("remaining_fraction")

        # Only fill in the percentages we couldn't get from the older schema above.
        # remaining_fraction is how much is LEFT (1.0 = full), so used% is
        # (1 - remaining) * 100.
        if rem_5h is not None and ses_percent is None:
            ses_percent = (1.0 - float(rem_5h)) * 100.0

        if rem_wk is not None and wk_percent is None:
            wk_percent = (1.0 - float(rem_wk)) * 100.0

    # Assemble the line.
    tok_str = format_tokens(total_tokens)
    ctx_used_str = format_tokens(input_tokens)
    ctx_limit_str = format_tokens(limit_tokens)

    sep = f" {DIM}|{RESET} "
    parts = [
        f"{CYAN}{hostname}{RESET}",
        f"{GREEN}{project}{RESET}",
        f"{BLUE}agy{RESET}",
        f"{MAGENTA}{model_name}{RESET}",
        f"{DIM}tok{RESET} {tok_str}",
        f"{DIM}ctx{RESET} {ctx_used_str}/{ctx_limit_str} {YELLOW}{int(round(ctx_percent))}%{RESET}"
    ]

    # Show each quota gauge only when its data is actually present. Each may be
    # independently absent (e.g. on the first load before the first API response),
    # so we add them separately and stay silent on whatever's missing -- no
    # misleading empty bar, no "API ERR" noise.
    if ses_percent is not None:
        parts.append(f"{DIM}ses{RESET} {bar(ses_percent)}")
    if wk_percent is not None:
        parts.append(f"{DIM}wk{RESET} {bar(wk_percent)}")

    print(sep.join(parts))


if __name__ == "__main__":
    main()
