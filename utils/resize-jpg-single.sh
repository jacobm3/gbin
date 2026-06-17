#!/bin/bash

# Configuration
longedge=1920
q=60

# Check if file argument provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <image-file>"
    exit 1
fi

input_file="$1"

# Check if file exists
if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' not found"
    exit 1
fi

# Create output directory if it doesn't exist
output_dir="img-${longedge}-${q}"
mkdir -p "$output_dir"

# Get the filename
filename=$(basename "$input_file")

# Resize the image
convert "$input_file" -verbose -resize "$longedge" -quality "$q" \
    "$output_dir/${longedge}.q${q}.${filename}"

echo "Resized: $filename -> $output_dir/${longedge}.q${q}.${filename}"
