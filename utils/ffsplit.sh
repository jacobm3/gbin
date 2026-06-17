#!/usr/bin/env bash

set -o pipefail

# Function to display help
function show_help {
    cat <<'EOF'
Usage: ffsplit.sh -i <input_file> [-s <start_time>] [-e <end_time>] [-h]

Trim/copy a media file with ffmpeg. If -s is omitted, start is the beginning.
If -e is omitted, copy until the end of the file.

Options:
  -i <input_file>    Input media file (required)
  -s <start_time>    Start time (hh:mm:ss[.ms] or seconds). Optional.
  -e <end_time>      End time   (hh:mm:ss[.ms] or seconds). Optional.
  -h                 Show this help and exit

Examples:
  # From 00:10:00 to end
  ffsplit.sh -i video.mp4 -s 00:10:00

  # From start to 00:05:00
  ffsplit.sh -i video.mp4 -e 00:05:00

  # From 00:10:00 to 00:20:00
  ffsplit.sh -i video.mp4 -s 00:10:00 -e 00:20:00
EOF
}

input_file=""
start_time=""
end_time=""

# Parse command-line arguments
while getopts ":i:s:e:h" opt; do
  case "$opt" in
    i) input_file="$OPTARG" ;;
    s) start_time="$OPTARG" ;;
    e) end_time="$OPTARG" ;;
    h) show_help; exit 0 ;;
    \?) echo "Error: Invalid option: -$OPTARG" >&2; show_help; exit 1 ;;
    :)  echo "Error: Option -$OPTARG requires an argument." >&2; show_help; exit 1 ;;
  esac
done

# Validate required args
if [[ -z "$input_file" ]]; then
  echo "Error: -i <input_file> is required." >&2
  echo
  show_help
  exit 1
fi

if [[ ! -f "$input_file" ]]; then
  echo "Error: Input file not found: $input_file" >&2
  exit 1
fi

# Build output filename
base="${input_file##*/}"
name="${base%.*}"
ext="${base##*.}"

tag_s=""
tag_e=""

if [[ -n "$start_time" ]]; then
  tag_s="_s${start_time//[:.]/-}"
fi
if [[ -n "$end_time" ]]; then
  tag_e="_e${end_time//[:.]/-}"
fi

suffix="${tag_s}${tag_e}"
if [[ -z "$suffix" ]]; then
  suffix="_full"
fi

output_file="${name}${suffix}.${ext}"

# Build ffmpeg command dynamically so -ss/-to are only used when provided
cmd=(ffmpeg -i "$input_file")

if [[ -n "$start_time" ]]; then
    cmd+=(-ss "$start_time")
fi

if [[ -n "$end_time" ]]; then
    cmd+=(-to "$end_time")
fi

cmd+=(-c copy "$output_file")

# Execute
echo "Running:"
printf '  %q ' "${cmd[@]}"; echo
echo

time "${cmd[@]}"
status=$?

echo
printf 'Command: %q ' "${cmd[@]}"; echo
echo

# Check if ffmpeg succeeded
if [[ $status -eq 0 ]]; then
    echo "Output saved to: $output_file"
else
    echo "Error: ffmpeg failed with status $status."
    exit $status
fi
