sqlite3 etc-pihole/gravity.db "DELETE FROM adlist;"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 'Steven Black unified');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://phishing.army/download/phishing_army_blocklist_extended.txt', 'Phishing Army extended');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/Spam404/lists/refs/heads/master/main-blacklist.txt', 'Spam404 main');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/Spam404/lists/refs/heads/master/adblock-list.txt', 'Spam404 ads');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains', 'NextDNS CNAME cloaking');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/ultimate.txt', 'Hagezi Ultimate');"
sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, comment) VALUES ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt', 'Hagezi Threat Intel');"

sqlite3 etc-pihole/gravity.db "INSERT OR IGNORE INTO domainlist (type,domain,enabled,comment) VALUES (3,'(\\.)ru$',1,'block all .ru');"

docker exec -it pihole pihole -g
