# chrome

Jacob's Chrome workstation setup. Three pieces, all installed into the user's
home (no root needed) by one script.

## Install on a new workstation

As your normal user (NOT root), with the repo at `~/gbin`:

```bash
~/gbin/chrome/setup.sh
```

That installs all three pieces below. Uninstall everything with
`~/gbin/chrome/setup.sh --uninstall`.

## What's here

| File | Installed to | Purpose |
|------|--------------|---------|
| `chrome-wait-online` | `~/.local/bin/chrome-wait-online` | wait for network at login, then launch Chrome with work tabs |
| `chrome.desktop` | `~/.config/autostart/chrome.desktop` | XFCE autostart entry that runs `chrome-wait-online` at login |
| `chrome-tab-reaper.py` | `~/.local/bin/chrome-tab-reaper` | hourly RAM reaper for runaway tabs |
| `chrome-tab-reaper.service` | `~/.config/systemd/user/` | oneshot unit for the reaper |
| `chrome-tab-reaper.timer` | `~/.config/systemd/user/` | hourly trigger for the reaper |
| `setup.sh` | — | installer for all of the above |

---

## chrome-wait-online + autostart

At XFCE login, `chrome.desktop` runs `chrome-wait-online`, which:

1. Waits (up to 120s) for NetworkManager to report `full` connectivity AND a
   real external HTTPS probe to succeed, so Chrome doesn't open before the
   network is up (avoids a screenful of "no internet" tabs).
2. Launches `google-chrome` with a fixed set of work tabs (gmail, Proton,
   WhatsApp, Google Messages, ChatGPT, Claude, Perplexity, Slack, gitea).

To change the tab list, edit the `urls=( ... )` array in `chrome-wait-online`
and re-run `setup.sh` (or just re-copy the file).

You can also launch the tab set on demand: `~/.local/bin/chrome-wait-online`.

---

## chrome-tab-reaper

Finds Chrome/Chromium renderer processes ("tabs") using more than a RAM
threshold (default **4 GiB** RSS) and kills them. Killing a renderer frees its
memory and turns that tab into an "Aw, Snap" page; the rest of the browser and
your other tabs keep running.

Runs **hourly** via a **per-user** systemd timer. Pure Python 3 stdlib — no pip
packages.

### Why the user instance (not system-wide)

Chrome runs as your user, and this tool only ever needs to signal your own
renderer processes — so it runs unprivileged in your systemd **user** instance.
No root, no sudo, minimal blast radius (a bug can at worst hit your own
processes). Running when you're logged out buys nothing: if no one's logged in,
there are no Chrome renderers to reap.

### Logs

- **File:** `~/.local/state/chrome-tab-reaper/reaper.log` — timestamped, one
  summary line per run plus a line per kill (a few bytes/hour; no rotation
  needed).
- **Journal:** `journalctl --user -u chrome-tab-reaper.service`

### Configuration

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

### Test / operate

```bash
# Safe: pretend every renderer is over-limit, but kill nothing
DRY_RUN=1 THRESHOLD_GB=0 ~/.local/bin/chrome-tab-reaper

# Real run now
systemctl --user start chrome-tab-reaper.service

# When does it next fire?
systemctl --user list-timers chrome-tab-reaper.timer
```

The reaper timer only runs while you have a login session — fine, since Chrome
only exists then. To run it even with no session open:
`sudo loginctl enable-linger $USER`.
