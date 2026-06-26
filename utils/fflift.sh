#!/usr/bin/env bash

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 input_video [amount]"
    echo "  Raises mid-tones and highlights while leaving shadows untouched."
    echo "  amount: lift strength as a percentage (default 15). Try 8 for subtle, 25 for strong."
    exit 1
fi

in="$1"
amount="${2:-15}"

if [[ ! -f "$in" ]]; then
    echo "File not found: $in"
    exit 1
fi

if ! awk "BEGIN{exit !($amount > 0)}"; then
    echo "Amount must be a positive number (percent). Got: $amount"
    exit 1
fi

base="${in%.*}"
ext="${in##*.}"
out="${base}.lift.${ext}"

# Build a tone curve. Shadows (0 .. knee) stay on the identity line so they are
# untouched; mid-tones get the full lift and highlights a tapered lift, with
# pure white pinned at 1 so nothing clips. Extra identity anchors in the toe and
# a guide point past the knee keep the spline from dipping below the line in the
# shadows (natural-spline undershoot).
read -r toe knee guide gy mid high <<EOF
$(awk -v amount="$amount" 'BEGIN {
    a = amount/100;
    toe = 0.10;                     # toe anchor, kept on the identity line
    k   = 0.22;                     # shadow knee: below this is left alone
    gx  = 0.36;                     # guide point so the rise starts gently
    gy  = 0.36 + a*0.45;
    m   = 0.5 + a;                  # mid-tone lift (strongest)
    h   = 0.75 + a*0.55;            # highlight lift (tapered to avoid clipping)
    if (gy > 0.95) gy = 0.95;
    if (m  > 0.97) m  = 0.97;
    if (h  > 0.98) h  = 0.98;
    printf "%.3f %.3f %.3f %.3f %.3f %.3f", toe, k, gx, gy, m, h;
}')
EOF

vf="curves=all='0/0 ${toe}/${toe} ${knee}/${knee} ${guide}/${gy} 0.5/${mid} 0.75/${high} 1/1'"

# Preserve source video codec and bitrate.
vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
    -of default=nw=1:nk=1 "$in")
vbitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate \
    -of default=nw=1:nk=1 "$in")
if [[ -z "$vbitrate" || "$vbitrate" == "N/A" ]]; then
    vbitrate=$(ffprobe -v error -show_entries format=bit_rate \
        -of default=nw=1:nk=1 "$in")
fi

echo
echo "Input : $in"
echo "Output: $out"
echo "Lift  : ${amount}%  (curve: shadows<=${knee} kept, mid->${mid}, highlight->${high})"
echo "Codec : ${vcodec}, bitrate: ${vbitrate:-unknown}"
echo

vargs=(-c:v "$vcodec")
if [[ -n "$vbitrate" && "$vbitrate" != "N/A" ]]; then
    vargs+=(-b:v "$vbitrate")
fi

ffmpeg -i "$in" -vf "$vf" "${vargs[@]}" -c:a copy "$out"

echo
echo "Done."
