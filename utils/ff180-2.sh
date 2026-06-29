#!/bin/bash
#
# ff180-2.sh — rotate a video using ffmpeg's transpose=2 filter.
#
# What it does:
#   Applies transpose=2 (90 degrees counter-clockwise) and saves a timestamped
#   .mp4. Audio is copied unchanged; video is re-encoded with H.264 (libx264).
#
# Heads up on the name: the "180" in the filename and the ".180." tag is just a
# label in this family of rotate scripts (90/180/270). The actual filter used,
# transpose=2, rotates 90 degrees COUNTER-CLOCKWISE — it does not perform a true
# 180-degree turn. A real 180 would need transpose applied twice, or hflip,vflip.
# The "-2" refers to the transpose value. Comments below describe the real effect.
#
# How to run it:
#   ff180-2.sh <filename>
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
output_file="${base_name}.180.${timestamp}.mp4"

# Run the ffmpeg command to rotate the video
#   -i "$input_file"   - the source video.
#   -vf "transpose=2"  - video filter. transpose value 2 = "90 degrees
#                        counter-clockwise" (and swaps width/height).
#                        (For reference: 0=90 CCW+vflip, 1=90 CW, 2=90 CCW, 3=90 CW+vflip.)
#   -c:a copy          - copy the audio stream as-is (no re-encode).
#   -c:v libx264       - re-encode the video with the H.264 encoder.
ffmpeg -i "$input_file" -vf "transpose=2" -c:a copy -c:v libx264 "$output_file"

echo "Output saved to $output_file"

