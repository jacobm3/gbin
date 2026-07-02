#!/usr/bin/env python3
"""Qwen Code status line: hostname, dir, 'qwen', model, tokens, context fill, GPU stats.

Qwen Code feeds this script a JSON blob on stdin (model, context_window,
workspace, ...) just like Claude Code does for cc-statusline.py. Instead of
subscription usage (meaningless for a local llama.cpp server) we show live GPU
stats for the RTX 3090 on ml3090a that serves the model.

GPU stats come from the prometheus + dcgm-exporter stack on ml3090a
(http://ml3090a.mink-neon.ts.net:9090), so this works from ANY machine on the
tailnet, not just ml3090a itself.

Wire it up in ~/.qwen/settings.json:
  "ui": {
    "statusLine": {
      "type": "command",
      "command": "python3 $HOME/gbin/claude/qwen-statusline.py",
      "refreshInterval": 5
    }
  }
"""
import json
import os
import socket
import sys
import urllib.parse
import urllib.request

# Where the GPU metrics live (prometheus scraping dcgm-exporter on ml3090a).
PROMETHEUS = "http://ml3090a.mink-neon.ts.net:9090"

# ANSI colors; same palette as cc-statusline.py so both status lines match.
DIM, CYAN, GREEN, YELLOW, RED, GREY, RESET = (
    "\033[2m", "\033[36m", "\033[32m", "\033[33m", "\033[31m",
    "\033[38;5;243m", "\033[0m")


def human(n):
    """1234 -> 1.2k, 1_200_000 -> 1.2M."""
    for unit, size in (("M", 1_000_000), ("k", 1_000)):
        if n >= size:
            return f"{n / size:.1f}".rstrip("0").rstrip(".") + unit
    return str(int(n))


def usage_color(pct):
    """Light grey under 50%, yellow under 80%, red at/above."""
    return GREY if pct < 50 else YELLOW if pct < 80 else RED


def gpu_stats():
    """Fetch GPU util/power/temp/vram from prometheus. Returns dict or None.

    Short timeout so the status line never hangs if ml3090a is unreachable --
    we just skip the GPU section in that case.
    """
    query = '{__name__=~"DCGM_FI_DEV_(GPU_UTIL|POWER_USAGE|GPU_TEMP|FB_USED)"}'
    url = PROMETHEUS + "/api/v1/query?" + urllib.parse.urlencode({"query": query})
    try:
        with urllib.request.urlopen(url, timeout=1.5) as resp:
            data = json.load(resp)
    except Exception:
        return None
    stats = {}
    for item in data.get("data", {}).get("result", []):
        name = item["metric"]["__name__"]
        stats[name] = float(item["value"][1])
    return stats or None


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        data = {}

    host = socket.gethostname()

    # Current directory name (basename only, like cc-statusline.py).
    workspace = data.get("workspace") or {}
    cwd = workspace.get("current_dir") or os.getcwd()
    dirname = os.path.basename(cwd.rstrip("/")) or cwd

    model = (data.get("model") or {}).get("display_name") or "?"

    # Qwen Code hands us context usage directly -- no transcript parsing needed.
    ctx = data.get("context_window") or {}
    used = ctx.get("current_usage") or 0
    size = ctx.get("context_window_size") or 0
    pct = ctx.get("used_percentage") or 0
    total = (ctx.get("total_input_tokens") or 0) + (ctx.get("total_output_tokens") or 0)

    sep = f" {DIM}|{RESET} "
    parts = [
        f"{CYAN}{host}{RESET}",
        f"{YELLOW}{dirname}{RESET}",
        f"{DIM}qwen{RESET}",
        f"{GREEN}{model}{RESET}",
        f"{DIM}tok{RESET} {human(total)}",
        f"{DIM}ctx{RESET} {human(used)}/{human(size)} {YELLOW}{round(pct)}%{RESET}",
    ]

    # GPU section: util%, power W, temp C, VRAM used. Skipped if prometheus
    # is unreachable (e.g. ml3090a is off).
    gpu = gpu_stats()
    if gpu:
        util = gpu.get("DCGM_FI_DEV_GPU_UTIL", 0)
        power = gpu.get("DCGM_FI_DEV_POWER_USAGE", 0)
        temp = gpu.get("DCGM_FI_DEV_GPU_TEMP", 0)
        vram_mib = gpu.get("DCGM_FI_DEV_FB_USED", 0)
        # temp coloring: fine to 70C, warm to 83C (3090 throttle), red above
        tcolor = GREY if temp < 70 else YELLOW if temp < 83 else RED
        parts.append(
            f"{DIM}gpu{RESET} {usage_color(util)}{round(util)}%{RESET}"
            f" {round(power)}W"
            f" {tcolor}{round(temp)}C{RESET}"
            f" {round(vram_mib / 1024, 1)}G"
        )

    print(sep.join(parts), end="")


if __name__ == "__main__":
    main()
