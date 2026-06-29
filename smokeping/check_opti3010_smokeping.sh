#!/bin/bash
#
# check_opti3010_smokeping.sh — ping-check the home SmokePing web UI and alert
# Slack if it's unreachable.
#
# This is a tiny "dead man's switch" style monitor: try to fetch the SmokePing
# page; if that fails, POST an alert message to a Slack incoming webhook. Meant
# to be run on a schedule from cron (see the example cron lines below).
#
# PREREQUISITES:
#   - curl installed.
#   - A file ~/.slack.hook.key that sets the SLACKHOOK variable to your Slack
#     incoming-webhook URL. It is kept out of this script so the URL (a secret)
#     isn't committed to git.

# Load the Slack webhook URL from the external secret file. The leading "."
# sources the file, so the SLACKHOOK variable it sets becomes available here.
# This file should contain slack hook url:
# SLACKHOOK=https://hooks.slack.com/services/xxx/yyy/zzz
. ~/.slack.hook.key

# Suggested cron schedule (copy into `crontab -e`). The two lines monitor more
# often on weekday working hours, less often on weekends:
# cron entry
# Monitor home smokeping server
# */5  7-23  * * 1-5 /home/ubuntu/gbin/check_opti3010_smokeping.sh
# */10 10-22 * * 0,6 /home/ubuntu/gbin/check_opti3010_smokeping.sh


# The SmokePing web page we expect to be reachable.
URL='http://10.0.0.200:81/smokeping/'

# Try to fetch the page quietly (-s = silent), throwing away the body (>/dev/null).
# curl exits nonzero if it can't connect. The "|| \" means: ONLY if that fetch
# fails, run the second curl, which POSTs a JSON alert to the Slack webhook.
#   -X POST                       send an HTTP POST
#   -H 'Content-type: ...'        tell Slack the body is JSON
#   --data "{...}"                the alert payload; Slack shows the "text" field
# Output/errors of the Slack call are logged to .slack.smokeping.log.
curl -s $URL >/dev/null  || \
curl -s -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"Unable to reach $URL \"}" $SLACKHOOK > .slack.smokeping.log 2>&1

