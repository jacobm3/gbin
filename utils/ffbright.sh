#!/usr/bin/env bash

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 input_video"
    exit 1
fi

in="$1"

if [[ ! -f "$in" ]]; then
    echo "File not found: $in"
    exit 1
fi

# Split filename and extension
base="${in%.*}"
ext="${in##*.}"

echo
echo "Choose brightening option:"
echo "1) Mild lift (gamma 1.2) — slightly dark footage"
echo "2) Medium lift (gamma 1.4) — typical indoor"
echo "3) Strong lift (gamma 1.6) — very dark"
echo "4) Gamma + contrast — dark but flat"
echo "5) Gamma + brightness — extremely dark"
echo "6) Curves preset (natural look)"
echo "7) Aggressive recovery (gamma + contrast + saturation)"
echo "8) Cancel"
echo

read -rp "Enter choice [1-8]: " choice

case "$choice" in
    1)
        vf="eq=gamma=1.2"
        suffix="bright1"
        ;;
    2)
        vf="eq=gamma=1.4"
        suffix="bright2"
        ;;
    3)
        vf="eq=gamma=1.6"
        suffix="bright3"
        ;;
    4)
        vf="eq=gamma=1.4:contrast=1.1"
        suffix="bright-contrast"
        ;;
    5)
        vf="eq=gamma=1.6:brightness=0.06"
        suffix="bright-strong"
        ;;
    6)
        vf="curves=preset=lighter"
        suffix="curves"
        ;;
    7)
        vf="eq=gamma=1.5:contrast=1.1:saturation=1.1"
        suffix="recover"
        ;;
    *)
        echo "Cancelled."
        exit 0
        ;;
esac

out="${base}_${suffix}.${ext}"

echo
echo "Processing..."
echo "Input : $in"
echo "Output: $out"
echo

ffmpeg -i "$in" -vf "$vf" -c:a copy "$out"

echo
echo "Done."
