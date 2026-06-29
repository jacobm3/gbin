#!/bin/bash
#
# fio-seq-read-1k-2g.sh
#
# WHAT THIS DOES:
#   Benchmarks SEQUENTIAL READ throughput using fio. It reads a test file
#   straight through in large 1 MB chunks with a single job and deep queue,
#   which measures peak streaming read bandwidth (MB/s) rather than IOPS.
#   Writes a timestamped report, then deletes the test file.
#
# HOW TO RUN:
#   cd into the disk/folder you want to test, then: ./fio-seq-read-1k-2g.sh
#   Results land in report-fio-seq-read1g_<timestamp>.out in that folder.
#
# PREREQUISITES:
#   - fio installed.
#   - Enough free space for the test file (~1 GB; see --size below).
#
# Original reference / recipe:
# https://linuxreviews.org/HOWTO_Test_Disk_I/O_Performance
#

# "date format" command text, executed later as $($ds) to timestamp the report.
# Format = YYYY-MM-DDThhmmss+zone.
ds='date +%Y-%m-%dT%H%M%S%z'
# Scratch file fio will read from during the test.
tmpfile="fio.temp.seq-read.file"

# Run the benchmark. Each fio flag, explained:
#   --name Seq-Read-1G    label for this job (shows in the output)
#   --eta-newline=5s      print a progress/ETA line every 5 seconds
#   --filename=$tmpfile   the file to test against (created if missing)
#   --rw=read             workload = sequential read (in order, front to back)
#   --size=1g             the job operates over a 1 GB file/region
#   --io_size=2g          total data to read before stopping (2 GB, so it loops)
#   --blocksize=1024k     1 MB per read I/O (large blocks = throughput-focused)
#   --ioengine=libaio     use Linux async I/O for issuing requests
#   --fsync=10000         flush only every 10000 ops (writes are rare here)
#   --iodepth=32          keep up to 32 requests in flight to saturate bandwidth
#   --direct=1            bypass the OS page cache so we measure the real disk
#   --numjobs=1           a single sequential reader (multiple would interleave)
#   --runtime=60          stop after 60 seconds even if io_size isn't reached
#   --group_reporting     single combined summary
#   --output <file>       write the report to a timestamped file
fio --name Seq-Read-1G --eta-newline=5s --filename=$tmpfile \
    --rw=read --size=1g --io_size=2g --blocksize=1024k \
    --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 \
    --numjobs=1 --runtime=60 --group_reporting --output report-fio-seq-read1g_$($ds).out

# Clean up the scratch test file so we don't leave a big file behind.
rm $tmpfile
