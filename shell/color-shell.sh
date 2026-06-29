# color-shell.sh — a colorized bash prompt (PS1).
#
# This is a SOURCED fragment, not a standalone program: there is no shebang
# because it is meant to be pulled into an interactive shell with
#     . ~/gbin/shell/color-shell.sh
# (typically from ~/.bashrc). It only defines the prompt; it runs no commands.
#
# Bash prompt color cheat-sheet:
#   \[ ... \]   wraps non-printing characters so bash counts line length right
#   \033[       the ANSI escape that starts a color/style code
#   01;32       style 01 (bold) + color 32 (green); 31=red 34=blue 35=magenta
#               36=cyan 37=white; 00 resets back to normal
#   The trailing "m" ends the code; "\033[00m" turns styling back off.

# Define short variables for each color so the PS1 string below stays readable.
# GRN/R/CYAN/etc are the colors; O is the "reset to normal" code (think "Off").
GRN='\[\033[01;32m\]'  R='\[\033[01;31m\]' CYAN='\[\033[01;36m\]' WHT='\[\033[01;37m\]'
BLUE='\[\033[01;34m\]' MAG='\[\033[01;35m\]' O='\[\033[00m\]'
# Local timezone label used elsewhere; harmless if unused by the prompt.
LTZ=DST
# The normal-user prompt. Bash expands these escapes each time it draws PS1:
#   \u user   \h short hostname   \w current working dir
#   \D{%F}    date as YYYY-MM-DD   \t time   \n newline
# So it shows "user@host:/path   2026-06-29 14:00" then a new line with "$ ".
# CYAN colors it, and ${O} resets the color after the prompt.
PS1="${CYAN}\u@\h:\w         \D{%F} \t\n$ ${O}"
# If we're root, use a red username and a "#" prompt as a danger signal so you
# don't forget you have full privileges. == compares strings in bash's [ ].
if [ "$USER" == 'root' ]; then PS1="$R\u$O@\h:\w         \D{%F} \t\n# "; fi
