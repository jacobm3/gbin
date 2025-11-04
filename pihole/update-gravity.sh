#!/bin/bash
# File: /home/j/pihole/update_gravity.sh

LOG_FILE="/home/j/pihole/gravity.update.log"

{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
  docker exec -i -e TERM=dumb pihole pihole -g
  echo    # blank line for readability
} >> "$LOG_FILE" 2>&1

