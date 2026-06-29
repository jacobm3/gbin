#!/usr/bin/env bash
#
# ffbright.sh — interactively brighten a dark video.
#
# What it does:
#   Prints a menu of brightening presets (gamma lifts, curves, etc.), asks you
#   to pick one, then re-encodes the video with the matching ffmpeg filter and
#   saves it next to the original with a descriptive suffix. Audio is copied.
#
# How to run it:
#   ffbright.sh <input_video>
#     <input_video>  the video to brighten (required)
#   The script then prompts you to choose option 1-8 (8 = cancel).
#
# Prerequisites:
#   ffmpeg must be installed and on your PATH.

# Stop immediately if any command fails.
set -e

# -z is true for an empty string (no argument). Show usage and quit.
if [[ -z "$1" ]]; then
    echo "Usage: $0 input_video"
    exit 1
fi

in="$1"

# -f tests for a regular file; "! -f" is true when it's missing, so stop.
if [[ ! -f "$in" ]]; then
    echo "File not found: $in"
    exit 1
fi

# Split filename and extension
# %.*  strips the extension (clip.mov -> clip); ##*. keeps just the extension.
base="${in%.*}"
ext="${in##*.}"

echo
echo "Choose brightening option:"
echo "1) Mild lift (gamma 1.2) — slightly dark footage"
echo "2) Medium lift (gamma 1.4) — typical indoor"
echo "3) Strong lift (gamma 1.6) — very dark"
echo "4) Gamma + contrast — dark but flat"
echo "5) Gamma + brightness — extremely dark"
echo "6) Curves preset (natural look)"
echo "7) Aggressive recovery (gamma + contrast + saturation)"
echo "8) Cancel"
echo

# read -r (don't mangle backslashes) -p (show this prompt) into variable "choice".
read -rp "Enter choice [1-8]: " choice

# Pick the ffmpeg video filter ("vf") and an output filename suffix based on the
# choice. In all "eq" cases:
#   gamma > 1      brightens mid-tones without blowing out pure black/white.
#   contrast > 1   increases the spread between dark and light.
#   brightness     a flat additive lift (range about -1..1).
#   saturation > 1 boosts color intensity.
case "$choice" in
    1)
        # Mild gamma lift only.
        vf="eq=gamma=1.2"
        suffix="bright1"
        ;;
    2)
        # Medium gamma lift.
        vf="eq=gamma=1.4"
        suffix="bright2"
        ;;
    3)
        # Strong gamma lift.
        vf="eq=gamma=1.6"
        suffix="bright3"
        ;;
    4)
        # Gamma lift plus a touch of contrast, for dark-but-flat footage.
        vf="eq=gamma=1.4:contrast=1.1"
        suffix="bright-contrast"
        ;;
    5)
        # Strong gamma plus a small additive brightness lift, for very dark clips.
        vf="eq=gamma=1.6:brightness=0.06"
        suffix="bright-strong"
        ;;
    6)
        # Use ffmpeg's built-in "lighter" curves preset for a natural look.
        vf="curves=preset=lighter"
        suffix="curves"
        ;;
    7)
        # Aggressive recovery: gamma + contrast + extra saturation together.
        vf="eq=gamma=1.5:contrast=1.1:saturation=1.1"
        suffix="recover"
        ;;
    *)
        # Anything else (including 8) cancels with a clean exit.
        echo "Cancelled."
        exit 0
        ;;
esac

# Build the output name from the base, the chosen suffix, and original extension.
out="${base}_${suffix}.${ext}"

echo
echo "Processing..."
echo "Input : $in"
echo "Output: $out"
echo

# Apply the chosen filter:
#   -i "$in"   - source video.
#   -vf "$vf"  - the brightening filter selected above.
#   -c:a copy  - copy audio unchanged. Video is re-encoded with ffmpeg defaults.
ffmpeg -i "$in" -vf "$vf" -c:a copy "$out"

echo
echo "Done."
