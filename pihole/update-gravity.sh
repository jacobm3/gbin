#!/bin/bash
#
# cron:
# 38 1 */3 * * /home/j/gbin/pihole/update-gravity.sh


FILETS=$(date '+%Y-%m')
DIR="/home/j/pihole"
LOG_FILE="${DIR}/gravity.update.${FILETS}.log"
mkdir -p $DIR

{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
  docker exec -i -e TERM=dumb pihole pihole -g
  echo    # blank line for readability
} >> "$LOG_FILE" 2>&1

