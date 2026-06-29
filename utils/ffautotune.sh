#!/usr/bin/env bash
#
# ffautotune.sh — automatically brighten/contrast-correct a dark video.
#
# What it does (two passes):
#   Pass 1: samples a couple of frames per second and measures the footage's
#           average brightness plus its black and white points.
#   Pass 2: from those measurements it computes ffmpeg "eq" filter settings
#           (contrast stretch + gamma lift, then a second stage that lifts the
#           blacks off the floor so shadows are not crushed) and re-encodes the
#           video, preserving the original codec and bitrate. Audio is copied.
#   Output is written next to the input as <name>.autotune.<ext>.
#
# How to run it:
#   ffautotune.sh <input_video> [target_brightness] [shadow_floor]
#     <input_video>       the video to correct (required)
#     [target_brightness] desired mid-tone luma 0-255 (default 128)
#     [shadow_floor]      lowest luma the blacks may reach 0-255 (default 24);
#                         raise it if shadows still look crushed
#
# Prerequisites:
#   ffmpeg, ffprobe, and awk must be installed and on your PATH.

# "set -e" makes the script stop immediately if any command returns an error,
# so we don't keep going after a failed analysis or encode.
set -e

# -z is true when the string is empty (no first argument). Print usage and exit.
if [[ -z "$1" ]]; then
    echo "Usage: $0 input_video [target_brightness] [shadow_floor]"
    echo "  Analyzes the footage and auto-applies brightness/contrast for max visibility."
    echo "  target_brightness: desired mid-tone luma 0-255 (default 128)"
    echo "  shadow_floor:      lowest luma the blacks are allowed to reach (default 24)"
    echo "                     raise it if shadows still look too dark/crushed"
    exit 1
fi

in="$1"
# "${2:-128}" means: use argument 2 if given, otherwise fall back to 128.
target="${2:-128}"
shadow_floor="${3:-24}"

# -f tests for a regular file. "! -f" is true when it does not exist, so stop.
if [[ ! -f "$in" ]]; then
    echo "File not found: $in"
    exit 1
fi

# Split the path into name and extension so we can build "<name>.autotune.<ext>".
# %.*  strips the shortest ".*" from the end -> drops the extension.
# ##*. strips the longest "*." from the front -> leaves just the extension.
base="${in%.*}"
ext="${in##*.}"
out="${base}.autotune.${ext}"

echo
echo "Analyzing $in ..."

# Pass 1: sample ~2 frames/sec and gather luma statistics.
#   YAVG  - average brightness
#   YLOW  - robust black point (low percentile)
#   YHIGH - robust white point (high percentile)
# ffmpeg flags here:
#   -hide_banner        - suppress the version/config banner ffmpeg normally prints.
#   -nostats            - don't print the live progress line.
#   -i "$in"            - the input video to analyze.
#   -vf "fps=2,..."     - a chain of video filters joined by commas:
#         fps=2          : drop down to 2 frames per second (fast, enough to sample).
#         signalstats    : compute per-frame stats including YAVG/YLOW/YHIGH (luma).
#         metadata=print:file=- : print those stats as text to the given file;
#                          "-" means stdout, so we can capture them in a variable.
#   -f null -           - force output format "null" with destination "-": we
#                          throw the decoded video away because we only want the
#                          printed stats, not an output file.
#   2>/dev/null         - discard stderr (ffmpeg's normal logging) so $stats only
#                          holds the metadata lines.
stats=$(ffmpeg -hide_banner -nostats -i "$in" \
    -vf "fps=2,signalstats,metadata=print:file=-" -f null - 2>/dev/null)

# If we captured nothing, there was probably no video stream to measure.
if [[ -z "$stats" ]]; then
    echo "Could not read video statistics (no video stream?)."
    exit 1
fi

