# resize-jpg.sh — batch-shrink every .JPG in the current folder.
#
# What it does:
#   For each file ending in "JPG" in the current directory, makes a smaller copy
#   whose longest side is 1920 pixels at JPEG quality 90, and drops it into a new
#   subfolder named img-1920-90. Originals are left untouched.
#
# How to run it:
#   Run it from inside the folder of photos you want to resize, e.g.:
#     bash resize-jpg.sh
#   (There is no shebang line, so invoke it with bash explicitly. It is also
#   meant to be sourced/copied for quick use rather than run as an executable.)
#
# Prerequisites:
#   ImageMagick's "convert" command must be installed and on your PATH.
#
# Note: the glob "*JPG" matches upper-case .JPG (and anything ending in JPG).
# Lower-case .jpg files would NOT be matched.

# longedge = target size, in pixels, for the longest side of each image.
longedge=1920
# q = JPEG quality 1-100 (higher = better quality and bigger file).
q=90
# Create the output folder, named after the settings so it's self-documenting.
# (No -p here, so this errors harmlessly if the folder already exists.)
mkdir img-${longedge}-${q}
# Loop over every file ending in "JPG" in the current directory; $x is each name.
#   convert            - ImageMagick: the input image is $x.
#   -verbose           - print what it's doing for each file.
#   -resize $longedge  - scale so the LONGEST side is 1920px (aspect ratio kept).
#   -quality $q        - set JPEG quality to 90.
#   last argument      - the output path: img-1920-90/1920.q90.<originalname>.
for x in *JPG; do convert $x -verbose -resize $longedge -quality $q img-${longedge}-${q}/${longedge}.q${q}.${x}; done
