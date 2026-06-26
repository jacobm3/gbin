# Gitea Backup & Restore Guide

**Host:** pve3 (Proxmox VE) · **Gitea:** v1.26.4, runs in **CT 123**, SQLite database
**Last updated:** 2026-06-26

This document explains how the Gitea backups work and how to restore them. It
contains **no passwords or keys** — all credentials (restic repo passwords,
Backblaze B2 keys, PBS access) are stored in **Bitwarden**.

---

## 1. Overview — how the backup works

Gitea's live data lives on the `nvme1550` ZFS pool inside CT 123. That pool is
**not** covered by the offsite restic jobs, and local ZFS snapshots sit on the
same disk — so they don't survive a disk failure. To close that gap, a nightly
job exports a self-contained Gitea archive onto `/tank/share-backup/`, which the
existing restic jobs already copy to **three** offsite/off-disk destinations.

### The nightly pipeline (all times on pve3, daily)

| Time  | Job | What it does |
|-------|-----|--------------|
| 03:00 | `/root/restic-backups/gitea-dump-to-tank.sh` | Runs `gitea dump` inside CT 123, writes a timestamped `.zip` to `/tank/share-backup/gitea/`, prunes to the newest 14. |
| 03:20 | `backup-all-to-b2.sh` | restic → Backblaze B2 (offsite cloud). |
| 03:36 | `backup-all-to-optiplex-3040-micro.sh` | restic → optiplex-3040-micro (local box). |
| 03:48 | `backup-all-to-pbs-d382.sh` | restic → pbs-d382 (local box). |

The dump runs first so each night's fresh archive is included in all three
restic runs. Cron lives in the **root crontab** on pve3 (`sudo crontab -l`).

### What's in each dump

A single `gitea-dump-YYYYMMDD-HHMMSS.zip` containing:

- `gitea-db.sql` — SQL dump of the database
- `data/gitea.db` — the live SQLite database file
- `app.ini` — Gitea configuration
- `data/gitea-repositories/` (and `repos`) — **all git repositories**
- `data/` — LFS objects, avatars, attachments, SSH host keys, indexers, etc.

Each dump is small (~2 MB today). Verify any archive with `unzip -t file.zip`.

### Where things live

| Item | Location |
|------|----------|
| Dump script (host) | `/root/restic-backups/gitea-dump-to-tank.sh` |
| Dump script (source of truth) | `/home/j/projects/pve3-config/restic/gitea-dump-to-tank.sh` |
| Local dump copies | `/tank/share-backup/gitea/gitea-dump-*.zip` |
| Dump log | `/root/restic-backups/gitea-dump.log` |
| Gitea config (live) | CT 123 `/etc/gitea/app.ini` |
| Gitea data (live) | CT 123 `/var/lib/gitea/` (repos under `data/gitea-repositories`) |
| restic repo: B2 | `s3:s3.us-west-004.backblazeb2.com/jm3-backup/restic/pve3_tank_share-backup` |
| restic repo: optiplex | `rest:` on optiplex-3040-micro (`/pve3-all`) |
| restic repo: pbs-d382 | `rest:http://pbs-d382:8000/jacob/pve3-all` |

> Restic credentials for the above are in **Bitwarden** (and on the host in
> `/root/restic-backups/.creds.*`, root-only). The dumps are stored under the
> `share-backup` path, so they're in the **B2 `pve3_tank_share-backup` repo**
> and the `pve3-all` repo on optiplex/pbs.

---

## 2. Restore

There are two stages: **(A) get a dump archive**, then **(B) restore Gitea from it.**

### A. Get a dump archive

**Easiest — if pve3 / the tank is alive:** the dumps are already on disk:

```bash
ls -lt /tank/share-backup/gitea/
# pick the newest good gitea-dump-*.zip
```

**If pve3 is gone — pull from an offsite restic repo.** Install restic on any
machine, set the repo + password (from Bitwarden), then restore just the gitea
folder. Example using **Backblaze B2**:

