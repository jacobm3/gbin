# ──────────────────────────────────────────────────────────────────────
#  systemd helpers cheat-sheet
#    sc / scu / jc / scen / scdis / scl / sclu / sclt / sctd / scwh / scgr / scboot
#  Run `schelp` for a colorized list of all of these.
#  sc auto-adds sudo for mutating verbs. scu = --user. jc = journalctl.
#  The list helpers (sclu / sclt / scl / scgr) show SYSTEM objects, then a separate
#  "── user ──" section with your own per-user objects — pass --user (-u) for ONLY your
#  user objects, or --sys (-s) for ONLY the system objects. The single-unit helpers take
#  --user (-u) to target a user unit:
#    sctd -u <t>   scwh -u <u>   scen --user <u>   scdis -u <u>   scboot --user
#    (jc --user -u <u> for user-unit logs)
#  Output is colorized k9s-style on a terminal (green=up, dim=off, red=bad);
#  pipe or redirect any of them and the color drops out automatically.
# ──────────────────────────────────────────────────────────────────────
#
# mnemonics: every name reads as "SystemCtl + verb", so the letters tell you what it does.
# sc     = SystemCtl                       — the base wrapper (auto-sudo for mutating verbs)
# scl    = SystemCtl List                  — units then timers, back to back  (-a = all states)
# sclu   = SystemCtl List Units            — what's loaded/running right now   (-a = all states)
# sclt   = SystemCtl List Timers           — timer schedules: next/last run    (-a = incl. dead)
# sctd   = SystemCtl Timer Detail          — a timer's schedule + the unit it runs
# scwh   = SystemCtl WHere                 — path of a unit file (+ override drop-ins)
# scgr   = SystemCtl GRep                  — find units by name (loaded + on-disk)
# scboot = SystemCtl BOOT                  — boot performance (systemd-analyze)
# scu    = SystemCtl User                  — your own --user units (no sudo), colorized+paged
#          (the list helpers already show user objects by default; -u = user-only)
# scen   = SystemCtl ENable  (--now)       — enable + start in one shot
# scdis  = SystemCtl DISable (--now)       — disable + stop in one shot
# jc     = JournalCtl                      — logs
# schelp = SystemCtl HELP                  — print this command list (colorized)
#
#
#  -- check / inspect (no sudo) ---------------------------------------
#  sc status nginx              state + recent logs (your #1 command)
#  sc is-active nginx           prints active/inactive, sets exit code
#  sc is-enabled nginx          will it start at boot?
#  sc is-failed nginx           did it crash?
#  sc cat nginx                 show the real unit file + any overrides
#  sc show nginx                every property (pipe to grep)
#  sc --failed                  list everything currently broken
#  sc list-units --type=service --state=running    what's running now
#  sc list-unit-files --state=enabled               what starts at boot
#  sc list-dependencies nginx   what it pulls in
#
#  -- control a service (auto-sudo) -----------------------------------
#  sc start nginx
#  sc stop nginx
#  sc restart nginx             stop + start
#  sc reload nginx              re-read config, keep connections alive
#  sc reload-or-restart nginx   reload if supported, else restart
#  sc kill nginx                send SIGTERM (add -s SIGKILL to force)
#
#  -- boot persistence ------------------------------------------------
#  scen nginx                   enable + start in one shot
#  scdis nginx                  disable + stop in one shot
#  sc enable nginx              start at boot, but don't start now
#  sc mask nginx                hard-disable (can't be started at all)
#  sc unmask nginx              undo a mask
#
#  -- editing units ---------------------------------------------------
#  sc edit nginx                safe drop-in override (survives updates)
#  sc edit --full nginx         edit the whole unit
#  sc daemon-reload             ALWAYS run after editing a .service file
#  sc reset-failed nginx        clear the "failed" flag after fixing it
#
#  -- list helpers (scl / sclu) ---------------------------------------
#  sclu                         system services, THEN a "── user ──" section of yours
#  sclu -u                      ONLY your per-user services
#  sclu -s                      ONLY the system services (no user section)
#  sclu -a                      ALL loaded services, any state (system + user)
#  sclu failed                  services in a specific state (system + user)
#  scl                          system units+timers, then your user units+timers
#  scl -a                       all loaded units + all timers (incl. dead), both scopes
#  scl -u                       ONLY your user units + timers
#  scl -s                       ONLY the system units + timers
#
#  -- timers (sclt / sctd) --------------------------------------------
#  sclt                         system timers, THEN a "── user ──" section of yours
#  sclt -u                      ONLY your per-user timers
#  sclt -s                      ONLY the system timers (no user section)
#  sclt -a   (or --all)         include inactive/dead timers too (system + user)
#  sctd certbot                 a system timer's schedule + the unit it triggers
#  sctd -u mybackup             a USER timer's schedule + the unit it triggers
#  sc cat certbot.timer         just the raw .timer unit (OnCalendar=…)
#
#  -- locating / finding unit files (scwh / scgr) ---------------------
#  scwh nginx                   real path of the unit file + override drop-ins
#  scwh -u syncthing            real path of one of YOUR user unit files
#  sc cat nginx                 dump the unit file contents (+ drop-ins)
#  scgr ssh                     find matches in system units, THEN in your user units
#  scgr -u ssh                  find matches in ONLY your user units
#  scgr -s ssh                  find matches in ONLY the system units
#  sc list-unit-files           every installed unit + its enable state
#  sc list-unit-files --type=timer    just the timers on disk
#
#  -- boot performance (scboot) ---------------------------------------
#  scboot                       slowest units to start (systemd-analyze blame)
#  scboot chain                 critical-chain: what actually held up boot
#  scboot time                  total firmware/loader/kernel/userspace time
#
#  -- logs (jc) -------------------------------------------------------
#  jc -u nginx                  all logs for one unit
#  jc -fu nginx                 follow live (Ctrl-C to stop)
#  jc -u nginx -b               this boot only
#  jc -u nginx --since "1 hour ago"
#  jc -u nginx -p err           errors and worse for this unit
#  jc -b -1                     logs from the PREVIOUS boot (post-crash)
#  jc -xe                       jump to end w/ hints (debug startup fails)
#  jc -k                        kernel messages (dmesg-style)
#  jc --disk-usage              how much space the journal eats
#
#  -- your own user services (scu, never needs sudo) ------------------
#  scu status syncthing         colorized + paged, just like `sc status`
#  scu restart syncthing
#  scu enable --now syncthing   (scu already implies --user; no need to repeat it)
#  scu daemon-reload            after editing ~/.config/systemd/user/*.service
#  scu list-timers              your user timers (or: sclt --user)
#
#  -- the rich helpers, --user style (your units only) ----------------
#  the list helpers already append a "── user ──" section by default; add --user (-u)
#  to drop the system section and show ONLY your units. the single-unit helpers take
#  --user (-u) to target a user unit instead of a system one:
#  sclu --user                  ONLY your user services (-a = all states)
#  sclt -u                      ONLY your user timers: next/last run + target
#  scl --user                   ONLY your user units + timers, one pager
#  scgr -u sync                 search ONLY your user units (loaded + ~/.config)
#  sctd -u mybackup             a user timer's schedule + the unit it runs
#  scwh -u syncthing            path of a user unit file + its drop-ins
#  scboot --user                user-session boot/start performance
#  scen --user syncthing        enable + start a user unit (no sudo)
#  scdis -u syncthing           disable + stop a user unit (no sudo)
#  jc --user -u syncthing       logs for a user unit (from the user journal)
#  jc --user -fu syncthing      follow a user unit's logs live
#
#  -- system power (auto-sudo via sc) ---------------------------------
#  sc reboot     |   sc poweroff   |   sc suspend   |   sc hibernate
# ──────────────────────────────────────────────────────────────────────

