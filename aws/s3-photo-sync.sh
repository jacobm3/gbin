# ---------------------------------------------------------------------------
# s3-photo-sync.sh
#
# What it does:
#   Backs up the local photo folder to Amazon S3 for real (uploads new and
#   changed files). Run s3-photo-sync-dry-run.sh first to preview the changes.
#
# How to run:
#   ./s3-photo-sync.sh
#   (No arguments. Source folder and S3 bucket are hard-coded below.)
#
# Prerequisites:
#   - The AWS CLI v2 installed.
#   - An AWS CLI named profile called "photos" with permission to write to the
#     target bucket.
#   - The local source folder /mnt/c/photos exists (this path looks like a
#     Windows C:\photos drive mounted under WSL).
# ---------------------------------------------------------------------------

# `aws s3 sync` copies only new/changed files from the source to the dest.
# Note: this is the SAME command as the dry-run script but WITHOUT --dryrun,
# so it actually performs the upload.
#   --profile photos: use the credentials saved under the "photos" profile.
#   --storage-class STANDARD_IA : store objects as "Standard - Infrequent
#                     Access" (cheaper storage, ideal for rarely-read backups).
#   Last two args are SOURCE (local folder) then DEST (s3://bucket/prefix).
aws s3 sync --profile photos --storage-class STANDARD_IA /mnt/c/photos s3://jacobm3-02e90e20/photos