```bash
# Credentials come from Bitwarden — do NOT hardcode them.
export RESTIC_REPOSITORY="s3:s3.us-west-004.backblazeb2.com/jm3-backup/restic/pve3_tank_share-backup"
export AWS_ACCESS_KEY_ID="...from Bitwarden..."
export AWS_SECRET_ACCESS_KEY="...from Bitwarden..."
export RESTIC_PASSWORD="...from Bitwarden..."

restic snapshots                       # find the snapshot you want
restic restore latest --target /restore \
       --include /tank/share-backup/gitea
# archives land in /restore/tank/share-backup/gitea/
```

(For optiplex or pbs-d382 instead, use their `rest:` repo URL + password from
Bitwarden; restore path is under the `pve3-all` repo.)

Pick the newest archive and verify it: `unzip -t gitea-dump-*.zip`.

### B. Restore Gitea from the dump

Gitea has **no `gitea restore` command** — restore is manual. Target: a Gitea
**1.26.x** instance (match the version; don't restore into an older one).

The fastest path in this lab is to rebuild CT 123 from the gitea-container-setup
notes (`/home/j/projects/gitea-container-setup/`), get Gitea **stopped**, then
drop the dump contents in.

```bash
# On the new/rebuilt Gitea host, with Gitea STOPPED:
#   (inside CT 123:  systemctl stop gitea)

# 1) Unzip the dump
mkdir -p /tmp/gitea-restore && cd /tmp/gitea-restore
unzip /path/to/gitea-dump-YYYYMMDD-HHMMSS.zip

# 2) Restore config
cp app.ini /etc/gitea/app.ini

# 3) Restore the database (this lab uses SQLite — just drop the db file in)
#    APP_DATA_PATH is /var/lib/gitea/data
cp data/gitea.db /var/lib/gitea/data/gitea.db
#    (If ever on MySQL/Postgres instead: create an empty DB and import
#     gitea-db.sql with the matching client.)

# 4) Restore repositories
rm -rf /var/lib/gitea/data/gitea-repositories
cp -a data/gitea-repositories /var/lib/gitea/data/gitea-repositories

# 5) Restore the rest of the data dir (LFS, avatars, attachments, ssh keys...)
cp -a data/lfs            /var/lib/gitea/data/ 2>/dev/null || true
cp -a data/avatars        /var/lib/gitea/data/ 2>/dev/null || true
cp -a data/repo-avatars   /var/lib/gitea/data/ 2>/dev/null || true
cp -a data/attachments    /var/lib/gitea/data/ 2>/dev/null || true
cp -a data/packages       /var/lib/gitea/data/ 2>/dev/null || true
cp -a data/ssh            /var/lib/gitea/data/ 2>/dev/null || true

# 6) Fix ownership and permissions (Gitea runs as user 'git')
chown -R git:git /var/lib/gitea
chown root:git /etc/gitea/app.ini && chmod 640 /etc/gitea/app.ini

# 7) Start Gitea, then regenerate git hooks (paths can change between hosts)
systemctl start gitea
su -s /bin/bash git -c '/usr/local/bin/gitea admin regenerate hooks --config /etc/gitea/app.ini'
```

### C. Verify the restore

- Web UI loads and you can log in.
- Repositories list shows everything and you can browse code/commits.
- `git clone` one repo over SSH and over HTTPS.
- Issues/PRs/avatars present.
- If git push fails server-side, re-run step 7 (`regenerate hooks`).

---

## 3. Quick operational checks

```bash
# Run a dump on demand:
sudo /root/restic-backups/gitea-dump-to-tank.sh

# See recent dumps and last log:
ls -lt /tank/share-backup/gitea/
tail -n 30 /root/restic-backups/gitea-dump.log

# Confirm the dump cron is installed (should be the 03:00 line):
sudo crontab -l | grep gitea-dump
```

**Retention:** 14 dumps kept locally on `/tank`; restic keeps the last 7
snapshots per repo (so ~7 nightly dumps offsite per destination). Adjust `KEEP`
in the dump script or `--keep-last` in the restic scripts if you want more.
