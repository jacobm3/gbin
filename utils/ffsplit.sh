#!/usr/bin/env bash
#
# ffsplit.sh — trim/extract a section of a media file without re-encoding.
#
# What it does:
#   Copies a time range out of a media file using ffmpeg stream-copy (-c copy),
#   so it is fast and lossless (no re-encode). You give a start and/or end time;
#   omit start to begin at the beginning, omit end to run to the end. The output
#   filename records the times you used, e.g. clip_s00-10-00_e00-20-00.mp4.
#
# How to run it (see the -h help block below for full examples):
#   ffsplit.sh -i <input_file> [-s <start_time>] [-e <end_time>] [-h]
#
# Prerequisites:
#   ffmpeg must be installed and on your PATH.

# "set -o pipefail" makes a pipeline fail if ANY command in it fails, not just
# the last one — so errors aren't silently hidden.
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

# Start everything empty; getopts below fills these in from the flags.
input_file=""
start_time=""
end_time=""

# Parse command-line arguments
# getopts reads the option string ":i:s:e:h". A letter followed by ":" means
# that option takes a value (placed in $OPTARG). The leading ":" switches on
# "silent" error handling so we can print our own messages via the \? and : cases.
while getopts ":i:s:e:h" opt; do
  case "$opt" in
    i) input_file="$OPTARG" ;;          # -i <file>: the input media file
    s) start_time="$OPTARG" ;;          # -s <time>: where to start the cut
    e) end_time="$OPTARG" ;;            # -e <time>: where to end the cut
    h) show_help; exit 0 ;;             # -h: print help and quit successfully
    \?) echo "Error: Invalid option: -$OPTARG" >&2; show_help; exit 1 ;;   # unknown flag
    :)  echo "Error: Option -$OPTARG requires an argument." >&2; show_help; exit 1 ;;  # missing value
  esac
done

# Validate required args
# -i is mandatory; with no input file there's nothing to do.
if [[ -z "$input_file" ]]; then
  echo "Error: -i <input_file> is required." >&2
  echo
  show_help
  exit 1
fi

# Make sure the input file actually exists before doing anything.
if [[ ! -f "$input_file" ]]; then
  echo "Error: Input file not found: $input_file" >&2
  exit 1
fi

# Build output filename
# ##*/ strips any directory path, leaving just the filename.
base="${input_file##*/}"
# %.* drops the extension; ##*. keeps just the extension.
name="${base%.*}"
ext="${base##*.}"

# These hold the start/end "tags" that get appended to the output name.
tag_s=""
tag_e=""

# If a start time was given, build a tag like "_s00-10-00".
# "${start_time//[:.]/-}" replaces every ":" or "." with "-" because colons and
# dots are awkward in filenames. // means "replace ALL matches".
if [[ -n "$start_time" ]]; then
  tag_s="_s${start_time//[:.]/-}"
fi
# Same for end time -> "_e00-20-00".
if [[ -n "$end_time" ]]; then
  tag_e="_e${end_time//[:.]/-}"
fi

# Combine the tags. If neither time was given (whole file), label it "_full".
suffix="${tag_s}${tag_e}"
if [[ -z "$suffix" ]]; then
  suffix="_full"
fi

output_file="${name}${suffix}.${ext}"

# Build ffmpeg command dynamically so -ss/-to are only used when provided
# We assemble the command in an array so each argument stays a separate word
# (this keeps filenames with spaces safe). Start with the input.
cmd=(ffmpeg -i "$input_file")

# -ss <time> tells ffmpeg to seek to the start time. Only add it if given.
if [[ -n "$start_time" ]]; then
    cmd+=(-ss "$start_time")
fi

# -to <time> tells ffmpeg to stop at the end time. Only add it if given.
if [[ -n "$end_time" ]]; then
    cmd+=(-to "$end_time")
fi

# -c copy = copy all streams as-is (no re-encode): fast and lossless. Then the
# output filename. (Note: placing -ss after -i seeks accurately, frame-precise.)
cmd+=(-c copy "$output_file")

# Execute
# First echo the exact command for the user. printf '%q' quotes each argument
# the way the shell would, so the printed line is copy-paste safe.
echo "Running:"
printf '  %q ' "${cmd[@]}"; echo
echo

# Run it, timing how long it takes. "${cmd[@]}" expands the array into args.
time "${cmd[@]}"
# $? is the exit status of the command we just ran (0 = success).
status=$?

echo
printf 'Command: %q ' "${cmd[@]}"; echo
echo

# Check if ffmpeg succeeded
if [[ $status -eq 0 ]]; then
    echo "Output saved to: $output_file"
else
    # Pass ffmpeg's failure status out as our own exit code so callers can detect it.
    echo "Error: ffmpeg failed with status $status."
    exit $status
fi
