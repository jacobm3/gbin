#!/bin/bash
#
# 7410-fix-keyboard-after-resume.sh — one-time installer for the keyboard fix.
#
# On the Dell Latitude 7410, the built-in keyboard/touchpad sometimes stops
# working after the laptop resumes from suspend. The fix is to reload the USB
# HID kernel modules on resume. systemd runs any executable placed in
# /lib/systemd/system-sleep/ around every suspend/resume, so we install our
# `reattach-keyboard` hook script into that directory.
#
# Run this ONCE to install the hook:
#     ./7410-fix-keyboard-after-resume.sh
#
# PREREQUISITES:
#   - Run from this folder (it copies the sibling `reattach-keyboard` file).
#   - sudo access (writing under /lib/systemd needs root).

# Copy the hook script into systemd's sleep-hook directory with root privileges.
# Every executable there gets called on suspend ("pre") and resume ("post").
sudo cp reattach-keyboard /lib/systemd/system-sleep/reattach-keyboard
