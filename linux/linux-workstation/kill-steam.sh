#!/bin/bash
#
# kill-steam.sh
#
# WHAT THIS DOES:
#   Forcefully stops every running Steam process. Steam tends to spawn several
#   processes and can linger after you close the window; this script keeps
#   killing them until none remain. Useful when Steam is hung or won't quit.
#
# HOW TO RUN:
#   ./kill-steam.sh
#   No arguments. Runs as your normal user (Steam runs as you, not root).
#
# PREREQUISITES:
#   - pgrep and pkill (part of the standard "procps" tools, present by default).

# Script to kill all Steam processes until they are gone

echo "Checking for Steam processes..."

# Check if Steam is running.
# "pgrep -x steam" searches for a process whose name is EXACTLY "steam" (-x =
# exact match, not just containing "steam"). It prints matching process IDs.
# We throw that output away (> /dev/null) and only look at its exit status:
# success (0) means at least one was found. The "!" flips that, so this block
# runs only when NO steam process is found.
if ! pgrep -x steam > /dev/null; then
    echo "No Steam processes are currently running."
    # Nothing to do, so exit successfully.
    exit 0
fi

echo "Stopping all Steam processes..."

# Loop until no Steam processes are found.
# Each pass checks again with pgrep; the loop body runs while one still exists.
while pgrep -x steam > /dev/null; do
    # pkill sends the default TERM (terminate) signal to every process named
    # exactly "steam", asking them to shut down.
    pkill -x steam
    echo "Steam processes terminated. Checking again..."
    sleep 1 # Wait 1 second before re-checking
done

echo "All Steam processes have been successfully stopped."

