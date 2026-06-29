#!/bin/bash
#
# gen-hosts.sh -- generate /etc/hosts-style lines for three /24 subnets.
#
# It prints one line per usable host address (.1 through .254) for each of the
# 10.0.0.x, 10.0.1.x, and 10.0.2.x networks, giving each a short name and a
# matching ".local" name. You can redirect the output into a hosts file or feed
# it to other tooling that wants a flat IP->name list.
#
# Example output lines:
#   10.0.0.1   h1   h1.local
#   10.0.1.1   b1   b1.local
#   10.0.2.1   c1   c1.local
#
# How to run it:
#   ./gen-hosts.sh                 # print to the terminal
#   ./gen-hosts.sh > hosts.txt     # save to a file
#
# Prerequisites: bash and seq (standard).

# `seq 1 254` produces the numbers 1,2,...,254. The loop runs once per number,
# with $x holding the current value, building the final octet of each address.
# echo writes three space-separated columns: the IP, a short host name, and the
# same name with a ".local" suffix. The 'h' prefix marks the 10.0.0.0/24 net.
for x in `seq 1 254`; do echo 10.0.0.$x h$x h$x.local; done
# Same idea for the 10.0.1.0/24 network, using a 'b' name prefix.
for x in `seq 1 254`; do echo 10.0.1.$x b$x b$x.local; done
# And for the 10.0.2.0/24 network, using a 'c' name prefix.
for x in `seq 1 254`; do echo 10.0.2.$x c$x c$x.local; done
