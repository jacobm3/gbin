#!/usr/bin/env bash
# Export the PREVIOUS day's user systemd journal to ~/.logs as a single
# zstd-compressed plain-text file (one file per day, ISO timestamps).
#
# Run daily by a user systemd timer (see install-journal-export-timer.sh).
# This is just for nice, grep-able, backup-friendly daily archives that you
# can see and timestamp at a glance; the journal itself still lives in
# journald (now kept for 5 years, see the installer).
#
# Empty days (e.g. the laptop was off) are skipped so ~/.logs doesn't fill
# up with zero-byte files.
set -euo pipefail

# systemd user services do NOT source ~/.bashrc, so brew/linuxbrew's PATH is
# not present. Add the usual spots so we can find zstd wherever it lives.
export PATH="$HOME/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOGDIR="$HOME/.logs"
mkdir -p "$LOGDIR"

# Yesterday's date, and the exact [yesterday 00:00, today 00:00) window.
DAY="$(date -d yesterday +%F)"
SINCE="$DAY 00:00:00"
UNTIL="$(date +%F) 00:00:00"
OUT="$LOGDIR/user-journal-$DAY.zst"

# Grab that day's user-journal lines as ISO-timestamped text.
# (With an explicit time window, journalctl prints nothing when there are no
# entries, so an empty result is a clean "nothing happened that day".)
TEXT="$(journalctl --user --since "$SINCE" --until "$UNTIL" -o short-iso 2>/dev/null || true)"

# Skip empty days rather than writing a useless file.
if [ -z "$TEXT" ]; then
  echo "no user-journal entries for $DAY; skipping"
  exit 0
fi

# Write the compressed daily file. -9 is overkill for ~20 KiB/day but cheap;
# -f makes a re-run for the same day simply overwrite (idempotent).
printf '%s\n' "$TEXT" | zstd -9 -q -f -o "$OUT"
echo "wrote $OUT ($(stat -c %s "$OUT") bytes)"