# These names may already exist as aliases (e.g. jacobrc has `alias sc='systemctl '`
# and `alias jc=journalctl`). If so, bash alias-expands the function-NAME token at
# parse time, so `sc() {...}` silently becomes `systemctl() {...}` — a function that
# calls itself forever, overflowing the stack and SEGV-ing the shell (closes the tab).
# Drop any conflicting aliases first so these define under their intended names.
unalias sc scu scl sclu sclt sctd scwh scgr scboot scen scdis jc schelp sch 2>/dev/null

# ── _sd_paint : k9s-style colorizer (internal) ──────────────────────────
# Reads stdin, tints systemd state words / durations / headers, writes stdout.
# Must run AFTER `column -t`/`cut` — ANSI bytes would otherwise throw off their
# width math; escape sequences are invisible, so they can't break later layout.
#   green = up/good   lavender = neutral/transitional   dim = off/idle   red = bad
# $1: 1 = force color, 0 = force off, omitted = auto (color iff stdout is a tty).
# Pass an explicit flag when piping into a pager — stdout is then the pager pipe,
# so auto-detection would wrongly see "not a tty" and strip the color.
_sd_paint() {
  local on=${1-} mode=${2-}
  [[ -n $on ]] || { [[ -t 1 ]] && on=1 || on=0; }
  [[ $on == 1 ]] || { cat; return; }
  local b=$'\e[1m' dim=$'\e[2m' g=$'\e[32m' r=$'\e[31m' \
        c=$'\e[38;2;180;190;254m' m=$'\e[35m' n=$'\e[0m'   # c = lavender #b4befe (truecolor)
  # one duration "word" = number + unit (longest units first so e.g. "days" wins over
  # "d"); a full span chains several with spaces, e.g. "1 day 10h", "3h 24min".
  local u='(days|day|months|month|weeks|week|years|year|hours|hour|hrs|h|min|s|ms|us|w|d|y)'
  local dur="[0-9]+(\.[0-9]+)?[[:space:]]?${u}\b"
  # structural rules (dividers / paths / ini headers / column headers) — safe anywhere.
  local -a rules=(
    -e "s/^.*──.*\$/${b}${m}&${n}/"
    -e "s|^# /.*|${dim}&${n}|"
    -e "s|^/.*|${c}&${n}|"
    -e "s/^\[[A-Za-z ]+\][[:space:]]*\$/${b}${c}&${n}/"
    -e "s/^(UNIT|NEXT)([[:space:]].*)?\$/${b}&${n}/"
  )
  # state words are a whole-line match, so they'd wrongly tint a unit NAME that merely
  # contains one (e.g. "static" in kmod-static-nodes). Skip them for output that is just
  # names+durations — callers pass "nostate" (e.g. scboot/systemd-analyze).
  [[ $mode == nostate ]] || rules+=(
    -e "s/\b(running|active|exited|listening|mounted|plugged|enabled)\b/${g}&${n}/Ig"
    -e "s/\b(waiting|activating|deactivating|reloading|static|indirect|generated|transient|alias|linked)\b/${c}&${n}/Ig"
    -e "s/\b(dead|inactive|disabled)\b/${dim}&${n}/Ig"
    -e "s/\b(failed|masked|not-found|error)\b/${r}&${n}/Ig"
  )
  rules+=( -e "s/\b${dur}([[:space:]]+${dur})*/${c}&${n}/Ig" )
  sed -E "${rules[@]}"
}

