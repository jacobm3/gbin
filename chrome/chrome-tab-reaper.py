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
  LOG_FILE       timestamped log file to append  (default ~/.local/state/chrome-tab-reaper/reaper.log)
"""

import datetime
import glob
import os
import signal
import sys
import time

# --- Configuration, read from environment variables at startup --------------
# os.environ.get(NAME, default) returns the env var if set, else the default.
# RAM threshold in GiB; a renderer using more than this gets killed.
THRESHOLD_GB = float(os.environ.get("THRESHOLD_GB", "4"))
# Convert that GiB figure to raw bytes (1024**3 bytes per GiB) for comparison.
THRESHOLD_BYTES = int(THRESHOLD_GB * 1024 ** 3)
# If DRY_RUN is set to a truthy word, only LOG what would be killed, kill nothing.
DRY_RUN = os.environ.get("DRY_RUN", "").lower() in ("1", "true", "yes", "on")
# Seconds to wait after a polite SIGTERM before escalating to a forceful SIGKILL.
TERM_GRACE = float(os.environ.get("TERM_GRACE", "5"))
# Default log path lives under the user's state dir; the systemd unit also sets
# LOG_FILE explicitly. journald keeps its own copy of stdout regardless.
LOG_FILE = os.environ.get(
    "LOG_FILE",
    os.path.expanduser("~/.local/state/chrome-tab-reaper/reaper.log"),
)

# Memory in /proc is reported in "pages"; this is the byte size of one page
# (usually 4096) so we can convert page counts to bytes.
PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")
# Substrings we look for in a process's executable name to recognize Chrome-like
# browsers (matched case-insensitively).
CHROME_HINTS = ("chrome", "chromium")

# Module-level handle for the open log file; set by _open_log(). None until then.
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
    # A tab is a child process launched with "--type=renderer". If that flag
    # isn't present (or there's no argv at all), this isn't a tab — skip it.
    if not argv or "--type=renderer" not in argv:
        return False
    # argv[0] is the program path; basename + lower() gives e.g. "chrome".
    exe = os.path.basename(argv[0]).lower()
    # True only if the exe name contains one of our Chrome/Chromium hints, so we
    # don't accidentally kill some other program that also uses "--type=renderer".
    return any(hint in exe for hint in CHROME_HINTS)


def renderer_label(argv):
    """Best-effort identifying bits — renderer argv carries no tab title/URL."""
    bits = [a for a in argv if a.startswith("--extension-process")
            or a.startswith("--renderer-client-id")
            or a.startswith("--js-flags")]
    return " ".join(bits) if bits else "(renderer)"


def kill_proc(pid):
    # In dry-run mode we never touch the process — just report what we'd do.
    if DRY_RUN:
        return "dry-run (not killed)"
    # First try a polite SIGTERM, asking the process to shut down cleanly.
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        # The process already exited between our scan and now.
        return "already gone"
    except PermissionError:
        # We don't own this process (e.g. another user's) — can't kill it.
        return "permission denied"
    # Wait up to TERM_GRACE seconds for it to actually die after SIGTERM.
    # time.monotonic() is a clock that only moves forward, safe for timing.
    deadline = time.monotonic() + TERM_GRACE
    while time.monotonic() < deadline:
        try:
            # os.kill(pid, 0) sends NO signal; it just tests if the pid is still
            # alive. If alive it returns; if gone it raises ProcessLookupError.
            os.kill(pid, 0)
        except ProcessLookupError:
            # Process is gone — the polite SIGTERM worked.
            return "terminated (SIGTERM)"
        # Still alive; wait a moment and check again.
        time.sleep(0.2)
    # Grace period expired and it's still running — force-kill with SIGKILL,
    # which the process cannot catch or ignore.
    try:
        os.kill(pid, signal.SIGKILL)
        return "killed (SIGKILL after grace)"
    except ProcessLookupError:
        # It died right at the deadline before we sent SIGKILL.
        return "terminated (SIGTERM)"


def main():
    # Open the log file (or fall back to stdout-only) before doing anything.
    _open_log()
    # Counters for the summary line at the end.
    # scanned = how many Chrome renderer processes we looked at.
    scanned = 0
    # killed = how many were over threshold and killed.
    killed = 0
    # Every running process has a numeric folder under /proc. The glob pattern
    # "/proc/[0-9]*" matches only those numeric folders (the PIDs).
    for path in glob.glob("/proc/[0-9]*"):
        # Turn "/proc/1234" into the integer pid 1234.
        pid = int(os.path.basename(path))
        # Never target ourselves.
        if pid == os.getpid():
            continue
        try:
            # Read the process's command line and check if it's a Chrome tab.
            argv = read_cmdline(pid)
            if not is_chrome_renderer(argv):
                continue
            scanned += 1
            # Measure its resident (physical) memory use.
            rss = rss_bytes(pid)
        except (FileNotFoundError, ProcessLookupError, PermissionError, ValueError):
            continue  # process vanished or unreadable between glob and read
        # Over the RAM limit? Kill it and log the action with details.
        if rss > THRESHOLD_BYTES:
            result = kill_proc(pid)
            killed += 1
            # rss / 1024**3 converts bytes back to GiB; :.2f = 2 decimal places.
            log(f"KILL pid={pid} rss={rss / 1024 ** 3:.2f}GiB "
                f"threshold={THRESHOLD_GB}GiB {renderer_label(argv)} -> {result}")

    # Final one-line summary of the run (tagged [DRY-RUN] if nothing was killed).
    mode = " [DRY-RUN]" if DRY_RUN else ""
    log(f"run complete{mode}: renderers_scanned={scanned} "
        f"over_threshold={killed} threshold={THRESHOLD_GB}GiB")
    return 0


# Standard Python entry point: only run main() when this file is executed
# directly (not when imported). sys.exit passes main()'s return code to the OS.
if __name__ == "__main__":
    sys.exit(main())
