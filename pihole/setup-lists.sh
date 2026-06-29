#!/bin/bash
#
# setup-lists.sh — load Pi-hole's block lists, allow/deny rules, and rebuild gravity.
#
# WHAT THIS DOES:
#   Waits for the Pi-hole Docker container to report "healthy", then inserts a
#   curated set of adlists (blocklists) and a few manual block/allow rules
#   directly into Pi-hole's gravity database, and finally runs `pihole -g` to
#   download those lists and compile them into the active blocking set.
#
# HOW TO RUN:
#   Run from the directory that contains the Pi-hole "etc-pihole" bind-mount
#   (it references etc-pihole/gravity.db with a relative path):  ./setup-lists.sh
#
# PREREQUISITES:
#   - A running Pi-hole container literally named "pihole".
#   - The sqlite3 CLI installed on the host.
#   - The container's gravity.db exposed at ./etc-pihole/gravity.db.
#
# Re-running is safe: every INSERT uses "INSERT OR IGNORE", so existing rows are
# left alone rather than duplicated.

# Block here until the container's Docker healthcheck reports "healthy".
# 'docker inspect -f' pulls just the .State.Health.Status field; 2>/dev/null
# hides errors during the brief window before the container exists. The 'until'
# loop keeps polling every 3 seconds until the value equals "healthy", so we
# don't try to edit the database before Pi-hole is ready.
# Wait until Pi-hole container is healthy
until [ "$(docker inspect -f '{{.State.Health.Status}}' pihole 2>/dev/null)" = "healthy" ]; do
  echo "⏳ Waiting for pihole to become healthy..."
  sleep 3
done
echo "✅ pihole is healthy!"



# Tell Pi-hole's FTL engine to keep only 1 day of query history in its database
# (database.maxDBdays = 1). 'docker exec' runs the command inside the container.
# Keeps the long-term query log small.
docker exec pihole pihole-FTL --config database.maxDBdays 1

# Add upstream blocklists ("adlists") to the gravity database. Each row is a URL
# Pi-hole will download domains from, plus a human-readable comment/label.
# "INSERT OR IGNORE" means: if a row with the same address already exists, skip
# it silently instead of erroring — that's what makes this script re-runnable.
# The actual download of these URLs happens later when 'pihole -g' runs.
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 'Steven Black unified');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://phishing.army/download/phishing_army_blocklist_extended.txt', 'Phishing Army extended');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/Spam404/lists/refs/heads/master/main-blacklist.txt', 'Spam404 main');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/Spam404/lists/refs/heads/master/adblock-list.txt', 'Spam404 ads');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains', 'NextDNS CNAME cloaking');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/ultimate.txt', 'Hagezi Ultimate');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt', 'Hagezi Threat Intel');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://blocklistproject.github.io/Lists/malware.txt', 'Blocklist Project');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/hiphopsmurf/NSABlocklist-pi-hole-edition/refs/heads/master/HOSTS%20(excluding%20most%20GOV%20URLs)', 'NSA Blocklist');"


# Manual deny rules go in the 'domainlist' table. The 'type' column encodes the
# kind of rule: type 3 = a deny rule written as a REGEX (so it can match many
# domains at once). 'enabled' = 1 turns the rule on. The patterns below block
# any domain ending in .ru or .cn. In the regex (\.)ru$ the backslash-dot
# matches a literal dot and $ anchors it to the end of the name.
# deny
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO domainlist (type,domain,enabled,comment) VALUES (3,'(\\.)ru$',1,'block all .ru');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO domainlist (type,domain,enabled,comment) VALUES (3,'(\\.)cn$',1,'block all .cn');"

# Manual allow rule. type 0 = an exact-match ALLOW (whitelist) entry. This
# carves a single host back out of the blocks above / out of the adlists, since
# that host is needed for AliExpress product pages to load.
# allow
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO domainlist (type, domain, enabled, comment) VALUES (0, 'acs.aliexpress.us', 1, 'required for ali exp product pages');"


# 'pihole -g' = "update gravity": download every adlist URL added above and
# compile all the domains + rules into Pi-hole's active blocking list. Without
# this step the rows we inserted would not actually block anything yet.
# -it gives the command an interactive terminal so its progress output shows.
docker exec -it pihole pihole -g
