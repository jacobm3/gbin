#!/bin/bash

# ---------------------------------------------------------------------------
# zfs-zed-test.sh
#
# What it does:
#   Helps verify that ZED (the ZFS Event Daemon, which sends alert emails/
#   notifications when something happens to a pool) is wired up correctly.
#   It (1) prints your active ZED settings, then (2) builds a tiny throwaway
#   ZFS pool and scrubs it to generate real ZFS events. If ZED is configured,
#   you should receive a notification from the scrub.
#
# How to run:
#   sudo ./zfs-zed-test.sh
#   (No arguments. Needs root because it creates/destroys a ZFS pool.)
#
# Prerequisites:
#   - ZFS installed, with /etc/zfs/zed.d/zed.rc present.
#   - Root privileges and a writable /tmp.
#   - No existing pool already named "test" (this script creates one).
# ---------------------------------------------------------------------------

# Print a heading, then show the user's ZED config with the noise stripped out.
echo Your condensed ZFS ZED config:
# Read the ZED config file and filter it for easier reading:
#   grep -v '^\s*$'  -> drop blank/whitespace-only lines (-v = invert match).
#   grep -v '^#'     -> drop comment lines that start with #.
# What's left is just the settings that are actually set.
cat /etc/zfs/zed.d/zed.rc | grep -v '^\s*$' | grep -v '^#'
echo
echo Generating test notification
# `set -x` turns on command tracing: from here on bash prints each command
# (prefixed with +) before running it, so you can see exactly what happens.
set -x
# Work in /tmp so the throwaway pool file lives somewhere temporary.
cd /tmp
# Create a "sparse file" to act as the pool's backing storage. A sparse file
# claims a size but uses almost no real disk until written to.
#   if=/dev/zero : read zeros as the input source.
#   of=sparse_file : write to this file.
#   bs=1 count=0 : copy zero bytes (so nothing is actually written)...
#   seek=100M    : ...but skip ahead 100 MiB first, which sets the file's
#                  apparent size to 100 MiB without consuming the space.
dd if=/dev/zero of=sparse_file bs=1 count=0 seek=100M
# Create a temporary ZFS pool named "test" backed by that sparse file.
zpool create test /tmp/sparse_file
# Scrub the pool. A scrub reads/verifies all data and emits ZFS events, which
# is exactly the activity we want ZED to notice and notify about.
zpool scrub test
# Give the scrub and ZED a few seconds to run and fire the notification.
sleep 10
# Tear everything down: export (cleanly detach) the pool...
zpool export test
# ...and delete the backing file so nothing is left behind.
rm sparse_file
