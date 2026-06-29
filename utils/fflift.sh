#!/usr/bin/env bash
#
# fflift.sh — gently brighten mid-tones and highlights while keeping shadows dark.
#
# What it does:
#   Builds a custom tone curve (using ffmpeg's "curves" filter) that leaves the
#   darkest shadows on the identity line (untouched) and lifts mid-tones and
#   highlights by a chosen amount, with pure white pinned so nothing clips. It
#   then re-encodes the video, preserving the original codec/bitrate. Audio is
#   copied. Output is saved as <name>.lift.<ext>.
#
# How to run it:
#   fflift.sh <input_video> [amount]
#     <input_video>  the video to brighten (required)
#     [amount]       lift strength as a percentage (default 15);
#                    try 8 for subtle, 25 for strong.
#
# Prerequisites:
#   ffmpeg, ffprobe, and awk must be installed and on your PATH.

# Stop immediately on any error.
set -e

# No first argument -> print usage (including what "amount" does) and exit.
if [[ -z "$1" ]]; then
    echo "Usage: $0 input_video [amount]"
    echo "  Raises mid-tones and highlights while leaving shadows untouched."
    echo "  amount: lift strength as a percentage (default 15). Try 8 for subtle, 25 for strong."
    exit 1
fi

in="$1"
# "${2:-15}" = use argument 2 if present, else default to 15 (percent).
amount="${2:-15}"

# -f tests for a regular file; "! -f" is true when it's missing, so stop.
if [[ ! -f "$in" ]]; then
    echo "File not found: $in"
    exit 1
fi

# Validate that "amount" is a positive number. awk's exit code is used as a
# test: "exit !(amount>0)" exits 0 (success) only when amount>0, so the leading
# "!" makes the if-branch run when the number is NOT positive.
if ! awk "BEGIN{exit !($amount > 0)}"; then
    echo "Amount must be a positive number (percent). Got: $amount"
    exit 1
fi

# Split name/extension and build the output name "<name>.lift.<ext>".
base="${in%.*}"
ext="${in##*.}"
out="${base}.lift.${ext}"

# Build a tone curve. Shadows (0 .. knee) stay on the identity line so they are
# untouched; mid-tones get the full lift and highlights a tapered lift, with
# pure white pinned at 1 so nothing clips. Extra identity anchors in the toe and
# a guide point past the knee keep the spline from dipping below the line in the
# shadows (natural-spline undershoot).
# awk computes the curve's control points in 0..1 units. "read -r" then loads
# the six printed numbers into shell variables for the filter string below.
# (A tone curve maps each input brightness x to an output y; "x/y" pairs below.)
read -r toe knee guide gy mid high <<EOF
$(awk -v amount="$amount" 'BEGIN {
    a = amount/100;                 # convert the percent to a 0..1 fraction
    toe = 0.10;                     # toe anchor, kept on the identity line
    k   = 0.22;                     # shadow knee: below this is left alone
    gx  = 0.36;                     # guide point so the rise starts gently
    gy  = 0.36 + a*0.45;            # output for the guide point (rises with amount)
    m   = 0.5 + a;                  # mid-tone lift (strongest)
    h   = 0.75 + a*0.55;            # highlight lift (tapered to avoid clipping)
    # Clamp each lifted point below 1.0 so we never hit pure white (clipping).
    if (gy > 0.95) gy = 0.95;
    if (m  > 0.97) m  = 0.97;
    if (h  > 0.98) h  = 0.98;
    printf "%.3f %.3f %.3f %.3f %.3f %.3f", toe, k, gx, gy, m, h;
}')
EOF

# Assemble the ffmpeg "curves" filter. all='...' applies one curve to all (RGB)
# channels. Each "x/y" is a control point the spline passes through:
#   0/0            pure black stays black
#   toe/toe, knee/knee  shadows stay on the identity line (no change)
#   guide/gy       gentle start of the rise just above the knee
#   0.5/mid        mid-tones get the strongest lift
#   0.75/high      highlights get a smaller, tapered lift
#   1/1            pure white stays white (no clipping)
vf="curves=all='0/0 ${toe}/${toe} ${knee}/${knee} ${guide}/${gy} 0.5/${mid} 0.75/${high} 1/1'"

# Preserve source video codec and bitrate.
# ffprobe reads metadata without decoding. -v error keeps it quiet, v:0 selects
# the first video stream, -show_entries asks for one field, and
# -of default=nw=1:nk=1 prints just the bare value (no key, no wrapper).
vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
    -of default=nw=1:nk=1 "$in")
vbitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate \
    -of default=nw=1:nk=1 "$in")
# If the per-stream bitrate is missing, fall back to the whole-file bitrate.
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

# Collect video-encode args in an array (safe word-splitting). Reuse the codec,
# and add the bitrate only if we found a real one.
vargs=(-c:v "$vcodec")
if [[ -n "$vbitrate" && "$vbitrate" != "N/A" ]]; then
    vargs+=(-b:v "$vbitrate")
fi

# Final encode: apply the curve (-vf), reuse codec/bitrate, copy audio (-c:a copy).
ffmpeg -i "$in" -vf "$vf" "${vargs[@]}" -c:a copy "$out"

echo
echo "Done."
