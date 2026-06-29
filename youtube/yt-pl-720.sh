#!/bin/bash

# ---------------------------------------------------------------------------
# yt-pl-720.sh
#
# What it does:
#   Downloads an ENTIRE YouTube playlist at up to 720p, organized into folders
#   by channel and playlist, with files numbered in playlist order.
#
# How to run:
#   ./yt-pl-720.sh <playlist-ID>
#   Pass just the playlist ID (the part after list= in a playlist URL), e.g.
#   ./yt-pl-720.sh PLabc123  (the script builds the full URL for you).
#
# Prerequisites:
#   - yt-dlp installed and on your PATH.
#   - ffmpeg installed (needed to merge video+audio and embed chapters).
# ---------------------------------------------------------------------------

# Require at least one argument (the playlist ID).
#   $# is the argument count; (( $# < 1 )) is true when none was given.
if (( $# < 1 )); then
  # $0 is this script's name; print usage and exit with an error code.
  echo "$0 PLAYLIST_ID"
  exit 1
else
  # Save the first argument as the playlist ID, then `shift` it off the list.
  PLID="$1"; shift
fi

# yt-dlp does the actual download.
#   -f "..." : FORMAT selector.
#     bestvideo[height<=720]+bestaudio : best video stream up to 720p merged
#                                        (+) with the best audio stream.
#     /best[height<=720]               : fallback (/) to a single combined file
#                                        no taller than 720p if the above fails.
yt-dlp -f "bestvideo[height<=720]+bestaudio/best[height<=720]" \
 --yes-playlist \
 --embed-chapters \
 -o "%(channel)s/%(playlist_title)s-%(playlist_id)s/%(playlist_index)s-%(title)s-%(id)s.%(ext)s" \
  https://www.youtube.com/playlist?list=$PLID
# --yes-playlist  : treat the URL as a whole playlist and download every video
#                   (overrides yt-dlp's "just this one video" guess).
# --embed-chapters: write chapter markers into the video file when available.
# -o is the OUTPUT filename TEMPLATE, which builds a nested folder structure:
#     channel/  playlist_title-playlist_id/  index-title-videoid.ext
#   playlist_index numbers files in playlist order so they sort correctly.
# The final argument rebuilds the full playlist URL from the ID you passed in.
