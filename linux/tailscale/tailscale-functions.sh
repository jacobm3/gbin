# tailscale-functions.sh — a colorized `ts` wrapper for the tailscale CLI
#
#  Source this from your shell rc (jacobrc already does). It defines `ts`, a thin
#  wrapper around the real `tailscale` binary that tints the read-only, human-
#  readable subcommands (status / ping / netcheck / ip / …) k9s-style so the
#  important bits jump out:
#
#     green = up/good     lavender = address/neutral     yellow = relay/idle
#     dim   = offline/idle/counters     red = offline/expired/failed
#
#  Everything else — `tailscale up`, `set`, `login`, `ssh`, `web`, `file`, and any
#  --json output — passes straight through untouched, so interactive prompts,
#  mutating commands and machine-readable output are never disturbed. Color also
#  drops out automatically when stdout is not a terminal (pipes/redirects) or when
#  NO_COLOR is set, so `ts status | grep foo` stays clean.

# `ts` is shipped as an alias elsewhere; drop it first. Defining `ts() {…}` while an
# alias `ts=tailscale` is live would alias-expand the function NAME at parse time and
# silently define `tailscale() {…}` instead (the classic self-recursion footgun).
unalias ts 2>/dev/null

# ── _ts_paint : k9s-style colorizer for tailscale output (internal) ──────────
# Reads stdin, tints addresses / states / durations / counters, writes stdout.
# $1: 1 = force color, 0 = force off, omitted = auto (color iff stdout is a tty).
_ts_paint() {
  # "on" = should we colorize? Take it from the first argument if one was given.
  # "${1-}" means "the first arg, or empty string if there isn't one" (avoids an
  # unbound-variable error under "set -u").
  local on=${1-}
  # If "on" wasn't passed (empty), auto-decide: "[[ -t 1 ]]" is true when stdout
  # is a real terminal, so color on; otherwise (pipe/redirect) color off.
  [[ -n $on ]] || { [[ -t 1 ]] && on=1 || on=0; }
  # If color is off, just pass stdin straight to stdout unchanged ("cat") and
  # return early, skipping all the sed coloring below.
  [[ $on == 1 ]] || { cat; return; }
  # Define the ANSI escape codes we paint with. $'\e[..m' is a literal escape
  # sequence; the terminal interprets these as color/style changes. "n" resets
  # back to normal after each colored span.
  local b=$'\e[1m' dim=$'\e[2m' g=$'\e[32m' r=$'\e[31m' y=$'\e[33m' \
        c=$'\e[38;2;180;190;254m' m=$'\e[35m' n=$'\e[0m'   # c = lavender #b4befe (truecolor)
  # Rules run left→right per line. Address/state rules inject escapes that contain
  # digits (e.g. "38;2;180;190;254"), so every later numeric rule is anchored by a
  # literal neighbor (ms, tx/rx, "ago") and can't accidentally match inside an escape.
  sed -E \
    `# netcheck bullet labels ("* UDP:") and DERP region rows ("- dfw:") → bold` \
    -e "s/^([[:space:]]*[*-] )([^:]+:)/\1${b}\2${n}/" \
    `# addresses: tailscale 100.x CGNAT v4, fd7a: ULA v6, and [v6]:port endpoints → lavender` \
    -e "s/\b100\.[0-9]+\.[0-9]+\.[0-9]+\b/${c}&${n}/g" \
    -e "s/\bfd7a:[0-9a-fA-F:]+/${c}&${n}/g" \
    -e "s/\[[0-9a-fA-F:]+\]:[0-9]+/${c}&${n}/g" \
    `# ownership: shared/personal owner ("jacobm3@") cyan-ish, tag-owned nodes magenta` \
    -e "s/\btagged-devices\b/${m}&${n}/g" \
    -e "s/[A-Za-z0-9._-]+@/${c}&${n}/g" \
    `# health/state words` \
    -e "s/\b(active|online|direct|running|enabled|Healthy|healthy|true|yes|pong)\b/${g}&${n}/Ig" \
    -e "s/\b(relay|idle|waiting|pending|stopped)\b/${y}&${n}/Ig" \
    -e "s/\b(offline|expired|failed|error|unhealthy|NeedsLogin|false)\b/${r}&${n}/Ig" \
    `# "last seen 57d ago" and byte counters → dim (background detail)` \
    -e "s/last seen [0-9]+[a-z]+ ago/${dim}&${n}/Ig" \
    -e "s/\b(tx|rx) [0-9]+/${dim}&${n}/g" \
    `# round-trip / DERP latencies → lavender` \
    -e "s/[0-9]+(\.[0-9]+)?ms\b/${c}&${n}/g"
}

# ── ts : colorized tailscale wrapper ─────────────────────────────────────────
ts() {
  # Decide color once, here, where stdout is still the real terminal.
  local on=1
  { [[ -t 1 ]] && [[ -z ${NO_COLOR-} ]]; } || on=0
  # --json must stay byte-for-byte valid; never paint it.
  case " $* " in *" --json "*|*" --json="*) on=0 ;; esac
  # Only the read-only, tabular/diagnostic subcommands are safe to pipe through sed.
  # Mutating or interactive ones (up/down/login/set/ssh/web/file/cert/serve/funnel…)
  # must keep their own stdin/stdout/tty, so they run unwrapped.
  case "$1" in
    status|ping|netcheck|ip|version|whois|dns|metrics|lock|netmap|debug) ;;
    *) on=0 ;;
  esac
  # "(( on ))" is true when on is 1. "command tailscale" runs the real binary,
  # bypassing this function/any alias, to avoid infinite recursion.
  if (( on )); then
    # Pipe the real output through the colorizer (forcing color on with "1").
    command tailscale "$@" | _ts_paint 1
    # In a pipeline "$?" would be _ts_paint's exit code; PIPESTATUS[0] is the
    # FIRST command's (tailscale's) exit code, which is the one callers care about.
    return "${PIPESTATUS[0]}"
  fi
  # Color disabled: run tailscale directly so its stdin/stdout/tty are untouched.
  command tailscale "$@"
}
