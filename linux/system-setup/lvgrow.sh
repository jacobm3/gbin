#!/bin/bash
#
# lvgrow.sh — grow the root filesystem to fill the whole disk.
#
# WHEN YOU NEED THIS: after expanding a VM's virtual disk (or cloning to a bigger
# one), the partition + LVM still only span the OLD size. This pushes the
# partition, the LVM physical volume, the logical volume, and the filesystem out
# to use all the newly-available space, in that order.
#
# HOW TO RUN (needs root):
#   sudo ~/gbin/linux/system-setup/lvgrow.sh
#   or remotely:
#   curl -sSL https://raw.githubusercontent.com/jacobm3/gbin/main/system-setup/lvgrow.sh | sudo bash
#
# ASSUMPTIONS: the stock Ubuntu 22 layout — disk /dev/sda, root on partition 3
# (/dev/sda3), in the default volume group "ubuntu-vg" / logical volume
# "ubuntu-lv". If your disk/partition/LV names differ, EDIT the paths below.
# RISK: partition/LVM edits. Growing is generally safe (no data moved), but
# double-check the device names match this machine before running.

# Don't let apt prompt during the optional package install below.
export DEBIAN_FRONTEND=noninteractive

# growpart (from cloud-guest-utils) resizes a partition in place. Install it only
# if it's missing: `which growpart` succeeds if present; the || runs apt otherwise.
which growpart || apt install -y cloud-guest-utils
# Show the root filesystem size before we start, for comparison.
echo Before:
df -h /
echo

# 1. Grow partition 3 on /dev/sda to fill the free space after it.
growpart /dev/sda 3
# 2. Tell LVM the physical volume on that partition is now bigger.
pvresize /dev/sda3
# 3. Extend the logical volume to use 100% of the now-free space in the group,
#    and --resizefs grows the filesystem on top of it in the same step.
lvresize -l+100%FREE --resizefs /dev/mapper/ubuntu--vg-ubuntu--lv

# Show the new size so you can confirm it grew.
echo
echo After:
df -h /
