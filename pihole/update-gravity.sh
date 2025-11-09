#!/bin/bash
# File: /home/j/pihole/update_gravity.sh

FILETS=$(date '+%Y-%m')
DIR="/home/j/pihole"
LOG_FILE="${DIR}/gravity.update.${FILETS}.log"
mkdir -p $DIR

{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
  docker exec -i -e TERM=dumb pihole pihole -g
  echo    # blank line for readability
} >> "$LOG_FILE" 2>&1

