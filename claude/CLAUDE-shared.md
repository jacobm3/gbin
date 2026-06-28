# Shared Claude Code guidance (all machines)

This file is imported by each machine's `~/.claude/CLAUDE.md` via the line
`@~/gbin/claude/CLAUDE-shared.md`. It is synced to every machine by the hourly
`gbin` pull, so editing it here changes Claude's behavior everywhere within the
hour. Put anything true on EVERY machine here; put machine-specific facts in
that machine's own `~/.claude/CLAUDE.md`.

## Local network & tailnet
Two parallel name/address spaces cover the same machines. Know both, because which one works depends on where you're calling from (on-LAN vs. remote-over-tailscale).

- **LAN:** subnet `10.0.0.0/24`, gateway `10.0.0.1`. Local DNS server is `dns-01` at `10.0.0.53`, which serves the **`home.arpa`** zone (RFC 8375 home domain). LAN names look like `<host>.home.arpa` → `10.0.0.x`.
- **Tailnet:** Tailscale MagicDNS domain **`mink-neon.ts.net`**. Tailnet names look like `<host>.mink-neon.ts.net` → a CGNAT `100.x.y.z` address. MagicDNS resolver is `100.100.100.100`. Works from any machine on the tailnet regardless of physical location.
- **resolv.conf search order is `mink-neon.ts.net home.arpa`**, so a bare `<host>` usually resolves to the tailnet name first.
- **Not every host exists in both spaces.** LAN-resident boxes (Proxmox host, VMs, bare-metal workstations) have *both* a `home.arpa` LAN entry and a tailnet name. Service containers fronted by `tailscale serve` (gitea, qmd, ntfy, monitoring, jellyfin) are **tailnet-only** — they have a `100.x`/`*.mink-neon.ts.net` name but **no** `home.arpa` LAN record. Don't assume a `home.arpa` name exists; verify with `getent hosts <host>.home.arpa`.
- **Authoritative sources — don't keep a host list here.** The `home.arpa` LAN records come from dnsmasq, backed by git at `https://gitea.mink-neon.ts.net/jacobm3/dnsmasq-config/src/branch/main/hosts/lan`. For tailnet names/IPs use `tailscale status`. For a one-off LAN lookup use `getent hosts <host>.home.arpa`.

### Always give all four URL forms for a service
Whenever you hand me a URL for a service on one of these machines, give **all four** variants (when they exist) so I can use whichever fits — on-LAN, over-tailscale, by-name, or by-raw-IP:
1. `home.arpa` DNS name — e.g. `https://stingray.home.arpa:8080/`
2. tailnet DNS name — e.g. `https://stingray.mink-neon.ts.net:8080/`
3. LAN IP — e.g. `https://10.0.0.12:8080/`
4. tailnet IP — e.g. `https://100.102.212.126:8080/`

If the service is tailnet-only (no `home.arpa`/LAN entry), give the two tailnet forms and say the LAN forms don't exist rather than inventing them.

## Shared memory (qmd) — primary memory store
A shared, cross-machine memory corpus is searchable via the `qmd` MCP server (tools: `query`, `get`, `multi_get`, `status`), backed by the gitea repo `jacobm3/qmd-corpus`. This is the **primary** place to store and recall durable knowledge — prefer it over the local per-machine `memory/` store for anything that isn't strictly throwaway working notes.

- **Recall first.** Before non-trivial work (touching a host/VM/CT, a service, infra, or a project with prior history), `query` qmd for relevant context instead of guessing or asking. The corpus folders are `projects/ systems/ runbooks/ reference/`.
- **Save durable facts.** When you learn something worth keeping across sessions and machines — a host/network fact, a fix, a procedure, a decision and its reasoning — save it with `~/gbin/qmd/save <folder>/<slug>.md` (markdown body on stdin). One topic per file, descriptive H1 title, lead with the answer, use real names (hostnames, VMIDs, paths). Searchable within ~5 min.
- **Don't save** secrets/credentials (the corpus is git-scanned), or things already living in a code repo or this CLAUDE.md. Instead store new secrets in vault.mink-neon.ts.net.
- **Write URLs as clickable links** — bare `https://host/path` or `<https://host/path>` autolinks, not inside backticks. The corpus is viewed in the gitea UI, where backtick code spans render as non-clickable text.
- Setup on a new machine: `~/gbin/qmd/setup`. Tooling lives in `~/gbin/qmd/`; service is reachable at `https://qmd.mink-neon.ts.net`.



