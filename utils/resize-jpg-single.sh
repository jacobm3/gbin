#!/bin/bash
#
# resize-jpg-single.sh — shrink ONE image file.
#
# What it does:
#   Makes a smaller copy of a single image whose longest side is 1920 pixels at
#   JPEG quality 60, written into a subfolder named img-1920-60. The original is
#   left untouched. (This is the one-file companion to resize-jpg.sh, which does
#   a whole folder.)
#
# How to run it:
#   resize-jpg-single.sh <image-file>
#
# Prerequisites:
#   ImageMagick's "convert" command must be installed and on your PATH.

# Configuration
# longedge = target pixel size for the longest side; q = JPEG quality (1-100).
longedge=1920
q=60

# Check if file argument provided
# $# is the argument count; 0 means the user gave us no file, so show usage.
if [ $# -eq 0 ]; then
    echo "Usage: $0 <image-file>"
    exit 1
fi

input_file="$1"

# Check if file exists
# -f is true for a regular file; "! -f" is true when it's missing, so stop.
if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' not found"
    exit 1
fi

# Create output directory if it doesn't exist
# -p means "no error if it already exists" (and create parents as needed).
output_dir="img-${longedge}-${q}"
mkdir -p "$output_dir"

# Get the filename
# basename strips any directory path, leaving just the file's name.
filename=$(basename "$input_file")

# Resize the image
#   convert            - ImageMagick, operating on the input file.
#   -verbose           - print what it's doing.
#   -resize "$longedge" - scale so the LONGEST side is 1920px (aspect kept).
#   -quality "$q"      - JPEG quality 60.
#   last argument      - output path: img-1920-60/1920.q60.<originalname>.
convert "$input_file" -verbose -resize "$longedge" -quality "$q" \
    "$output_dir/${longedge}.q${q}.${filename}"

echo "Resized: $filename -> $output_dir/${longedge}.q${q}.${filename}"
