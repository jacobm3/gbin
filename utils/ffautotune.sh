#!/usr/bin/env bash

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 input_video [target_brightness] [shadow_floor]"
    echo "  Analyzes the footage and auto-applies brightness/contrast for max visibility."
    echo "  target_brightness: desired mid-tone luma 0-255 (default 128)"
    echo "  shadow_floor:      lowest luma the blacks are allowed to reach (default 24)"
    echo "                     raise it if shadows still look too dark/crushed"
    exit 1
fi

in="$1"
target="${2:-128}"
shadow_floor="${3:-24}"

if [[ ! -f "$in" ]]; then
    echo "File not found: $in"
    exit 1
fi

base="${in%.*}"
ext="${in##*.}"
out="${base}.autotune.${ext}"

echo
echo "Analyzing $in ..."

# Pass 1: sample ~2 frames/sec and gather luma statistics.
#   YAVG  - average brightness
#   YLOW  - robust black point (low percentile)
#   YHIGH - robust white point (high percentile)
stats=$(ffmpeg -hide_banner -nostats -i "$in" \
    -vf "fps=2,signalstats,metadata=print:file=-" -f null - 2>/dev/null)

if [[ -z "$stats" ]]; then
    echo "Could not read video statistics (no video stream?)."
    exit 1
fi

# Average each metric across sampled frames.
read -r avg low high <<EOF
$(awk -F= '
    /YAVG=/  { a += $2; n++ }
    /YLOW=/  { l += $2 }
    /YHIGH=/ { h += $2 }
    END { if (n) printf "%.3f %.3f %.3f", a/n, l/n, h/n }
' <<< "$stats")
EOF

if [[ -z "$avg" ]]; then
    echo "No luma data found in analysis."
    exit 1
fi

# Compute eq parameters in two stages, applied in order:
#   1. expose: stretch [low,high] to full range and gamma-lift avg toward target
#   2. lift:   remap the whole range into [floor,1] so blacks can't be crushed
read -r contrast brightness gamma liftc liftb <<EOF
$(awk -v avg="$avg" -v low="$low" -v high="$high" -v target="$target" -v floor="$shadow_floor" 'BEGIN {
    a = avg/255; lo = low/255; hi = high/255; t = target/255; f = floor/255;
    range = hi - lo; if (range < 0.05) range = 0.05;

    # stage 2 lifts blacks to f, so stage 1 should aim a bit lower so the
    # final average still lands on the target.
    tp = (t - f)/(1 - f);
    if (tp < 0.02) tp = 0.02; if (tp > 0.98) tp = 0.98;

    c = 1/range;                       # contrast stretch (low->0, high->1)
    if (c > 3) c = 3; if (c < 1) c = 1;

    b = c*(0.5 - lo) - 0.5;            # shift so the black point lands at 0
    if (b > 1) b = 1; if (b < -1) b = -1;

    as = (a - lo)/range;               # where avg sits after the stretch
    if (as < 0.02) as = 0.02; if (as > 0.98) as = 0.98;

    g = log(as)/log(tp);               # gamma to push avg toward the pre-lift target
    if (g > 3) g = 3; if (g < 0.4) g = 0.4;

    lc = 1 - f;                        # stage 2: map [0,1] -> [f,1]
    lb = 0.5*f;

    printf "%.4f %.4f %.4f %.4f %.4f", c, b, g, lc, lb;
}')
EOF

# Preserve source video codec and bitrate.
vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
    -of default=nw=1:nk=1 "$in")
vbitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate \
    -of default=nw=1:nk=1 "$in")
if [[ -z "$vbitrate" || "$vbitrate" == "N/A" ]]; then
    vbitrate=$(ffprobe -v error -show_entries format=bit_rate \
        -of default=nw=1:nk=1 "$in")
fi

vf="eq=contrast=${contrast}:brightness=${brightness}:gamma=${gamma},eq=contrast=${liftc}:brightness=${liftb}:saturation=1.05"

echo "  measured: avg=${avg}  low=${low}  high=${high}  (target=${target}, shadow_floor=${shadow_floor})"
echo "  applying: contrast=${contrast}  brightness=${brightness}  gamma=${gamma}"
echo
echo "Input : $in"
echo "Output: $out"
echo "Codec : ${vcodec}, bitrate: ${vbitrate:-unknown}"
echo

vargs=(-c:v "$vcodec")
if [[ -n "$vbitrate" && "$vbitrate" != "N/A" ]]; then
    vargs+=(-b:v "$vbitrate")
fi

ffmpeg -i "$in" -vf "$vf" "${vargs[@]}" -c:a copy "$out"

echo
echo "Done."
