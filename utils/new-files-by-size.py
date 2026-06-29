#!/usr/bin/env python3
#
# new-files-by-size.py -- list recently-modified .mkv video files, sorted by
# size (smallest first), in a tidy three-column table.
#
# What it does: starting from the current directory, it searches recursively for
# files ending in ".mkv", keeps only those modified within the last 3 days, then
# prints each file's full path, byte size, and last-modified timestamp.
#
# How to run it:
#   cd /the/folder/you/want/to/scan
#   ./new-files-by-size.py        (or: python3 new-files-by-size.py)
# It takes no command-line arguments; it always scans the current directory.
# To change the folder or the age cutoff, edit `target_directory` and
# `time_threshold` below.
#
# Prerequisites: Python 3 only (pathlib and datetime are in the standard
# library; nothing extra to install).

# Path: an object-oriented way to work with file paths and walk directories.
from pathlib import Path
# datetime: current time and timestamps. timedelta: a span of time (e.g. 3 days).
from datetime import datetime, timedelta

# Define the target directory and time frame
# Path(".") means "the current working directory" (where you run the script).
target_directory = Path(".")  # Replace with the path you want to search
# The cutoff time: now minus 3 days. Files modified before this are ignored.
time_threshold = datetime.now() - timedelta(days=3)

# Get all .mkv files in the directory recursively
# This is a "list comprehension": it builds a list by looping over matching
# files and producing one dictionary per file that passes the filter.
mkv_files = [
    {
        # file.resolve() turns the path into a full absolute path; str() makes
        # it a plain string for printing.
        "FullName": str(file.resolve()),
        # file.stat() reads the file's metadata; st_size is its size in bytes.
        "Length": file.stat().st_size,
        # st_mtime is the last-modified time as a Unix timestamp (seconds);
        # fromtimestamp converts it into a readable datetime object.
        "LastWriteTime": datetime.fromtimestamp(file.stat().st_mtime)
    }
    # rglob("*.mkv") walks the directory tree recursively, yielding every path
    # whose name ends in ".mkv".
    for file in target_directory.rglob("*.mkv")
    # Keep this file only if its last-modified time is newer than the cutoff.
    if datetime.fromtimestamp(file.stat().st_mtime) > time_threshold
]

# Sort files by Length
# sorted() returns a new list ordered by the key function. Here the key is each
# dict's "Length" value, so files come out smallest-first (ascending).
mkv_files_sorted = sorted(mkv_files, key=lambda x: x["Length"])

# Display formatted header with adjusted column width
# These are f-strings with alignment specifiers:
#   :<80  = left-align the text in a field 80 characters wide
#   :>15  = right-align the text in a field 15 characters wide (good for numbers)
# First line is the column titles; second line is a row of dashes underlining
# each column ('-'*80 makes a string of 80 dashes, etc.).
print(f"{'FullName':<80} {'Length':>15} {'LastWriteTime'}")
print(f"{'-'*80} {'-'*15} {'-'*13}")

# Display each file in formatted columns
for file_info in mkv_files_sorted:
    # Format the last write time
    # strftime turns the datetime into a string using the given pattern:
    #   %m/%d/%Y = month/day/4-digit-year, %H:%M:%S = 24-hour time.
    last_write_time = file_info["LastWriteTime"].strftime("%m/%d/%Y %H:%M:%S")
    # Print the three columns using the same widths as the header so they line up.
    print(f"{file_info['FullName']:<80} {file_info['Length']:>15} {last_write_time}")
