# comma2newline.sh -- turn a comma-separated list into one item per line.
#
# What it does: reads text on standard input, replaces every comma (and any
# spaces right after it) with a newline, and writes the result to standard
# output. Handy for splitting things like "a, b, c" into a vertical list.
#
# How to run it:
#   echo "a, b,c,  d" | ./comma2newline.sh
#   ./comma2newline.sh < somefile.txt
# (This file has no shebang, so run it via a shell, e.g. `sh comma2newline.sh`,
#  or pipe through it as shown above. It is really just a one-line sed wrapper.)
#
# Prerequisites: sed (standard on every Linux/Unix system).
#
# The sed expression explained:
#   s/, */\n/g
#     s        = substitute (find-and-replace)
#     , *      = the pattern to find: a literal comma, then zero or more spaces
#                (the space followed by '*' means "any number of the preceding
#                 character", so "," "," "  " all match after the comma)
#     \n       = the replacement: a newline character
#     g        = global; replace EVERY match on each line, not just the first
# Reading from stdin and writing to stdout is sed's default when no file is given.
sed 's/, */\n/g'
