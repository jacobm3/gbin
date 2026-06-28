# chrome-tab-reaper

Finds Chrome/Chromium renderer processes ("tabs") using more than a RAM
threshold (default **4 GiB** RSS) and kills them. Killing a renderer frees its
memory and turns that tab into an "Aw, Snap" page; the rest of the browser and
your other tabs keep running.

Runs **hourly** via a **per-user** systemd timer. Pure Python 3 stdlib — no pip
packages.

## Why the user instance (not system-wide)

Chrome runs as your user, and this tool only ever needs to signal your own
renderer processes — so it runs unprivileged in your systemd **user** instance.
No root, no sudo, minimal blast radius (a bug can at worst hit your own
processes). Running when you're logged out buys nothing: if no one's logged in,
there are no Chrome renderers to reap.

## Files

| File | Installed to | Purpose |
|------|--------------|---------|
| `chrome-tab-reaper.py` | `~/.local/bin/chrome-tab-reaper` | the reaper |
| `chrome-tab-reaper.service` | `~/.config/systemd/user/` | oneshot unit |
| `chrome-tab-reaper.timer` | `~/.config/systemd/user/` | hourly trigger |
| `install.sh` | — | installer |

## Install (this or any Debian/Ubuntu box)

The repo is always at `~/gbin`, so on any machine — **as your normal user, not
root**:

```bash
~/gbin/linux/chrome/install.sh
```

It checks for `python3`, drops the files under `~/.local`, and enables the
hourly user timer.

## Logs

- **File:** `~/.local/state/chrome-tab-reaper/reaper.log` — timestamped, one
  summary line per run plus a line per kill (a few bytes/hour; no rotation
  needed).
- **Journal:** `journalctl --user -u chrome-tab-reaper.service`

## Configuration

Override the threshold (or enable dry-run) without editing repo files:

```bash
systemctl --user edit chrome-tab-reaper.service
# [Service]
# Environment=THRESHOLD_GB=6
```

| Env var | Default | Meaning |
|---------|---------|---------|
| `THRESHOLD_GB` | `4` | kill renderers above this RSS |
| `DRY_RUN` | off | `1` = log only, never kill |
| `TERM_GRACE` | `5` | seconds after SIGTERM before SIGKILL |
| `LOG_FILE` | `~/.local/state/chrome-tab-reaper/reaper.log` | log path |

## Test / operate

```bash
# Safe: pretend every renderer is over-limit, but kill nothing
DRY_RUN=1 THRESHOLD_GB=0 ~/.local/bin/chrome-tab-reaper

# Real run now
systemctl --user start chrome-tab-reaper.service

# When does it next fire?
systemctl --user list-timers chrome-tab-reaper.timer
```

The timer only runs while you have a login session — fine, since Chrome only
exists then. To run it even with no session open:
`sudo loginctl enable-linger $USER`.

## Uninstall

```bash
~/gbin/linux/chrome/install.sh --uninstall
```
