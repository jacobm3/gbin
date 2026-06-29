#!/bin/bash
#
# fio-rand-read-4k-4g.sh
#
# WHAT THIS DOES:
#   Benchmarks RANDOM READ disk performance using fio (Flexible I/O tester).
#   It creates a temporary test file in the current directory, hammers it with
#   small 4 KB random reads from 32 parallel jobs, and writes a timestamped
#   report, then deletes the test file.
#
# HOW TO RUN:
#   cd into the disk/folder you want to test, then: ./fio-rand-read-4k-4g.sh
#   Results land in report-fio-rand-read4k_<timestamp>.out in that folder.
#
# PREREQUISITES:
#   - fio installed.
#   - Enough free space for the test file (~1 GB; see --size below).
#
# Original reference / recipe:
# https://linuxreviews.org/HOWTO_Test_Disk_I/O_Performance
#

# A small "date format" string reused below. Note it's NOT run here; it's the
# command text. We execute it later with $($ds) to stamp the report filename.
# Format = YYYY-MM-DDThhmmss+zone, e.g. 2026-06-29T142530-0500.
ds='date +%Y-%m-%dT%H%M%S%z'
# Name of the scratch file fio will read from during the test.
tmpfile="fio.temp.rand-read.file"

# Run the benchmark. Each fio flag, explained:
#   --name Rand-Read-4k   label for this job (shows in the output)
#   --eta-newline=5s      print a progress/ETA line every 5 seconds
#   --filename=$tmpfile   the file to test against (created if missing)
#   --rw=randread         workload = random reads (jump around the file)
#   --size=1g             each job operates over a 1 GB file/region
#   --io_size=4g          total amount of data to read before stopping (4 GB)
#   --blocksize=4k        size of each read I/O = 4 KB (small, IOPS-focused)
#   --ioengine=libaio     use Linux async I/O for issuing requests
#   --fsync=1             flush to disk after every write (here mainly for file setup)
#   --iodepth=1           keep 1 outstanding request at a time per job
#   --direct=1            bypass the OS page cache so we measure the real disk
#   --numjobs=32          run 32 parallel workers to load the device
#   --runtime=60          stop after 60 seconds even if io_size isn't reached
#   --group_reporting     combine all 32 jobs into one summary instead of 32
#   --output <file>       write the report to a timestamped file
fio --name Rand-Read-4k --eta-newline=5s --filename=$tmpfile \
  --rw=randread --size=1g --io_size=4g --blocksize=4k --ioengine=libaio \
  --fsync=1 --iodepth=1 --direct=1 --numjobs=32 --runtime=60 \
  --group_reporting --output report-fio-rand-read4k_$($ds).out

# Clean up the scratch test file so we don't leave a big file behind.
rm $tmpfile


