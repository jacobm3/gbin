#!/bin/bash
#
# update-gravity.sh — periodically refresh Pi-hole's blocklists, logging the run.
#
# WHAT THIS DOES:
#   Runs "pihole -g" (update gravity) inside the Pi-hole container to re-download
#   all configured blocklists, and appends the output to a monthly log file.
#   Meant to run unattended from cron, not interactively.
#
# HOW IT RUNS (cron):
#   The line below is the crontab entry that schedules it. Fields are
#   minute hour day-of-month month day-of-week. So "38 1 */3 * *" means:
#   at 01:38, every 3rd day of the month. Install with `crontab -e`.
# cron:
# 38 1 */3 * * /home/j/gbin/pihole/update-gravity.sh
#
# PREREQUISITES:
#   - A running Pi-hole container named "pihole".
#   - Write access to /home/j/pihole for the log file.


# Year-month string (e.g. 2026-06) so each month gets its own rolling log file.
FILETS=$(date '+%Y-%m')
# Directory where logs live.
DIR="/home/j/pihole"
# Full path of this month's log file.
LOG_FILE="${DIR}/gravity.update.${FILETS}.log"
# Make sure the log directory exists (-p = no error if it already does).
mkdir -p $DIR

# Group these commands with { ... } so their combined output can be redirected
# in one shot. The trailing redirect ">> "$LOG_FILE" 2>&1" appends both normal
# output (stdout) and errors (2>&1 sends stderr to the same place) to the log.
{
  # Write a timestamped header line so each run is easy to find in the log.
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
  # Run the gravity update inside the container. -i keeps stdin open; we set
  # TERM=dumb so pihole doesn't emit fancy terminal/color escape codes that
  # would clutter a plain log file. (No -t here, since cron has no terminal.)
  docker exec -i -e TERM=dumb pihole pihole -g
  echo    # blank line for readability
} >> "$LOG_FILE" 2>&1

