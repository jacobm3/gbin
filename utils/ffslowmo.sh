#!/usr/bin/env bash

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 input_video [speed_percent]"
    echo "  speed_percent: playback speed as a percentage (default 50 = half speed)"
    echo "  Examples:"
    echo "    $0 clip.mp4        # 50% speed"
    echo "    $0 clip.mp4 25     # 25% speed (quarter speed)"
    exit 1
fi

in="$1"
speed="${2:-50}"

if [[ ! -f "$in" ]]; then
    echo "File not found: $in"
    exit 1
fi

if ! awk "BEGIN{exit !($speed > 0)}"; then
    echo "Speed must be a positive number (percent). Got: $speed"
    exit 1
fi

# Split filename and extension
base="${in%.*}"
ext="${in##*.}"
out="${base}.slowmo-${speed}.${ext}"

# Playback factor (e.g. 50% -> 0.5). Video PTS scales by 1/factor; audio tempo by factor.
factor=$(awk "BEGIN{printf \"%.6f\", $speed/100}")
pts=$(awk "BEGIN{printf \"%.6f\", 100/$speed}")

# Detect source video codec and bitrate so the output matches.
vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
    -of default=nw=1:nk=1 "$in")
vbitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate \
    -of default=nw=1:nk=1 "$in")
if [[ -z "$vbitrate" || "$vbitrate" == "N/A" ]]; then
    vbitrate=$(ffprobe -v error -show_entries format=bit_rate \
        -of default=nw=1:nk=1 "$in")
fi

# Build an atempo chain; each stage is limited to the 0.5-2.0 range ffmpeg allows.
t=$factor
atempo=""
while awk "BEGIN{exit !($t < 0.5)}"; do
    atempo+="atempo=0.5,"
    t=$(awk "BEGIN{printf \"%.6f\", $t/0.5}")
done
while awk "BEGIN{exit !($t > 2.0)}"; do
    atempo+="atempo=2.0,"
    t=$(awk "BEGIN{printf \"%.6f\", $t/2.0}")
done
atempo+="atempo=$t"

echo
echo "Input : $in"
echo "Output: $out"
echo "Speed : ${speed}% (video codec: ${vcodec}, bitrate: ${vbitrate:-unknown})"
echo

vargs=(-c:v "$vcodec")
if [[ -n "$vbitrate" && "$vbitrate" != "N/A" ]]; then
    vargs+=(-b:v "$vbitrate")
fi

ffmpeg -i "$in" \
    -filter:v "setpts=${pts}*PTS" "${vargs[@]}" \
    -filter:a "$atempo" \
    "$out"

echo
echo "Done."