# Average each metric across sampled frames.
# "read -r avg low high" splits one line of text into three variables.
# The line comes from awk, which scans every metadata line:
#   -F=            : split each line on "=" so $2 is the number after the key.
#   /YAVG=/ {...}  : on lines containing YAVG=, add the value to running total a,
#                    and count frames in n.
#   /YLOW=/, /YHIGH=/ : likewise accumulate the black/white points.
#   END {...}      : after all lines, if we saw at least one frame (n>0), print
#                    the three averages (total/count) separated by spaces.
# The <<< "$stats" feeds the captured stats text into awk as its input.
read -r avg low high <<EOF
$(awk -F= '
    /YAVG=/  { a += $2; n++ }
    /YLOW=/  { l += $2 }
    /YHIGH=/ { h += $2 }
    END { if (n) printf "%.3f %.3f %.3f", a/n, l/n, h/n }
' <<< "$stats")
EOF

# If awk printed nothing, no YAVG lines were found, so we can't tune anything.
if [[ -z "$avg" ]]; then
    echo "No luma data found in analysis."
    exit 1
fi

# Compute eq parameters in two stages, applied in order:
#   1. expose: stretch [low,high] to full range and gamma-lift avg toward target
#   2. lift:   remap the whole range into [floor,1] so blacks can't be crushed
# awk does the arithmetic in floating point. -v passes our shell variables in as
# awk variables; everything below works in 0..1 units (the raw 0..255 luma
# values are divided by 255). The five numbers printed at the end are read back
# into contrast/brightness/gamma (stage 1) and liftc/liftb (stage 2).
read -r contrast brightness gamma liftc liftb <<EOF
$(awk -v avg="$avg" -v low="$low" -v high="$high" -v target="$target" -v floor="$shadow_floor" 'BEGIN {
    # Normalize every measured/target value from 0..255 down to 0..1.
    a = avg/255; lo = low/255; hi = high/255; t = target/255; f = floor/255;
    # How wide the used part of the tonal range is. Clamp to a minimum so we
    # never divide by ~0 on a flat/low-contrast clip.
    range = hi - lo; if (range < 0.05) range = 0.05;

    # stage 2 lifts blacks to f, so stage 1 should aim a bit lower so the
    # final average still lands on the target.
    # tp = the brightness target adjusted to "before stage 2 lift" space, and
    # clamped away from the extremes so the gamma math below stays well-behaved.
    tp = (t - f)/(1 - f);
    if (tp < 0.02) tp = 0.02; if (tp > 0.98) tp = 0.98;

    c = 1/range;                       # contrast stretch (low->0, high->1)
    # Keep contrast sane: never below 1 (no shrink) and never above 3 (no blowout).
    if (c > 3) c = 3; if (c < 1) c = 1;

    b = c*(0.5 - lo) - 0.5;            # shift so the black point lands at 0
    # ffmpeg's eq brightness only accepts roughly -1..1, so clamp to that.
    if (b > 1) b = 1; if (b < -1) b = -1;

    as = (a - lo)/range;               # where avg sits after the stretch
    # Keep it strictly inside 0..1 so log() below is defined and finite.
    if (as < 0.02) as = 0.02; if (as > 0.98) as = 0.98;

    g = log(as)/log(tp);               # gamma to push avg toward the pre-lift target
    # Clamp gamma to a reasonable band (0.4 darkens, 3 brightens) to avoid extremes.
    if (g > 3) g = 3; if (g < 0.4) g = 0.4;

    lc = 1 - f;                        # stage 2: map [0,1] -> [f,1]
    lb = 0.5*f;                        # matching brightness offset for that remap

    # Emit the five values stage 1 (c,b,g) and stage 2 (lc,lb) need.
    printf "%.4f %.4f %.4f %.4f %.4f", c, b, g, lc, lb;
}')
EOF

# Preserve source video codec and bitrate.
# ffprobe inspects the file without decoding it. Flags:
#   -v error                 - only print real errors, keep output clean.
#   -select_streams v:0      - look at the first video stream only.
#   -show_entries stream=codec_name - ask for just the codec name field.
#   -of default=nw=1:nk=1    - output format: no wrapper, no key, i.e. bare value.
vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
    -of default=nw=1:nk=1 "$in")
# Same idea, but pull the video stream's bit_rate (bits per second).
vbitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate \
    -of default=nw=1:nk=1 "$in")
# Some containers don't store a per-stream bitrate; if missing/"N/A", fall back
# to the whole-file (format) bitrate instead.
if [[ -z "$vbitrate" || "$vbitrate" == "N/A" ]]; then
    vbitrate=$(ffprobe -v error -show_entries format=bit_rate \
        -of default=nw=1:nk=1 "$in")
fi

# Assemble the final video-filter string: two "eq" filters chained with a comma.
#   eq=contrast=..:brightness=..:gamma=..  - stage 1, the exposure/gamma correction.
#   eq=contrast=..:brightness=..:saturation=1.05 - stage 2, the shadow lift, plus a
#                  tiny 5% saturation boost so the brighter image doesn't look washed out.
vf="eq=contrast=${contrast}:brightness=${brightness}:gamma=${gamma},eq=contrast=${liftc}:brightness=${liftb}:saturation=1.05"

echo "  measured: avg=${avg}  low=${low}  high=${high}  (target=${target}, shadow_floor=${shadow_floor})"
echo "  applying: contrast=${contrast}  brightness=${brightness}  gamma=${gamma}"
echo
echo "Input : $in"
echo "Output: $out"
echo "Codec : ${vcodec}, bitrate: ${vbitrate:-unknown}"
echo

# Build the video-encoding arguments as an array so each piece stays a separate
# word (safe quoting). Start by reusing the source codec via -c:v.
vargs=(-c:v "$vcodec")
# If we found a usable bitrate, add "-b:v <bitrate>" so the output matches.
if [[ -n "$vbitrate" && "$vbitrate" != "N/A" ]]; then
    vargs+=(-b:v "$vbitrate")
fi

# Final encode:
#   -i "$in"        - the source video.
#   -vf "$vf"       - apply the two-stage brightness/contrast filter built above.
#   "${vargs[@]}"   - expand the codec/bitrate args (each as its own argument).
#   -c:a copy       - copy the audio stream unchanged.
#   "$out"          - the corrected output file.
ffmpeg -i "$in" -vf "$vf" "${vargs[@]}" -c:a copy "$out"

echo
echo "Done."
