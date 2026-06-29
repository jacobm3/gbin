#!/bin/bash
#
# fio-seq-write-4k-10g.sh
#
# WHAT THIS DOES:
#   Benchmarks SEQUENTIAL WRITE throughput using fio. It writes a test file
#   straight through in large 4 MB chunks with a single job and deep queue,
#   measuring peak streaming write bandwidth (MB/s) rather than IOPS. Writes a
#   timestamped report, then deletes the test file.
#
# HOW TO RUN:
#   cd into the disk/folder you want to test, then: ./fio-seq-write-4k-10g.sh
#   Results land in report-fio-seq-write4g_<timestamp>.out in that folder.
#
# PREREQUISITES:
#   - fio installed.
#   - Enough free space for the test file (~4 GB; see --size below).
#   - WARNING: this WRITES to the test device. Run it where free space exists.
#
# Original reference / recipe:
# https://linuxreviews.org/HOWTO_Test_Disk_I/O_Performance
#

# "date format" command text, executed later as $($ds) to timestamp the report.
# Format = YYYY-MM-DDThhmmss+zone.
ds='date +%Y-%m-%dT%H%M%S%z'
# Scratch file fio will write into during the test.
tmpfile="fio.temp.seq-write.file"

# Run the benchmark. Each fio flag, explained:
#   --name Seq-Write-4G   label for this job (shows in the output)
#   --eta-newline=5s      print a progress/ETA line every 5 seconds
#   --filename=$tmpfile   the file to test against (created if missing)
#   --rw=write            workload = sequential write (in order, front to back)
#   --size=4g             the job operates over a 4 GB file/region
#   --io_size=10g         total data to write before stopping (10 GB, so it loops)
#   --blocksize=4096k     4 MB per write I/O (large blocks = throughput-focused)
#   --ioengine=libaio     use Linux async I/O for issuing requests
#   --fsync=10000         flush to disk every 10000 ops (lets writes batch up)
#   --iodepth=32          keep up to 32 requests in flight to saturate bandwidth
#   --direct=1            bypass the OS page cache so we measure the real disk
#   --numjobs=1           a single sequential writer (multiple would interleave)
#   --runtime=60          stop after 60 seconds even if io_size isn't reached
#   --group_reporting     single combined summary
#   --output <file>       write the report to a timestamped file
fio --name Seq-Write-4G --eta-newline=5s --filename=$tmpfile \
    --rw=write --size=4g --io_size=10g --blocksize=4096k \
    --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 \
    --numjobs=1 --runtime=60 --group_reporting --output report-fio-seq-write4g_$($ds).out

# Clean up the scratch test file so we don't leave a big file behind.
rm $tmpfile
