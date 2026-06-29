#!/bin/bash
#
# check_vault.sh
#
# Health check for a Vault server: ask Vault for its status, and if that fails
# (server down, sealed, unreachable, etc.) post the error text to a Slack
# channel via an incoming webhook. Designed to run from cron on a schedule.
#
# Usage / install: drop in /home/ubuntu/bin and add the cron lines shown below.
# Prerequisites:
#   - vault CLI installed and on PATH.
#   - A real Slack incoming-webhook URL in SLACKHOOK (placeholder below).
#   - VAULT_ADDR pointing at the Vault server to check.

# Slack incoming-webhook URL to POST alerts to. Replace the xxx/yyy/zzz with the
# real webhook path from Slack's "Incoming Webhooks" app config.
SLACKHOOK=https://hooks.slack.com/services/xxx/yyy/zzz
# Tell the vault CLI which server to talk to. `export` so the child `vault`
# process inherits it. Replace xxxx with the real host.
export VAULT_ADDR=https://xxxx:8200/

# Suggested cron schedule (copy into `crontab -e`): check every 5 min during
# weekday work hours, every 10 min on weekend daytime.
# cron entry
# */5  7-23  * * 1-5 /home/ubuntu/bin/check_vault.sh
# */10 10-22 * * 0,6 /home/ubuntu/bin/check_vault.sh


# Work out of a fixed directory so the relative state files below always land in
# the same place no matter where cron invoked us from.
dir=/home/ubuntu/bin
cd $dir

# Scratch file we build the Slack JSON payload into.
file=.vault.slack.msg
# File capturing the raw output of `vault status`.
out=.vault.status.out

# Record when this check last ran (handy for spotting a dead cron job).
date > .vault.check.date

# Run the status command, redirecting both stdout and stderr (2>&1) into $out so
# we capture the full message whether it succeeded or errored.
vault status > $out 2>&1 

# `$?` is the exit code of the previous command. `vault status` exits 0 only when
# Vault is up AND unsealed. If it's 0, all is well — nothing to alert, so quit.
if [ $? -eq 0 ]; then
  exit 0
fi


# --- Vault is unhealthy: build a Slack message JSON payload in $file ---
# Start the JSON object and the "text" field, prefixing the message with "ERR:".
# (Single quotes keep the JSON punctuation literal.)
echo '{"text": "ERR: ' > $file

# Append the captured status output, made JSON-safe:
#   first sed  — escape any double quotes (" -> \") so they don't break the JSON.
#   second sed — turn each line's end into a literal "\n" so the multi-line
#                status renders as line breaks inside the single JSON string.
cat $out | sed 's/"/\\"/g' | sed 's/$/\\n/' >> $file

# Close the "text" string and the JSON object.
echo '"}' >> $file

# POST the assembled JSON to Slack.
#   -X POST                       use the POST method.
#   -H 'Content-type: ...json'    tell Slack the body is JSON.
#   --data @$file                 send the file's contents as the request body
#                                 (the @ means "read body from this file").
#   > .slack.log 2>&1             save curl's output/errors for later debugging.
curl -X POST -H 'Content-type: application/json' \
	--data @$file $SLACKHOOK > .slack.log 2>&1 

