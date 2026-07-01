# qmd — shared Claude Code memory tooling

Scripts to connect any machine to the home-lab's shared memory service (qmd,
running in CT 130 on pve3, exposed at `https://qmd.mink-neon.ts.net`).

The memory content itself lives in a separate repo: **`jacobm3/qmd-corpus`**.

## Scripts

| Script  | What it does                                                              |
|---------|---------------------------------------------------------------------------|
| `setup` | Registers the `qmd` MCP server in Claude Code (user scope). Run once per machine. Idempotent. |
| `save`  | Writes a markdown file to the corpus, commits, and pushes. Reindexed within ~1 min. |

## Connect a new machine

```sh
~/gbin/qmd/setup
```

Requires: this machine on the tailnet, the `claude` CLI installed, and your
normal SSH access to gitea (the same access the `gbin` repo uses).

## Save memory

```sh
~/gbin/qmd/save systems/new-host.md <<'MD'
# new-host facts
...
MD
```

Folders: `projects/  systems/  runbooks/  reference/`. See the corpus repo's
README for what goes where and retrieval tips.

## service/ — deployed config for CT 130

Verbatim copies of what runs on the qmd host (pve3, LXC 130), so a rebuild
doesn't reconstruct from prose. Full rebuild steps are in the corpus doc
`systems/qmd-memory-service.md`; once the CT has node/qmd/tailscale and
`/opt/corpus` cloned, deploy these with:

```sh
# from pve3
for f in qmd.service qmd-sync.service qmd-sync.timer; do
  sudo pct push 130 service/$f /etc/systemd/system/$f
done
sudo pct push 130 service/qmd-sync.sh /usr/local/bin/qmd-sync.sh --perms 755
sudo pct push 130 service/index.yml /root/.config/qmd/index.yml
sudo pct exec 130 -- systemctl daemon-reload
sudo pct exec 130 -- systemctl enable --now qmd.service qmd-sync.timer
```

If you change the timer/units on the CT, copy them back here (`pct pull`) and push.