# ── _sd_page : pager for the reformatted helpers (internal) ──────────────
# Our helpers pipe their output, so systemctl never spawns its own pager — restore
# it here. Pages only on a terminal (pipes/redirects pass straight through). less
# flags mirror systemd's own: -F quit if it fits one screen (short lists act like
# plain output), -R render raw color, -S don't wrap (we already clip to width),
# -X leave the output on screen after quitting. Falls back to cat if less is absent.
_sd_page() {
  [[ -t 1 ]] || { cat; return; }
  if command -v less >/dev/null 2>&1; then less -FRSX; else cat; fi
}

# ── _sd_user_ok : is a --user systemd manager reachable? (internal) ───────
# The list helpers now show system units AND your per-user units by default. But a
# root login or a session with no user D-Bus bus has no --user manager — querying it
# there just spews "Failed to connect to bus" to stderr. Probe once, quietly; callers
# skip the user section when this returns non-zero. `show -p Version` is the cheapest
# round-trip to the manager that succeeds iff it's actually answering.
_sd_user_ok() { systemctl --user show -p Version >/dev/null 2>&1; }

# systemctl colorizes itself, but ONLY when its stdout is a tty. When it spawns its
# pager (less) the stdout is the pipe to less, so it drops color — that's why long
# `sc status` / `sclu` output paged out plain. Force SYSTEMD_COLORS to match OUR real
# terminal: 1 when interactive (color survives the pager), 0 when piped/redirected
# (no escape leakage). systemctl's default pager flags already include -R to render it.
# NOTE: evaluate `-t 1` in the function body, NOT inside $(…) — there stdout is captured.

