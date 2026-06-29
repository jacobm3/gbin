#!/bin/bash

# ---------------------------------------------------------------------------
# yt-audio.sh
#
# What it does:
#   Downloads only the audio track of a single YouTube video (no video), useful
#   for music, talks, or podcasts. The saved file uses safe, plain filenames.
#
# How to run:
#   ./yt-audio.sh <video-URL>
#   Example: ./yt-audio.sh https://www.youtube.com/watch?v=abc123
#
# Prerequisites:
#   - yt-dlp installed and on your PATH.
# ---------------------------------------------------------------------------

# Require at least one argument (the video URL).
#   $# is the argument count; (( $# < 1 )) is true when none was given.
if (( $# < 1 )); then
  # $0 is this script's name; print usage and exit with an error code.
  echo "$0 VIDEO_URL"
  exit 1
else
  # Save the first argument as the URL, then `shift` it off the argument list.
  URL="$1"; shift
fi

# yt-dlp does the actual download.
#   -f "ba" : FORMAT selector. "ba" = "best audio" — grab the highest quality
#             audio-only stream and skip the video entirely.
yt-dlp -f "ba" \
 -o "%(channel)s-%(title)s-%(id)s.%(ext)s" \
 --restrict-filenames \
  $URL
# -o is the OUTPUT filename TEMPLATE: channel-title-videoid.ext, all in one
#    filename (no subfolder). The video id keeps names unique.
# --restrict-filenames replaces spaces/special characters with safe ones
#    (ASCII only, no spaces), avoiding filename trouble across systems.
