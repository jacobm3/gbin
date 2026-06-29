#clear
#
# etag.sh -- probe a URL repeatedly to see if it is being served consistently.
#
# It does two checks against the URL you pass as the first argument:
#   1) Fetches just the HTTP headers six times and prints the ETag header each
#      time. The ETag is a server-generated fingerprint of the response; if it
#      changes between requests you are likely hitting different backend servers
#      (e.g. behind a load balancer) or a cache that keeps regenerating content.
#   2) Fetches the full body six times and prints an md5 hash of it. If the
#      hashes differ, the actual content is changing between requests.
# Together these help diagnose flapping caches, load-balanced backends, or
# pages that change on every load.
#
# How to run it:
#   ./etag.sh https://example.com/somepage
# ($1 is the URL; there is no shebang, so invoke via a shell or pipe.)
#
# Prerequisites: curl, egrep, grep, md5sum, sleep, seq (all standard).

# Print a blank line to visually separate this run's output from whatever
# came before it in the terminal.
echo 
# First check: request only the headers (curl -I) six times.
# `seq 1 6` produces 1 2 3 4 5 6; the loop body runs once per number.
for x in `seq 1 6`; do
    # curl -I $1  : do a HEAD request, fetching response headers only (no body).
    # egrep -i 'etag' : keep only the ETag header line, case-insensitive.
    curl -I $1 | egrep -i 'etag'
    # Brief pause so we don't hammer the server back-to-back.
    sleep 0.1
done
# Second check: fetch the full body six times and hash it each time.
for x in `seq 1 6`; do
    # Print a label with no trailing newline (-n) so the hash lands on the
    # same line as "body hash: ".
    echo -n 'body hash: '
    # curl $1  : fetch the page body.
    # grep -v 'Generated on.' : drop any line containing "Generated on" plus one
    #   more character (the '.' matches any single char). Such timestamp lines
    #   would change every request and make the hash differ for a boring reason,
    #   so we strip them to compare the *real* content.
    # md5sum : produce a short fingerprint of the remaining content.
    curl $1 | grep -v 'Generated on.' | md5sum
done
# Trailing blank line to separate this run from the next prompt.
echo 
