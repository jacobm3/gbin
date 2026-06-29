#!/bin/bash
#
# _ffvflip.sh — vertically flip (mirror top-to-bottom) a video and re-encode it.
#
# What it does:
#   Takes a video file, flips it upside-down, and writes a new file whose name
#   records the flip plus the codec and bitrate used (e.g. clip-vflip-vp9-1500k.mp4).
#   The audio track is copied through unchanged (not re-encoded).
#
# How to run it:
#   _ffvflip.sh <input-file> [codec] [bitrate]
#     <input-file>  the video to flip (required)
#     [codec]       video codec to encode with (default: vp9)
#     [bitrate]     target video bitrate, e.g. 1500k or 4M (default: 1500k)
#
# Prerequisites:
#   ffmpeg must be installed and on your PATH.
#
# Note: the leading underscore in the name usually marks this as a "helper"
# variant; ffvflip.sh is the simpler everyday version.

# "$#" is the number of arguments passed to the script.
# If it is 0 the user gave us nothing to work on, so print usage and stop.
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <input-file> [codec] [bitrate]"
    echo "This script vertically flips the video file and appends '-vflip' to the output filename."
    exit 1
fi

# -r tests whether the file is readable. "! -r" is true when it is NOT readable
# (missing file, wrong permissions, typo in the name), so we bail out early.
if [ ! -r "$1" ]; then
    echo "Error: Input file '$1' is not readable or does not exist."
    exit 1
fi

# -z is true when the string is empty, i.e. the user did not pass a 2nd argument.
# So: if no codec was given, default to vp9; otherwise use what they typed.
if [ -z "$2" ]; then
    CODEC="vp9"
else
    CODEC="$2"
fi

# Same pattern for the 3rd argument (bitrate): default to 1500k if omitted.
if [ -z "$3" ]; then
    BITRATE="1500k"
else
    BITRATE="$3"
fi

# Extract the filename without the extension
# basename strips any leading directory path (-- means "stop reading options",
# so a filename starting with '-' is treated as data, not a flag).
filename=$(basename -- "$1")
# "${filename##*.}" deletes the longest match of "*." from the front, leaving
# just the extension (e.g. "mp4"). ## = greedy strip from the left.
extension="${filename##*.}"
# "${filename%.*}" deletes the shortest ".*" from the end, removing the
# extension and leaving the bare name. % = strip from the right.
filename="${filename%.*}"

# vertically flip the video and save it with 'vflip' and codec info appended before the extension
# Breakdown of the ffmpeg command:
#   time          - shell builtin: prints how long the encode took when done.
#   -i "$1"       - input file (the original video).
#   -vf "vflip"   - "video filter": vflip mirrors the image vertically (top<->bottom).
#   -c:v $CODEC   - encode the VIDEO stream with the chosen codec (e.g. vp9, libx264).
#   -b:v $BITRATE - target VIDEO bitrate; higher = better quality, bigger file.
#   -c:a copy     - copy the AUDIO stream as-is (no re-encode, no quality loss).
# The output filename bakes in the flip tag, codec, and bitrate so you can tell
# at a glance how it was made, then re-attaches the original extension.
time ffmpeg -i "$1" -vf "vflip" -c:v $CODEC -b:v $BITRATE -c:a copy "${filename}-vflip-${CODEC}-${BITRATE}.${extension}"

