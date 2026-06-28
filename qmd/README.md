# qmd — shared Claude Code memory tooling

Scripts to connect any machine to the home-lab's shared memory service (qmd,
running in CT 130 on pve3, exposed at `https://qmd.mink-neon.ts.net`).

The memory content itself lives in a separate repo: **`jacobm3/qmd-corpus`**.

## Scripts

| Script  | What it does                                                              |
|---------|---------------------------------------------------------------------------|
| `setup` | Registers the `qmd` MCP server in Claude Code (user scope). Run once per machine. Idempotent. |
| `save`  | Writes a markdown file to the corpus, commits, and pushes. Reindexed within ~5 min. |

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
