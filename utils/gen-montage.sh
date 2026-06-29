#!/usr/bin/env bash
# Usage: ./gen-thumbs.sh path/to/video.mp4
#
# gen-montage.sh — build a single "contact sheet" image of a video.
#
# What it does:
#   Samples 56 evenly-spaced frames across the whole video, stamps each frame
#   with its timestamp, then tiles them into one 8x7 grid JPG saved next to the
#   video (same name, .jpg extension). Handy for previewing a long clip at a glance.
#
# How it works:
#   It first measures the video's duration, computes the frames-per-second needed
#   to land exactly 56 frames across that duration, extracts those frames into a
#   temporary directory, then tiles them with ffmpeg's tile filter.
#
# How to run it:
#   gen-montage.sh path/to/video.mp4
#
# Prerequisites:
#   ffmpeg, ffprobe, and awk must be installed and on your PATH. The drawtext
#   filter requires ffmpeg built with libfreetype (the usual distro builds have it).

# 1) Input video
VIDEO="$1"
if [ -z "$VIDEO" ]; then
  echo "Usage: $0 path/to/video.mp4"
  exit 1
fi

# 2) Number of screenshots we want total (8x7 = 56)
SAMPLES=56

# 3) Get total duration in seconds (as a floating-point number)
# ffprobe reads metadata without decoding. Flags:
#   -v error          - only show real errors.
#   -of csv=p=0       - output as CSV with no property-name prefix (just the value).
#   -show_entries format=duration - ask only for the container's duration field.
DURATION="$(ffprobe -v error -of csv=p=0 -show_entries format=duration "$VIDEO")"

# 4) Calculate the FPS needed to get exactly 56 frames from start to end
#    E.g., if the video is 280s long: 280 / 56 = 5s/frame => fps=0.2
#    We'll do the reverse: fps = SAMPLES / DURATION
# awk computes SAMPLES/DURATION. Guard against a zero/empty duration (would be a
# divide-by-zero) by falling back to fps=1 in that case.
FPS="$(awk -v dur="$DURATION" -v sam="$SAMPLES" 'BEGIN { if (dur > 0) print sam / dur; else print 1 }')"

# 5) Construct intermediate and final output filenames
# %.* drops the extension so we can re-use the base name for the output .jpg.
BASENAME="${VIDEO%.*}"
# $$ is the current process ID, making the temp dir name unique per run so two
# runs don't collide.
THUMBS_DIR=".tmp-thumbs.$$"        # Temporary directory to store individual frames
FINAL_IMAGE="${BASENAME}.jpg"  # Final tiled image

# Clean up (optional) and recreate tmp-thumbs directory
# rm -rf removes any leftover dir from a previous run; mkdir -p (re)creates it.
rm -rf "$THUMBS_DIR"
mkdir -p "$THUMBS_DIR"

##########################################################################
# STEP 1: Generate individual frames (each with a timestamp)
##########################################################################
echo "==> Extracting frames with timestamps..."

# ffmpeg flags:
#   -hide_banner        - hide the version/config banner.
#   -loglevel warning   - only print warnings and errors.
#   -y                  - overwrite output files without asking.
#   -i "$VIDEO"         - the source video.
# The -vf video-filter chain (comma-separated stages):
#   fps=${FPS}          - output frames at this rate, giving ~56 evenly-spaced frames.
#   scale=320:-1:force_original_aspect_ratio=decrease
#                       - resize to 320px wide; -1 = auto height keeping aspect
#                         ratio; "decrease" never enlarges past the original.
#   drawtext=...        - burn text onto each frame:
#         fontcolor=white, fontsize=20 - white 20px text.
#         x=10:y=H-th-10               - position: 10px from left, and 10px up from
#                                        the bottom (H=frame height, th=text height).
#         shadowcolor/shadowx/shadowy  - a 2px black drop shadow for legibility.
#         text='%{pts\:hms}'           - the frame's timestamp formatted H:M:S
#                                        (pts = presentation timestamp).
#   -q:v 2              - JPEG quality (2 is near-best; lower number = higher quality).
#   frame_%03d.jpg      - numbered output files: frame_001.jpg, frame_002.jpg, ...
time ffmpeg -hide_banner -loglevel warning -y \
  -i "$VIDEO" \
  -vf "fps=${FPS},
       scale=320:-1:force_original_aspect_ratio=decrease,
       drawtext=fontcolor=white:fontsize=20:x=10:y=H-th-10:shadowcolor=black:shadowx=2:shadowy=2:text='%{pts\\:hms}'" \
  -q:v 2 \
  "${THUMBS_DIR}/frame_%03d.jpg"

##########################################################################
# STEP 2: Combine frames into an 8x7 tiled contact sheet
##########################################################################
echo "==> Creating tiled montage (8x7) from frames..."

# Option A: Use FFmpeg to tile images into a single JPG
# -----------------------------------------------
# The glob pattern must match the extracted frames. 
# tile=8x7 => 8 columns, 7 rows, total 56 cells
# ffmpeg flags for the tiling step:
#   -pattern_type glob  - treat the -i path as a shell glob (frame_*.jpg) so all
#                         the extracted frames are read in order as an image sequence.
#   -i "..frame_*.jpg"  - the input frames.
#   -vf "tile=8x7"      - tile filter: arrange the frames in an 8-column by
#                         7-row grid (8*7 = 56 cells, matching SAMPLES).
#   -frames:v 1         - output just one image (the single tiled montage).
#   -q:v 2              - JPEG quality (near-best).
#   "$FINAL_IMAGE"      - the output contact-sheet JPG.
time ffmpeg -hide_banner -loglevel warning -y \
  -pattern_type glob \
  -i "${THUMBS_DIR}/frame_*.jpg" \
  -vf "tile=8x7" \
  -frames:v 1 \
  -q:v 2 \
  "$FINAL_IMAGE"

# Option B: Use ImageMagick (montage) instead of FFmpeg (comment out Option A above):
# -----------------------------------------------
# montage tiles the frames in an 8x7 grid; -geometry +2+2 adds 2px spacing between cells.
# montage "${THUMBS_DIR}/frame_*.jpg" -tile 8x7 -geometry +2+2 "$FINAL_IMAGE"

# Remove the temporary per-frame directory now that the montage is built.
rm -fr $THUMBS_DIR
echo "==> Done. Created tiled thumbnails: $FINAL_IMAGE"

