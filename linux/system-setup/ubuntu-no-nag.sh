# ubuntu-no-nag.sh — silence the "Ubuntu Pro / ESM" advertising that Ubuntu
# prints in the login banner (the message-of-the-day, /etc/motd).
#
# HOW TO RUN (needs root; it sudo's each step):
#   ~/gbin/linux/system-setup/ubuntu-no-nag.sh
# Tested on 24.04.1 LTS. Ubuntu may change apt_check.py between releases, so the
# patch below can stop matching on a future version (harmless — it just no-ops).
# RISK: edits a distro Python file in place (a .orig backup is kept, see below).
# (No shebang on purpose — run with bash/sh.)

# Disable Ubuntu Pro advertising in /etc/motd.
# This patches Ubuntu's apt_check.py so the two functions that print the ESM /
# Pro upsell return immediately and emit nothing.
#   sed flags:
#     -E  use extended regular expressions (nicer grouping syntax)
#     -z  treat the whole file as ONE record (NUL-separated), so a regex can
#         span multiple lines — needed because we match across the def's header
#     -i.orig  edit the file in place, but first save a backup as <file>.orig
#   Each -e finds a function's "def ...:" header (captured as group \1) and
#   rewrites it to the same header followed by an indented `return`, which makes
#   the function do nothing. The second pattern uses non-greedy .*? to skip the
#   def's argument lines up to the closing "):" before inserting the return.
sudo sed -Ezi.orig \
  -e 's/(def _output_esm_service_status.outstream, have_esm_service, service_type.:\n)/\1    return\n/' \
  -e 's/(def _output_esm_package_alert.*?\n.*?\n.:\n)/\1    return\n/' \
  /usr/lib/update-notifier/apt_check.py

# From here on, stop if any command fails.
set -e

# The motd is assembled by running every script in /etc/update-motd.d in order.
# Move the chatty/ad-y ones out of the way (into a bak/ subfolder) so they no
# longer run, rather than deleting them — easy to restore later.
cd /etc/update-motd.d 
sudo mkdir -p bak 
# 10-help-text        - generic "documentation / support" blurb
# 50-landscape-sysinfo- the system-load summary block
# 50-motd-news        - fetches and prints Ubuntu's promotional news
for file in 10-help-text 50-landscape-sysinfo 50-motd-news; do
       # Only move it if it's actually present (guards against re-runs).
       if [ -f $file ]; then sudo mv $file bak; fi
       done

# Regenerate the cached "updates available" portion of the motd now, so the
# banner reflects our changes immediately instead of at the next scheduled run.
sudo /usr/lib/update-notifier/update-motd-updates-available --force

