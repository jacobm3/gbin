#!/bin/bash

# Wait until Pi-hole container is healthy
until [ "$(docker inspect -f '{{.State.Health.Status}}' pihole 2>/dev/null)" = "healthy" ]; do
  echo "⏳ Waiting for pihole to become healthy..."
  sleep 3
done
echo "✅ pihole is healthy!"



docker exec pihole pihole-FTL --config database.maxDBdays 1

sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 'Steven Black unified');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://phishing.army/download/phishing_army_blocklist_extended.txt', 'Phishing Army extended');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/Spam404/lists/refs/heads/master/main-blacklist.txt', 'Spam404 main');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/Spam404/lists/refs/heads/master/adblock-list.txt', 'Spam404 ads');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains', 'NextDNS CNAME cloaking');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/ultimate.txt', 'Hagezi Ultimate');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt', 'Hagezi Threat Intel');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://blocklistproject.github.io/Lists/malware.txt', 'Blocklist Project');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/hiphopsmurf/NSABlocklist-pi-hole-edition/refs/heads/master/HOSTS%20(excluding%20most%20GOV%20URLs)', 'NSA Blocklist');"


# deny
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO domainlist (type,domain,enabled,comment) VALUES (3,'(\\.)ru$',1,'block all .ru');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO domainlist (type,domain,enabled,comment) VALUES (3,'(\\.)cn$',1,'block all .cn');"

# allow
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO domainlist (type, domain, enabled, comment) VALUES (0, 'acs.aliexpress.us', 1, 'required for ali exp product pages');"


docker exec -it pihole pihole -g
