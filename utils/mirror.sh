# mirror.sh — download a whole website for offline browsing using wget.
#
# What it does:
#   Recursively downloads a site, rewrites its links so the saved copy works
#   when opened locally, and logs progress to wget-mirror.log. Skips large
#   archive files (.zip/.gz/.tgz). Note: this is NOT an ffmpeg/ImageMagick tool.
#
# How to run it:
#   Pass the starting URL as the first argument, e.g.:
#     bash mirror.sh https://example.com/
#   (No shebang line, so invoke it with bash explicitly.)
#
# Prerequisites:
#   wget must be installed and on your PATH.
#
# wget options explained (backslashes just continue the command onto more lines):
#   --mirror         - shorthand for recursive download + infinite depth +
#                      timestamping (only re-fetch changed files) + keep listings.
#   --convert-links  - after downloading, rewrite links to point at the local
#                      copies so the site browses correctly offline.
#   --html-extension - save pages with a .html extension even if the URL had none
#                      (so your browser/file manager recognizes them).
#   --wait=0.25      - wait 0.25 seconds between requests, to be polite to the server.
#   --span-hosts     - allow following links onto OTHER hostnames (not just the
#                      starting domain). Use with care: can pull in a lot.
#   -o wget-mirror.log - write all progress/log output to this file instead of the screen.
#   --reject zip,gz,tgz - do not download files with these extensions (skip big archives).
#   $1               - the starting URL you pass on the command line.
wget --mirror            \
     --convert-links     \
     --html-extension    \
     --wait=0.25            \
     --span-hosts \
     -o wget-mirror.log              \
     --reject zip,gz,tgz \
     $1

