#!/bin/bash
#
# start-k3s.sh
#
# WHAT THIS DOES:
#   Starts a single-node k3s (lightweight Kubernetes) server in the background,
#   logging to /var/log/k3s.log, then makes the cluster's admin kubeconfig
#   readable by the "ubuntu" user so kubectl works without sudo. Finally it
#   prints basic cluster info to confirm it came up.
#
# HOW TO RUN:
#   ./start-k3s.sh
#   Needs sudo (starts a system service and edits files under /etc/rancher).
#
# PREREQUISITES:
#   - k3s already installed at /usr/local/bin/k3s.
#   - "screen" and "kubectl" installed; an "ubuntu" user that owns kubeconfig.

# Launch the k3s server inside a detached "screen" session so it keeps running
# after this script exits. Flag by flag:
#   -d -m            start screen detached (in the background, no terminal)
#   -L               enable logging of the session's output
#   -Logfile <path>  send that log to /var/log/k3s.log
#   -S k3s-server    name the session "k3s-server" so we can find/stop it later
# The remaining "/usr/local/bin/k3s server" is the actual command screen runs:
# it starts the k3s control-plane + node.
sudo screen -d -m -L -Logfile /var/log/k3s.log -S k3s-server /usr/local/bin/k3s server
# Give k3s a few seconds to start and write out its kubeconfig file before we
# touch it below.
sleep 5
# k3s writes its admin kubeconfig as root-owned. Hand ownership to the ubuntu
# user so kubectl can read it without sudo.
sudo chown ubuntu:ubuntu /etc/rancher/k3s/k3s.yaml
# Lock the kubeconfig down to owner-only read/write (600). It contains cluster
# admin credentials, so other users shouldn't be able to read it.
sudo chmod 600 /etc/rancher/k3s/k3s.yaml

# Turn on command tracing so the verification commands below are echoed as they run.
set -x
# Show the cluster's API server / services endpoints — confirms the control
# plane is reachable.
kubectl cluster-info
# List the namespaces — a simple sanity check that kubectl can talk to k3s.
kubectl get namespace
