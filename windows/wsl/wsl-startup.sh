#!/bin/bash

# ============================================================================
# wsl-startup.sh — start background services that WSL doesn't auto-start
# ============================================================================
#
# WHAT THIS DOES
#   WSL2 doesn't run a full init/systemd by default, so services like Docker and
#   cron aren't started automatically when you open the distro. This script
#   starts each one ONLY if it isn't already running, so it's safe to run every
#   time you open a shell.
#
# HOW TO RUN
#   Run it from your shell startup (e.g. add `~/gbin/windows/wsl/wsl-startup.sh`
#   to your ~/.bashrc / ~/.profile), or run it by hand:
#       bash ~/gbin/windows/wsl/wsl-startup.sh
#
# PREREQUISITES: WSL2 Ubuntu with docker + cron installed and passwordless sudo
#   (so the `sudo service ... start` calls don't prompt). See wsl-astro.sh /
#   wsl2-ubuntu-setup.sh for the install side.
# ============================================================================

# pgrep searches for a running process by name. "&>/dev/null" throws away its
# output; we only care about its exit code. The "|| ..." part runs ONLY if
# pgrep found nothing (docker not running), in which case we start it.
pgrep dockerd &>/dev/null || sudo service docker start

# Same pattern for cron: start the cron daemon only if it isn't already running.
pgrep cron &>/dev/null || sudo service cron start


