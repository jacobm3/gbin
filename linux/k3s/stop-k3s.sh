#!/bin/bash -x
#
# stop-k3s.sh
#
# WHAT THIS DOES:
#   Stops the single-node k3s server that start-k3s.sh launched. It ends the
#   named screen session, kills any leftover k3s processes, then runs k3s's
#   official killall script to tear down remaining containers/network/mounts.
#
# HOW TO RUN:
#   ./stop-k3s.sh
#   Needs sudo. The "-x" in the shebang above makes bash print each command as
#   it runs, so you can watch the shutdown steps.
#
# PREREQUISITES:
#   - k3s installed, with /usr/local/bin/k3s-killall.sh present.
#   - A running k3s started under a screen session named "k3s-server".

# Tell the screen session named "k3s-server" to quit, which stops the k3s
# server process running inside it. -X sends a command, -S selects the session.
sudo screen -XS k3s-server quit
# Belt-and-suspenders cleanup of any k3s processes that survived:
#   ps aux                              list every process
#   grep /var/lib/rancher/k3s          keep only k3s-related ones
#   grep -v grep                       drop the grep command itself from the list
#   awk '{print $2}'                   print just column 2 (the process ID)
#   sudo xargs kill                    feed those PIDs to "kill" to terminate them
ps aux | grep /var/lib/rancher/k3s | grep -v grep | awk '{print $2}' | sudo xargs kill
# Run k3s's bundled killall script, which stops all k3s-managed containers and
# cleans up leftover network interfaces and mounts.
sudo /usr/local/bin/k3s-killall.sh