# sc = SystemCtl — the base wrapper; auto-prefixes sudo for mutating verbs.
sc() {
  local c=0; [[ -t 1 ]] && c=1
  case "$1" in
    start|stop|restart|reload|enable|disable|mask|unmask|\
    daemon-reload|reset-failed|set-property|kill)
      (( EUID )) && set -- sudo systemctl "$@" || set -- systemctl "$@"
      ;;
    *) set -- systemctl "$@" ;;   # status/cat/list/etc. stay unprivileged
  esac
  SYSTEMD_COLORS=$c "$@"
}

# The list bodies are split into _sclu/_sclt (emit colorized text, no pager) and the
# public sclu/sclt (page that text). scl can then merge both bodies into ONE pager so
# units and timers share a single scrollback instead of opening back-to-back pagers.
# Color (c) and width (w) are decided by the public fn — its stdout is the real tty, so
# `tput cols` and the color test are accurate before output is piped into _sd_page.

# _sclu <color> <width> <user> <all> [state] — colorized unit list, no pager.
# <user>=1 → operate on the --user manager (your own units) instead of the system one.
# <all>=1 → list-units --all (every loaded service, any state); else filter by [state]
# (default running). systemctl only tints PROBLEM rows (failed/not-found) and leaves
# healthy ones plain, so forcing SYSTEMD_COLORS buys nothing here. Reformat like scgr and
# run through our own colorizer instead, so STATE is colored for every row (running=green,
# dead=dim…).
_sclu() {
  local c=$1 w=$2 user=$3 all=$4; shift 4
  # Build the systemctl base, adding --user when asked. Using an array keeps the
  # optional flag clean — no fragile string-splitting on a possibly-empty variable.
  local -a sctl=(systemctl); (( user )) && sctl+=(--user)
  local -a sel
  (( all )) && sel=(--all) || sel=(--state="${1:-running}")
  { printf 'UNIT\tSTATE\tDESCRIPTION\n'
    "${sctl[@]}" list-units --type=service "${sel[@]}" --no-legend |
      awk '{ i=($1=="●")?2:1; d=""; for(j=i+4;j<=NF;j++) d=d (d?" ":"") $j
             printf "%s\t%s\t%s\n", $i, $(i+3), d }'
  } | column -t -s $'\t' | cut -c "1-$w" | _sd_paint "$c"
}

