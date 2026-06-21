#!/usr/bin/env python3
"""chrome-tab-reaper — kill Chrome/Chromium renderer processes ("tabs")
that exceed a RAM threshold (default 4 GiB RSS).

Each browser tab is backed by a `--type=renderer` process; killing one frees
its memory and shows the tab an "Aw, Snap" page (the rest of the browser and
other tabs are unaffected). Stdlib only — reads /proc directly. Designed to
run hourly from a systemd timer.

Configuration via environment variables:
  THRESHOLD_GB   RAM threshold in GiB (RSS)      (default 4)
  DRY_RUN        1/true = log only, never kill   (default off)
  TERM_GRACE     seconds to wait after SIGTERM   (default 5)
  LOG_FILE       timestamped log file to append  (default /var/log/chrome-tab-reaper/reaper.log)
"""

import datetime
import glob
import os
import signal
import sys
import time

THRESHOLD_GB = float(os.environ.get("THRESHOLD_GB", "4"))
THRESHOLD_BYTES = int(THRESHOLD_GB * 1024 ** 3)
DRY_RUN = os.environ.get("DRY_RUN", "").lower() in ("1", "true", "yes", "on")
TERM_GRACE = float(os.environ.get("TERM_GRACE", "5"))
LOG_FILE = os.environ.get("LOG_FILE", "/var/log/chrome-tab-reaper/reaper.log")

PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")
CHROME_HINTS = ("chrome", "chromium")

_logfh = None


def _open_log():
    """Open the timestamped log file for appending; fall back to stdout-only."""
    global _logfh
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        _logfh = open(LOG_FILE, "a", buffering=1)
    except OSError as e:
        print(f"warning: cannot write log file {LOG_FILE}: {e}", file=sys.stderr)
        _logfh = None


def log(msg):
    """Emit a timestamped line to stdout (-> journald) and the log file."""
    stamp = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    line = f"{stamp} {msg}"
    print(line, flush=True)
    if _logfh:
        _logfh.write(line + "\n")


def read_cmdline(pid):
    # Normally /proc/<pid>/cmdline is NUL-separated, but Chrome/Chromium (and
    # other Electron/Chromium apps) rewrite their argv in place to set the
    # process title, which collapses the args into a single space-separated
    # blob. Normalize NUL -> space and split on whitespace to handle both.
    with open(f"/proc/{pid}/cmdline", "rb") as f:
        raw = f.read()
    text = raw.replace(b"\0", b" ").decode("utf-8", "replace")
    return text.split()


def rss_bytes(pid):
    # /proc/<pid>/statm field 2 = resident set size, in pages.
    with open(f"/proc/{pid}/statm") as f:
        resident_pages = int(f.read().split()[1])
    return resident_pages * PAGE_SIZE


def is_chrome_renderer(argv):
    if not argv or "--type=renderer" not in argv:
        return False
    exe = os.path.basename(argv[0]).lower()
    return any(hint in exe for hint in CHROME_HINTS)


def renderer_label(argv):
    """Best-effort identifying bits — renderer argv carries no tab title/URL."""
    bits = [a for a in argv if a.startswith("--extension-process")
            or a.startswith("--renderer-client-id")
            or a.startswith("--js-flags")]
    return " ".join(bits) if bits else "(renderer)"


def kill_proc(pid):
    if DRY_RUN:
        return "dry-run (not killed)"
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return "already gone"
    except PermissionError:
        return "permission denied"
    deadline = time.monotonic() + TERM_GRACE
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return "terminated (SIGTERM)"
        time.sleep(0.2)
    try:
        os.kill(pid, signal.SIGKILL)
        return "killed (SIGKILL after grace)"
    except ProcessLookupError:
        return "terminated (SIGTERM)"


def main():
    _open_log()
    scanned = 0
    killed = 0
    for path in glob.glob("/proc/[0-9]*"):
        pid = int(os.path.basename(path))
        if pid == os.getpid():
            continue
        try:
            argv = read_cmdline(pid)
            if not is_chrome_renderer(argv):
                continue
            scanned += 1
            rss = rss_bytes(pid)
        except (FileNotFoundError, ProcessLookupError, PermissionError, ValueError):
            continue  # process vanished or unreadable between glob and read
        if rss > THRESHOLD_BYTES:
            result = kill_proc(pid)
            killed += 1
            log(f"KILL pid={pid} rss={rss / 1024 ** 3:.2f}GiB "
                f"threshold={THRESHOLD_GB}GiB {renderer_label(argv)} -> {result}")

    mode = " [DRY-RUN]" if DRY_RUN else ""
    log(f"run complete{mode}: renderers_scanned={scanned} "
        f"over_threshold={killed} threshold={THRESHOLD_GB}GiB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
