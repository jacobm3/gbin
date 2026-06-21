# chrome-tab-reaper

Finds Chrome/Chromium renderer processes ("tabs") using more than a RAM
threshold (default **4 GiB** RSS) and kills them. Killing a renderer frees its
memory and turns that tab into an "Aw, Snap" page; the rest of the browser and
your other tabs keep running.

Runs **hourly** via a systemd timer. Pure Python 3 stdlib — no pip packages.

## Files

| File | Installed to | Purpose |
|------|--------------|---------|
| `chrome-tab-reaper.py` | `/usr/local/sbin/chrome-tab-reaper` | the reaper |
| `chrome-tab-reaper.service` | `/etc/systemd/system/` | oneshot unit |
| `chrome-tab-reaper.timer` | `/etc/systemd/system/` | hourly trigger |
| `chrome-tab-reaper.logrotate` | `/etc/logrotate.d/chrome-tab-reaper` | log rotation |
| `install.sh` | — | installer |

## Install (this or any Debian/Ubuntu box)

The repo is always at `~/gbin`, so on any machine:

```bash
sudo ~/gbin/linux/chrome/install.sh
```

It installs `python3` + `logrotate` if missing, drops the files in place, and
enables the hourly timer.

## Logs

- **File:** `/var/log/chrome-tab-reaper/reaper.log` — timestamped, one summary
  line per run plus a line per kill. Rotated weekly by `logrotate`, 8 kept,
  compressed.
- **Journal:** `journalctl -u chrome-tab-reaper.service`

## Configuration

Override the threshold (or enable dry-run) without editing repo files:

```bash
sudo systemctl edit chrome-tab-reaper.service
# [Service]
# Environment=THRESHOLD_GB=6
```

| Env var | Default | Meaning |
|---------|---------|---------|
| `THRESHOLD_GB` | `4` | kill renderers above this RSS |
| `DRY_RUN` | off | `1` = log only, never kill |
| `TERM_GRACE` | `5` | seconds after SIGTERM before SIGKILL |
| `LOG_FILE` | `/var/log/chrome-tab-reaper/reaper.log` | log path |

## Test / operate

```bash
# Safe: pretend every renderer is over-limit, but kill nothing
sudo DRY_RUN=1 THRESHOLD_GB=0 /usr/local/sbin/chrome-tab-reaper

# Real run now
sudo systemctl start chrome-tab-reaper.service

# When does it next fire?
systemctl list-timers chrome-tab-reaper.timer
```

## Uninstall

```bash
sudo ~/gbin/linux/chrome/install.sh --uninstall
```