## SSH to other machines
- SSH keypair is `~/.ssh/id_ed25519` (private key only; no `.pub` checked in). Use it for key-based logins to other boxes on the network.
- `~/.ssh/known_hosts` is hashed (`HashKnownHosts yes`), so host entries aren't human-readable — discover live hosts with `ip neigh` or a quick `nmap`/ping sweep of `10.0.0.0/24` instead of grepping known_hosts.
- Assume key-based, non-interactive SSH should "just work" to other lab machines; if it doesn't, surface the auth error rather than retrying with passwords.

## Secrets access
- Secrets are stored in a Hashicorp Vault instance at `https://vault.mink-neon.ts.net` or `10.0.0.11` using approle stored in `~/.claude/vault-approle.json` 

## Notifications (ntfy)
- To push a notification to the user, use the ntfy topic stored in Vault at `secret/ntfy` (KV v2 mount `secret`). Fields: `server`=`https://ntfy.sh`, `topic`=`claude-ndyklmawvyorpnyl`, `url`=`https://ntfy.sh/claude-ndyklmawvyorpnyl`.
- Publish: `curl -d "message" https://ntfy.sh/claude-ndyklmawvyorpnyl`. Public ntfy.sh, unauthenticated; the hard-to-guess topic is the access control. Prefer fetching the topic from Vault over hardcoding it.

## Git access
- The primary place for git version control is a local gitea instance at https://gitea.mink-neon.ts.net/
- Use your own gitea user account
- username: 'claude'
- password in in vault: /v1/secret/data/gitea-claude:password 
- PAT: /v1/secret/data/gitea-claude:pat 
- **All new gitea repos must be owned by `jacobm3`, not `claude`.** `claude` is a gitea *site admin*, so create repos directly under jacobm3 via the admin API (claude retains owner-level access automatically — no collaborator step needed). `jacobm3` is a user account, not an org (gitea has no orgs; user/org names share one namespace so an org named `jacobm3` can't exist):
  `curl -X POST -H "Authorization: token $PAT" -H "Content-Type: application/json" https://gitea.mink-neon.ts.net/api/v1/admin/users/jacobm3/repos -d '{"name":"<repo>","private":true,"default_branch":"main"}'`
- To move an existing `claude`-owned repo to jacobm3: `curl -X POST -H "Authorization: token $PAT" -H "Content-Type: application/json" https://gitea.mink-neon.ts.net/api/v1/repos/claude/<repo>/transfer -d '{"new_owner":"jacobm3"}'`
- when you ask me if i want you to commit changes to an existing repo, if i say 'yes' assume i mean to commit and push.
- **`cnp`** (shorthand for "commit and push"): when I say `cnp`, stage all current changes, commit them with a concise message describing what we just did, and push. Push to whatever the current repo's `origin` points at — don't assume gitea vs github; use the remote(s) actually configured for that repo. If `origin` pushes to multiple remotes, push to all of them.

## Working preferences
- Prefer real verification: when you change something, check the actual running state (service status, a curl/ping) rather than assuming success.
- This is a single-user environment; it's fine to act without hand-holding on routine ops, but confirm anything that could take down networking or storage.

## Communication style
- be direct and token efficient in your output
- never qualify statements with flowery phrases like "embarrassingly parallel" or "and it's worth being clear on" or "that's a great question" or "the honest truth is" or "honest caveats are".  
- i assume you're being honest.  always be honest.

## Coding style
- assume the code you write will be maintained in the future by a human with limited coding skill and declining cognitive capacity
- don't use complex or clever code features
- keep code as simple and easy to read as possible
- comment abundantly indicating what you're doing and why
