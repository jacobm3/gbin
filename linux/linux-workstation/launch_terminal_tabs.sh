#!/bin/bash
#
# launch_terminal_tabs.sh
#
# WHAT THIS DOES:
#   Opens a single maximized xfce4-terminal window with three tabs preloaded:
#     1. htop  (process/CPU/memory monitor)
#     2. btop  (a fancier system monitor)
#     3. shell (a plain interactive shell)
#   Handy one-click "system dashboard" on an XFCE desktop.
#
# HOW TO RUN:
#   ./launch_terminal_tabs.sh   (from inside a graphical desktop session)
#
# PREREQUISITES:
#   - xfce4-terminal, htop, and btop installed.
#   - A running X/graphical session (this opens a GUI window).

# Each backslash at the end of a line joins it to the next, so the whole thing
# below is one long xfce4-terminal command split for readability.
xfce4-terminal \
  `# Title shown for the first tab.` \
  --initial-title=htop \
  `# Open the window maximized to fill the screen.` \
  --maximize \
  `# First tab's command: run htop, and when htop exits, "exec bash" replaces it`\
  `# with an interactive shell so the tab stays open instead of closing.` \
  --command="bash -c 'htop; exec bash'" \
  `# Make this first tab the focused/active one when the window opens.` \
  --active-tab \
  `# Second tab, titled "btop" (-T sets the tab title), running btop the same`\
  `# stay-open-after-exit way as above.` \
  --tab -T btop --command="bash -c 'btop; exec bash'" \
  `# Third tab, titled "shell", left as a normal interactive shell.` \
  --tab -T shell