# _sclt <color> <width> <user> [timer args…] — colorized timer list, no pager.
# <user>=1 → list the --user manager's timers instead of the system ones.
# Date columns hold spaces, so positional reformatting is unreliable; instead keep
# systemctl's own layout, clip to the terminal width (piped output is a fixed 142 cols
# wide and would otherwise wrap), and colorize — durations turn lavender, the header bold.
_sclt() {
  local c=$1 w=$2 user=$3; shift 3
  local -a sctl=(systemctl); (( user )) && sctl+=(--user)
  "${sctl[@]}" list-timers "$@" --no-pager | cut -c "1-$w" | _sd_paint "$c"
}

# sclu = SystemCtl List Units — services in a given state (default: running).
# By DEFAULT shows the system services, then a separate "── user ──" section with your
# own per-user services (skipped if no user manager is reachable).
# -a / --all  → every loaded service regardless of state (maps to list-units --all).
# -u / --user → show ONLY your per-user services (drop the system section).
# -s / --sys  → show ONLY the system services (drop the user section).
# Flags may appear in either order (e.g. `sclu -a --user` or `sclu --sys failed`).
sclu() {
  local all=0 user=0 sys=0
  while [[ $1 == -a || $1 == --all || $1 == -u || $1 == --user || $1 == -s || $1 == --sys ]]; do
    case $1 in -a|--all) all=1 ;; -u|--user) user=1 ;; -s|--sys) sys=1 ;; esac; shift
  done
  local w=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)} c=0; [[ -t 1 ]] && c=1
  {
    if (( user )); then                          # user-only: just your units
      _sclu "$c" "$w" 1 "$all" "$@"
    elif (( ! sys )) && _sd_user_ok; then        # default: system, then user appended
      printf '── system ──\n'
      _sclu "$c" "$w" 0 "$all" "$@"
      printf '\n── user ──\n'
      _sclu "$c" "$w" 1 "$all" "$@"
    else                                         # system-only (-s, or no user manager)
      _sclu "$c" "$w" 0 "$all" "$@"
    fi
  } | _sd_page
}

# sclt = SystemCtl List Timers — every timer with its next/last run time.
# By DEFAULT shows the system timers, then a separate "── user ──" section with your
# own per-user timers (skipped if no user manager is reachable).
# -a / --all  → include inactive/dead timers (maps to list-timers --all).
# -u / --user → show ONLY your per-user timers (drop the system section).
# -s / --sys  → show ONLY the system timers (drop the user section).
sclt() {
  local user=0 all=0 sys=0
  # Pop our flags off the front. -u/-s are OURS (consumed); -a/--all we re-add
  # below as systemctl's own --all so it passes through to list-timers.
  while [[ $1 == -a || $1 == --all || $1 == -u || $1 == --user || $1 == -s || $1 == --sys ]]; do
    case $1 in -a|--all) all=1 ;; -u|--user) user=1 ;; -s|--sys) sys=1 ;; esac; shift
  done
  (( all )) && set -- --all "$@"
  local w=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)} c=0; [[ -t 1 ]] && c=1
  {
    if (( user )); then                          # user-only
      _sclt "$c" "$w" 1 "$@"
    elif (( ! sys )) && _sd_user_ok; then        # default: system, then user appended
      printf '── system ──\n'
      _sclt "$c" "$w" 0 "$@"
      printf '\n── user ──\n'
      _sclt "$c" "$w" 1 "$@"
    else                                         # system-only (-s, or no user manager)
      _sclt "$c" "$w" 0 "$@"
    fi
  } | _sd_page
}

