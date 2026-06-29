#!/bin/bash
#
# ff270-3.sh — rotate a video using ffmpeg's transpose=3 filter.
#
# What it does:
#   Applies transpose=3 (90 degrees clockwise AND a vertical flip) and saves a
#   timestamped .mp4. Audio is copied unchanged; video is re-encoded with H.264.
#
# Heads up on the name: the "270" label is part of this rotate-script family
# (90/180/270). The actual filter, transpose=3, is "90 degrees clockwise plus a
# vertical flip" — which is equivalent to a 90-degrees-counter-clockwise turn
# combined with a horizontal mirror, NOT a plain 270-degree rotation. The "-3"
# refers to the transpose value. Comments below describe the real effect.
#
# How to run it:
#   ff270-3.sh <filename>
#     <filename>  the video to rotate (required)
#
# Prerequisites:
#   ffmpeg with the libx264 encoder, installed and on your PATH.

# Check if the filename is provided
# -z is true for an empty string (no argument). If so, print usage and quit.
if [ -z "$1" ]; then
    echo "Usage: $0 filename"
    exit 1
fi

# Input filename
input_file="$1"

# Extract the base name (remove extension) from the input filename
# "${input_file%.*}" drops the extension (clip.mov -> clip); we add .mp4 below.
base_name="${input_file%.*}"

# Get the current date and time in the desired format
# YYYYMMDD.HHMMSS timestamp keeps each output filename unique.
timestamp=$(date +"%Y%m%d.%H%M%S")

# Construct the output filename
output_file="${base_name}.270.${timestamp}.mp4"

# Run the ffmpeg command to rotate/flip the video
#   -i "$input_file"   - the source video.
#   -vf "transpose=3"  - video filter. transpose value 3 = "90 degrees clockwise
#                        then flipped vertically" (and swaps width/height).
#                        (For reference: 0=90 CCW+vflip, 1=90 CW, 2=90 CCW, 3=90 CW+vflip.)
#   -c:a copy          - copy the audio stream as-is (no re-encode).
#   -c:v libx264       - re-encode the video with the H.264 encoder.
ffmpeg -i "$input_file" -vf "transpose=3" -c:a copy -c:v libx264 "$output_file"

echo "Output saved to $output_file"

