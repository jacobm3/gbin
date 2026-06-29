#!/bin/bash

# ---------------------------------------------------------------------------
# yt-720.sh
#
# What it does:
#   Downloads a single YouTube video at up to 720p, saving it under a folder
#   named after the channel.
#
# How to run:
#   ./yt-720.sh <video-URL>
#   Example: ./yt-720.sh https://www.youtube.com/watch?v=abc123
#
# Prerequisites:
#   - yt-dlp installed and on your PATH.
#   - ffmpeg installed (yt-dlp needs it to merge separate video+audio streams).
# ---------------------------------------------------------------------------

# Require at least one argument (the video URL).
#   $#  is the number of arguments passed.
#   (( ... )) does arithmetic; this is true when fewer than 1 arg was given.
if (( $# < 1 )); then
  # $0 is this script's name; print a short usage hint and exit with an error.
  echo "$0 URL"
  exit 1
else
  # Save the first argument as the URL. `shift` then drops it from the list
  # (harmless here; kept for consistency with the other yt-* scripts).
  PLID="$1"; shift
fi

# yt-dlp does the actual download.
#   -f "..."  : the FORMAT selector telling yt-dlp which streams to grab.
#     mp4[height<=720]+bestaudio : best mp4 video no taller than 720p, merged
#                                  (+) with the best available audio track.
#     /best[height<=720]         : the / is a fallback — if that combo isn't
#                                  available, take the best single file <=720p.
yt-dlp -f "mp4[height<=720]+bestaudio/best[height<=720]" \
 -o "%(channel)s/%(title)s-%(id)s.%(ext)s" \
  $PLID
# -o is the OUTPUT filename TEMPLATE. The %(...)s fields are filled in by
# yt-dlp: channel name becomes a folder, then the file is title-videoid.ext
# (the unique video id keeps names from colliding; ext is chosen automatically).