# scl = SystemCtl List — units then timers in ONE paged buffer (any args filter units).
# By DEFAULT shows the full system group (units + timers), then a "── user ──" group
# with your per-user units + timers (skipped if no user manager is reachable).
# -a / --all  → all loaded units (any state) + all timers (incl. dead).
# -u / --user → show ONLY your per-user units and timers (drop the system group).
# -s / --sys  → show ONLY the system units and timers (drop the user group).
scl() {
  local all=0 user=0 sys=0
  while [[ $1 == -a || $1 == --all || $1 == -u || $1 == --user || $1 == -s || $1 == --sys ]]; do
    case $1 in -a|--all) all=1 ;; -u|--user) user=1 ;; -s|--sys) sys=1 ;; esac; shift
  done
  local w=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)} c=0; [[ -t 1 ]] && c=1
  local -a tflag=(); (( all )) && tflag=(--all)
  {
    if (( user )); then                          # user-only group
      _sclu "$c" "$w" 1 "$all" "$@"; echo; _sclt "$c" "$w" 1 "${tflag[@]}"
    elif (( ! sys )) && _sd_user_ok; then        # default: whole system group, then user group
      printf '── system ──\n'
      _sclu "$c" "$w" 0 "$all" "$@"; echo; _sclt "$c" "$w" 0 "${tflag[@]}"
      printf '\n── user ──\n'
      _sclu "$c" "$w" 1 "$all" "$@"; echo; _sclt "$c" "$w" 1 "${tflag[@]}"
    else                                         # system-only group (-s, or no user manager)
      _sclu "$c" "$w" 0 "$all" "$@"; echo; _sclt "$c" "$w" 0 "${tflag[@]}"
    fi
  } | _sd_page
}

# sctd = SystemCtl Timer Detail — a timer's schedule AND the unit it activates.
# Accepts "certbot" or "certbot.timer". -u / --user → a per-user timer.
sctd() {
  local user=0; [[ $1 == -u || $1 == --user ]] && { user=1; shift; }
  local -a sctl=(systemctl); (( user )) && sctl+=(--user)
  local t=$1 c=0; [[ -t 1 ]] && c=1
  [[ $t == *.timer ]] || t=$t.timer
  local svc
  svc=$("${sctl[@]}" show "$t" -p Unit --value 2>/dev/null)
  [[ -z $svc ]] && svc=${t%.timer}.service
  {
    "${sctl[@]}" cat "$t" || return
    printf '\n# ── activates: %s ──\n' "$svc"
    "${sctl[@]}" cat "$svc"
  } | _sd_paint "$c" | _sd_page
}

# scwh = SystemCtl WHere — where does this unit live? real path + override drop-ins.
# -u / --user → look up a per-user unit (e.g. ~/.config/systemd/user/…).
scwh() {
  local user=0; [[ $1 == -u || $1 == --user ]] && { user=1; shift; }
  local -a sctl=(systemctl); (( user )) && sctl+=(--user)
  "${sctl[@]}" show "$1" -p FragmentPath -p DropInPaths --value | _sd_paint
}

# _scgr <width> <user> <pattern> — emit the loaded + on-disk matches (raw, no paint/page).
# Split out of scgr so the public fn can run it once for the system manager and once for
# the --user manager. <user>=1 → query the per-user manager.
_scgr() {
  local w=$1 user=$2 pat=$3
  local -a sctl=(systemctl); (( user )) && sctl+=(--user)
  # list-units cols: [●] NAME  LOAD  ACTIVE  SUB  DESCRIPTION…  — keep NAME, SUB, DESC.
  echo "── loaded ──"
  { printf 'UNIT\tSTATE\tDESCRIPTION\n'
    "${sctl[@]}" list-units      --all --no-legend 2>/dev/null |
      awk -v p="$pat" 'BEGIN{p=tolower(p)}
        { i=($1=="●")?2:1; d=""; for(j=i+4;j<=NF;j++) d=d (d?" ":"") $j
          if(tolower($i" "d) ~ p) printf "%s\t%s\t%s\n", $i, $(i+3), d }'
  } | column -t -s $'\t' | cut -c "1-$w"

  # list-unit-files cols: NAME  STATE  [PRESET] — only NAME is meaningful to search.
  echo "── on disk ──"
  { printf 'UNIT\tSTATE\n'
    "${sctl[@]}" list-unit-files       --no-legend 2>/dev/null |
      awk -v p="$pat" 'BEGIN{p=tolower(p)} tolower($1) ~ p { printf "%s\t%s\n", $1, $2 }'
  } | column -t -s $'\t' | cut -c "1-$w"
}

