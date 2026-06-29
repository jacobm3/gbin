#!/bin/bash
#
# fio-rand-write-4k-10g.sh
#
# WHAT THIS DOES:
#   Benchmarks RANDOM WRITE disk performance using fio. Creates a temporary
#   test file, pounds it with small 4 KB random writes from 32 parallel jobs,
#   writes a timestamped report, then deletes the test file.
#
# HOW TO RUN:
#   cd into the disk/folder you want to test, then: ./fio-rand-write-4k-10g.sh
#   Results land in report-fio-rand-write10G_<timestamp>.out in that folder.
#
# PREREQUISITES:
#   - fio installed.
#   - Enough free space for the test file (~4 GB; see --size below).
#   - WARNING: this WRITES to the test device. Run it where free space exists;
#     don't aim it at a disk you can't afford to fill temporarily.
#
# Original reference / recipe:
# https://linuxreviews.org/HOWTO_Test_Disk_I/O_Performance
#

# "date format" command text, executed later as $($ds) to timestamp the report.
# Format = YYYY-MM-DDThhmmss+zone.
ds='date +%Y-%m-%dT%H%M%S%z'
# Scratch file fio will write into during the test.
tmpfile="fio.temp.rand-write.file"

# Run the benchmark. Each fio flag, explained:
#   --name Rand-Write-4k  label for this job (shows in the output)
#   --eta-newline=5s      print a progress/ETA line every 5 seconds
#   --filename=$tmpfile   the file to test against (created if missing)
#   --rw=randwrite        workload = random writes (jump around the file)
#   --size=4g             each job operates over a 4 GB file/region
#   --io_size=10g         total amount of data to write before stopping (10 GB)
#   --blocksize=4k        size of each write I/O = 4 KB (small, IOPS-focused)
#   --ioengine=libaio     use Linux async I/O for issuing requests
#   --fsync=1             flush to disk after every write (forces durable writes)
#   --iodepth=1           keep 1 outstanding request at a time per job
#   --direct=1            bypass the OS page cache so we measure the real disk
#   --numjobs=32          run 32 parallel workers to load the device
#   --runtime=60          stop after 60 seconds even if io_size isn't reached
#   --group_reporting     combine all 32 jobs into one summary instead of 32
#   --output <file>       write the report to a timestamped file
fio --name Rand-Write-4k --eta-newline=5s --filename=$tmpfile \
  --rw=randwrite --size=4g --io_size=10g --blocksize=4k --ioengine=libaio \
  --fsync=1 --iodepth=1 --direct=1 --numjobs=32 --runtime=60 \
  --group_reporting --output report-fio-rand-write10G_$($ds).out

# Clean up the scratch test file so we don't leave a big file behind.
rm $tmpfile


