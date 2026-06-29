#!/bin/bash
#
# count-uniq-lines.sh -- count how many times each distinct line appears on
# standard input, then print "<count>: <line>" for every distinct line.
#
# This is similar to the classic `sort | uniq -c`, but it does NOT require the
# input to be sorted first and it does NOT sort the output. Lines are tallied in
# a hash table (an associative array), so identical lines are counted together
# no matter where they appear in the input.
#
# How to run it:
#   ./count-uniq-lines.sh < somefile.txt
#   some-command | ./count-uniq-lines.sh
#
# Prerequisites: bash 4+ (needed for `declare -A` associative arrays).
#
# Note: output order is whatever order bash happens to store the keys in
# (effectively unordered). Pipe through `sort` afterward if you want it ordered.

# Declare an associative array (a key->value map). Keys will be the input lines,
# values will be how many times each line was seen.
declare -A line_counts

# Read standard input one line at a time.
#   IFS=    : clear the field separator so leading/trailing whitespace on the
#             line is kept exactly as-is (not stripped).
#   read -r : do not treat backslashes as escape characters; read the raw line.
# The loop ends when read hits end-of-input.
while IFS= read -r line; do
  # Use the whole line as the array key and increment its counter.
  # ((...)) is bash arithmetic; "++" adds one. If this key was never seen
  # before, it starts at 0 and becomes 1.
  ((line_counts["$line"]++))
done

# Iterate over every key (every distinct line) in the array.
# "${!line_counts[@]}" expands to the list of KEYS (the '!' means "the keys",
# not the values). Quoting keeps lines with spaces intact.
for line in "${!line_counts[@]}"; do
  # (old format, kept for reference: "<line>: <count>")
  #echo "$line: ${line_counts[$line]}"
  # Print the count first, then the line, e.g. "3: hello world".
  echo "${line_counts[$line]}: $line"
done

