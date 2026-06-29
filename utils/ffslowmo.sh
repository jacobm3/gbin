#!/usr/bin/env bash
#
# ffslowmo.sh — slow a video down (or speed it up) by a percentage.
#
# What it does:
#   Re-times the video so it plays at the requested percentage of normal speed
#   (default 50% = half speed) and re-times the audio to match without changing
#   its pitch. Video codec/bitrate are preserved. Saves <name>.slowmo-<pct>.<ext>.
#
# How it works (the tricky parts):
#   - Video: ffmpeg's setpts filter multiplies each frame's presentation
#     timestamp (PTS). To play at 50% speed you stretch time by 2x, so the
#     multiplier is 100/speed (e.g. 2.0 for 50%).
#   - Audio: the atempo filter changes tempo but only accepts factors between
#     0.5 and 2.0 per instance, so for big changes we chain several atempo
#     filters whose factors multiply together to the target.
#
# How to run it:
#   ffslowmo.sh <input_video> [speed_percent]
#     <input_video>   the video to re-time (required)
#     [speed_percent] playback speed as a percent (default 50 = half speed)
#   Examples:
#     ffslowmo.sh clip.mp4        # 50% speed
#     ffslowmo.sh clip.mp4 25     # 25% speed (quarter speed)
#
# Prerequisites:
#   ffmpeg, ffprobe, and awk must be installed and on your PATH.

# Stop immediately on any error.
set -e

# No first argument -> show usage and exit.
if [[ -z "$1" ]]; then
    echo "Usage: $0 input_video [speed_percent]"
    echo "  speed_percent: playback speed as a percentage (default 50 = half speed)"
    echo "  Examples:"
    echo "    $0 clip.mp4        # 50% speed"
    echo "    $0 clip.mp4 25     # 25% speed (quarter speed)"
    exit 1
fi

in="$1"
# "${2:-50}" = use argument 2 if given, otherwise default to 50 (percent).
speed="${2:-50}"

# -f tests for a regular file; "! -f" is true when it's missing, so stop.
if [[ ! -f "$in" ]]; then
    echo "File not found: $in"
    exit 1
fi

# Validate speed is a positive number (same awk-exit-code trick as elsewhere).
if ! awk "BEGIN{exit !($speed > 0)}"; then
    echo "Speed must be a positive number (percent). Got: $speed"
    exit 1
fi

# Split filename and extension
base="${in%.*}"
ext="${in##*.}"
out="${base}.slowmo-${speed}.${ext}"

# Playback factor (e.g. 50% -> 0.5). Video PTS scales by 1/factor; audio tempo by factor.
# awk does the floating-point math; printf "%.6f" gives 6 decimal places.
#   factor = speed/100  -> the audio tempo multiplier (0.5 means half-speed audio).
#   pts    = 100/speed  -> the video PTS multiplier (2.0 stretches time to 2x length).
factor=$(awk "BEGIN{printf \"%.6f\", $speed/100}")
pts=$(awk "BEGIN{printf \"%.6f\", 100/$speed}")

# Detect source video codec and bitrate so the output matches.
# ffprobe reads metadata only: -v error (quiet), v:0 (first video stream),
# -show_entries picks the field, -of default=nw=1:nk=1 prints the bare value.
vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
    -of default=nw=1:nk=1 "$in")
vbitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate \
    -of default=nw=1:nk=1 "$in")
# Fall back to the whole-file bitrate if the stream doesn't report one.
if [[ -z "$vbitrate" || "$vbitrate" == "N/A" ]]; then
    vbitrate=$(ffprobe -v error -show_entries format=bit_rate \
        -of default=nw=1:nk=1 "$in")
fi

# Build an atempo chain; each stage is limited to the 0.5-2.0 range ffmpeg allows.
# We start with t = the target tempo factor, then repeatedly factor out 0.5 (for
# very slow) or 2.0 (for very fast) until what's left fits in one atempo. The
# chained factors multiply back to the original target.
t=$factor
atempo=""
# While t is below 0.5, peel off an "atempo=0.5" and divide t by 0.5.
while awk "BEGIN{exit !($t < 0.5)}"; do
    atempo+="atempo=0.5,"
    t=$(awk "BEGIN{printf \"%.6f\", $t/0.5}")
done
# While t is above 2.0, peel off an "atempo=2.0" and divide t by 2.0.
while awk "BEGIN{exit !($t > 2.0)}"; do
    atempo+="atempo=2.0,"
    t=$(awk "BEGIN{printf \"%.6f\", $t/2.0}")
done
# Append the final remaining factor (now guaranteed within 0.5..2.0).
atempo+="atempo=$t"

echo
echo "Input : $in"
echo "Output: $out"
echo "Speed : ${speed}% (video codec: ${vcodec}, bitrate: ${vbitrate:-unknown})"
echo

# Collect video-encode args (codec, and bitrate if known) in an array.
vargs=(-c:v "$vcodec")
if [[ -n "$vbitrate" && "$vbitrate" != "N/A" ]]; then
    vargs+=(-b:v "$vbitrate")
fi

# Final re-time:
#   -i "$in"                       - source video.
#   -filter:v "setpts=${pts}*PTS"  - multiply each video frame's timestamp by pts
#                                    (e.g. 2.0) to stretch/compress playback time.
#   "${vargs[@]}"                  - reuse source codec/bitrate for the video.
#   -filter:a "$atempo"            - the audio tempo chain that matches the speed
#                                    change while keeping pitch natural.
#   "$out"                         - the re-timed output file.
ffmpeg -i "$in" \
    -filter:v "setpts=${pts}*PTS" "${vargs[@]}" \
    -filter:a "$atempo" \
    "$out"

echo
echo "Done."