# scgr = SystemCtl GRep — find units by name or description, NOT by the enum state
# columns (loaded/active/waiting/enabled/…), both loaded in memory and on disk.
# Case-insensitive substring, like grep -i. Output is re-tabulated and clipped to the
# terminal width — systemctl pads to the longest unit name systemwide when piped,
# which otherwise wraps and looks unaligned.
# By DEFAULT searches system units, then a "── user units ──" group for your per-user
# units. -u / --user → search ONLY your per-user units. -s / --sys → system units only.
scgr() {
  local user=0 sys=0
  while [[ $1 == -u || $1 == --user || $1 == -s || $1 == --sys ]]; do
    case $1 in -u|--user) user=1 ;; -s|--sys) sys=1 ;; esac; shift
  done
  local w=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)} c=0; [[ -t 1 ]] && c=1
  {
    if (( user )); then                          # user-only
      _scgr "$w" 1 "$1"
    elif (( ! sys )) && _sd_user_ok; then        # default: system units, then user units
      echo "── system units ──"; _scgr "$w" 0 "$1"
      printf '\n── user units ──\n'; _scgr "$w" 1 "$1"
    else                                         # system-only (-s, or no user manager)
      _scgr "$w" 0 "$1"
    fi
  } | _sd_paint "$c" | _sd_page
}

# scboot = SystemCtl BOOT — boot performance via systemd-analyze (default: blame).
# -u / --user → analyze your user session's manager instead of the system one.
scboot() {
  local user=0; [[ $1 == -u || $1 == --user ]] && { user=1; shift; }
  local -a sa=(systemd-analyze); (( user )) && sa+=(--user)
  local c=0; [[ -t 1 ]] && c=1
  case "$1" in
    chain) "${sa[@]}" critical-chain ;;
    time)  "${sa[@]}" time ;;
    *)     "${sa[@]}" blame ;;
  esac | _sd_paint "$c" nostate | _sd_page
}

# scu = SystemCtl User — operate on your own --user units (never needs sudo).
# Mirrors `sc`: forces SYSTEMD_COLORS to our real tty so status/cat stay colorized
# through the pager, and 0 when piped/redirected so no escape codes leak.
scu() {
  local c=0; [[ -t 1 ]] && c=1
  SYSTEMD_COLORS=$c systemctl --user "$@"
}
# jc = JournalCtl — the log reader. For user-unit logs: `jc --user -u <unit>`
# (journalctl --user reads your per-user journal); --user passes straight through.
jc()  { journalctl "$@"; }

# the two-step savers, as their own verbs.  -u / --user → act on a user unit (no sudo).
# scen  = SystemCtl ENable  (--now) — enable + start in one shot.
scen() {
  [[ $1 == -u || $1 == --user ]] && { shift; systemctl --user enable --now "$@"; return; }
  (( EUID )) && sudo systemctl enable  --now "$@" || systemctl enable  --now "$@"
}
# scdis = SystemCtl DISable (--now) — disable + stop in one shot.
scdis(){
  [[ $1 == -u || $1 == --user ]] && { shift; systemctl --user disable --now "$@"; return; }
  (( EUID )) && sudo systemctl disable --now "$@" || systemctl disable --now "$@"
}

