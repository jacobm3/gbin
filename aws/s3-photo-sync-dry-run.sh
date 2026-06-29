# ---------------------------------------------------------------------------
# s3-photo-sync-dry-run.sh
#
# What it does:
#   Shows what a photo backup to Amazon S3 WOULD do, without actually copying
#   anything. Use this to preview changes before running the real s3-photo-sync.sh.
#
# How to run:
#   ./s3-photo-sync-dry-run.sh
#   (No arguments. Source folder and S3 bucket are hard-coded below.)
#
# Prerequisites:
#   - The AWS CLI v2 installed.
#   - An AWS CLI named profile called "photos" (configured in ~/.aws/config /
#     ~/.aws/credentials) with permission to write to the target bucket.
#   - The local source folder /mnt/c/photos exists (this path looks like a
#     Windows C:\photos drive mounted under WSL).
# ---------------------------------------------------------------------------

# `aws s3 sync` copies only new/changed files from the source to the dest.
#   --dryrun        : DON'T actually upload; just print what would happen.
#                     This is the only difference from the real sync script.
#   --profile photos: use the credentials saved under the "photos" profile.
#   --storage-class STANDARD_IA : store objects as "Standard - Infrequent
#                     Access" (cheaper storage, small per-retrieval fee), a
#                     good fit for backups you rarely download.
#   Last two args are SOURCE (local folder) then DEST (s3://bucket/prefix).
aws s3 sync --dryrun --profile photos --storage-class STANDARD_IA /mnt/c/photos s3://jacobm3-02e90e20/photos
