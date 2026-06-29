#!/bin/bash
#
# ffvflip.sh — vertically flip (mirror top-to-bottom) a video.
#
# What it does:
#   Flips the input video upside-down and saves the result as a timestamped
#   .mp4 next to wherever you run it. Audio is copied through unchanged.
#
# How to run it:
#   ffvflip.sh <filename>
#     <filename>  the video to flip (required)
#
# Prerequisites:
#   ffmpeg must be installed and on your PATH.

# Check if the filename is provided
# -z is true when the string is empty (no first argument given). If so, show
# usage and exit. $0 is the script's own name, handy for the Usage message.
if [ -z "$1" ]; then
    echo "Usage: $0 filename"
    exit 1
fi

# Input filename
input_file="$1"

# Extract the base name (remove extension) from the input filename
# "${input_file%.*}" strips the shortest ".*" from the end, i.e. drops the
# extension (clip.mov -> clip). We re-add our own .mp4 extension later.
base_name="${input_file%.*}"

# Get the current date and time in the desired format
# date +"..." formats the current time; here YYYYMMDD.HHMMSS so each run
# produces a unique filename and never overwrites a previous result.
timestamp=$(date +"%Y%m%d.%H%M%S")

# Construct the output filename
output_file="${base_name}.vflip.${timestamp}.mp4"

# Run the ffmpeg command to flip the video upside down
#   -i "$input_file" - the source video.
#   -vf "vflip"      - video filter that mirrors the frame vertically.
#   -c:a copy        - copy the audio stream unchanged (no re-encode).
# The video stream is re-encoded with ffmpeg's default mp4 codec since no
# -c:v was specified.
ffmpeg -i "$input_file" -vf "vflip" -c:a copy "$output_file"

echo "Output saved to $output_file"