# schelp = SystemCtl HELP — print the list of helpers defined here, aligned and paged.
# Self-contained coloring (bold command name) — not _sd_paint, whose state-word
# rules would wrongly tint words like "running"/"timers" in the descriptions.
schelp() {
  local b='' n=''
  [[ -t 1 ]] && { b=$'\e[1m' n=$'\e[0m'; }
  {
    printf '%s\n\n' "${b}── systemd helpers ──${n}  (sc auto-sudoes mutating verbs; lists are colored & paged)"
    { printf 'COMMAND\tMNEMONIC\tWHAT IT DOES\n'
      printf 'sc\tSystemCtl\twrapper: sc status|start|stop|restart|enable|cat|edit <unit>\n'
      printf 'scl\tSC List\t[-a][-u] system units+timers, then a user section\n'
      printf 'sclu\tSC List-Units\t[-a|state][-u] system services, then a user section (def running)\n'
      printf 'sclt\tSC List-Timers\t[-a][-u] system timers, then a user section: next/last run\n'
      printf 'sctd\tSC Timer-Detail\t[-u] <timer> its schedule + the unit it triggers\n'
      printf 'scwh\tSC WHere\t[-u] <unit> path of the unit file + override drop-ins\n'
      printf 'scgr\tSC GRep\t[-u] <pattern> find system then user units (loaded + on disk)\n'
      printf 'scboot\tSC BOOT\t[-u][chain|time] boot performance (systemd-analyze)\n'
      printf 'scu\tSC User\t<verb> operate on your --user units (never sudo), colored+paged\n'
      printf 'scen\tSC ENable\t[-u] <unit> enable + start in one shot (--now)\n'
      printf 'scdis\tSC DISable\t[-u] <unit> disable + stop in one shot (--now)\n'
      printf 'jc\tJournalCtl\tsystem/service logs (journalctl); jc --user -u <unit> for user logs\n'
      printf 'schelp\tSC HELP\tthis reference (alias: sch)\n'
    } | column -t -s $'\t' | sed -E "s/^([^[:space:]]+)/${b}\\1${n}/"
    printf '%s\n' "  (list helpers append a user section by default; -u/--user = user-only, -s/--sys = system-only)"

    printf '\n%s\n' "${b}── journalctl (jc) ──${n}  (prefix each with 'jc'; add -u <unit> to scope to one unit)"
    { printf 'FLAGS\tWHAT IT DOES\n'
      printf '%s\t%s\n' '-u <unit>'           'logs for ONE unit (repeatable for several)'
      printf '%s\t%s\n' '-f'                  'follow live, like tail -f (Ctrl-C to stop)'
      printf '%s\t%s\n' '-fu <unit>'          'follow ONE unit (-f plus -u)'
      printf '%s\t%s\n' '-e'                  'jump to the end (newest entries)'
      printf '%s\t%s\n' '-xe'                 'end + explanatory hints — debugging failed starts'
      printf '%s\t%s\n' '-b'                  'this boot only;  -b -1 = the previous boot'
      printf '%s\t%s\n' '-k'                  'kernel messages only (dmesg-style)'
      printf '%s\t%s\n' '-p err'              'priority err and worse (emerg|alert|crit|err)'
      printf '%s\t%s\n' '-g <regex>'          'grep the message text'
      printf '%s\t%s\n' '-n 50'               'last 50 lines (default 10);  -n with no number = all'
      printf '%s\t%s\n' '-r'                  'newest first (reverse order)'
      printf '%s\t%s\n' '-o cat'              'bare messages — strip timestamp/host/metadata'
      printf '%s\t%s\n' '--since "1 hour ago"' 'time window (pairs with --until "...")'
      printf '%s\t%s\n' '--disk-usage'        'how much disk the journal is using'
      printf '%s\t%s\n' '--vacuum-time=2d'    'delete journal entries older than 2 days'
    } | column -t -s $'\t' | sed -E "s/^([^[:space:]]+)/${b}\\1${n}/"
  } | _sd_page
}
sch() { schelp "$@"; }   # short alias for schelp

# function tab completion
source /usr/share/bash-completion/completions/systemctl 2>/dev/null
# sc and scu both take unit names as args, so reuse systemctl's completer for both.
complete -F _systemctl sc scu
source /usr/share/bash-completion/completions/journalctl 2>/dev/null
complete -F _journalctl jc
