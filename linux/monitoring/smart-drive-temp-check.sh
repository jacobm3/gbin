#!/bin/bash
#
# smart-drive-temp-check.sh
#
# WHAT THIS DOES:
#   Reads the temperature of every /dev/sd? disk via SMART. If any drive is
#   hotter than a set threshold, it sends a Pushover phone alert and then
#   SHUTS THE MACHINE DOWN to protect the hardware.
#
# HOW TO RUN:
#   sudo ./smart-drive-temp-check.sh
#   Run as root (smartctl and shutdown both require it). Typically scheduled
#   from cron to run periodically.
#
# PREREQUISITES:
#   - smartmontools installed (provides smartctl).
#   - ZFS's ZED config at /etc/zfs/zed.d/zed.rc holding Pushover credentials.
#   - WARNING: on an over-temp drive this powers the box off immediately.

# get pushover creds from zed
# "." (dot/source) runs the ZED config in the current shell so its variables
# (the Pushover credentials) become available here. We reuse ZFS Event Daemon's
# existing Pushover setup instead of storing the secrets twice.
. /etc/zfs/zed.d/zed.rc

# Define your Pushover User and API Token
# Copy the credentials loaded above into clearly-named local variables.
PUSHOVER_USER=$ZED_PUSHOVER_USER
PUSHOVER_TOKEN=$ZED_PUSHOVER_TOKEN

# Define the temperature threshold
# Degrees Celsius. Above this, a drive is considered too hot.
TEMP_THRESHOLD=48

# Check each drive's temperature
# "/dev/sd?" matches single-letter SATA/SAS disks: /dev/sda, /dev/sdb, etc.
for drive in /dev/sd?; do
    # Read the drive's SMART attributes (-A) and pull out the temperature.
    # awk finds the "Temperature_Celsius" line and prints field 10, which holds
    # the raw temperature value in that SMART attribute row.
    temp=$(smartctl -A "$drive" | awk '/Temperature_Celsius/ {print $10}')
    
    # Only act if we actually got a number (-n = string is non-empty) AND that
    # number is greater than (-gt) the threshold.
    if [ -n "$temp" ] && [ "$temp" -gt "$TEMP_THRESHOLD" ]; then
        # Send Pushover notification
        # POST the alert to Pushover's API. Each --form-string sets one field:
        #   token  = this application's API token
        #   user   = the recipient user/group key
        #   title  = "[shorthostname] Drive Temperature Alert"
        #   message= which drive, its temp, and that we're shutting down
        # "-s" runs curl silently (no progress meter).
        curl -s \
            --form-string "token=$PUSHOVER_TOKEN" \
            --form-string "user=$PUSHOVER_USER" \
            --form-string "title=[$(hostname -s)] Drive Temperature Alert" \
            --form-string "message=Drive $drive is at $temp C, exceeding the threshold of $TEMP_THRESHOLD C. Shutting down!" \
            https://api.pushover.net/1/messages.json
        # Also print the same message to the terminal/log for a local record.
        echo "message=Drive $drive is at $temp C, exceeding the threshold of $TEMP_THRESHOLD C. Shutting down!" 
	# Power the machine off immediately to prevent heat damage.
	shutdown -h now
    fi
done

