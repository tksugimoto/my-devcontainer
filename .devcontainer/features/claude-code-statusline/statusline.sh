#!/bin/bash
# Claude Code status line: model name, git branch, context usage (gauge), rate limits.
# Reads the status line JSON on stdin. Every section disappears when its field is absent.

# Reset times render in whatever TZ the environment sets — the container's comes
# from containerEnv in devcontainer.json. No default here: outside the container
# TZ is deliberately unset so glibc reads /etc/localtime, and hardcoding a zone
# would override the host's correct one.

GAUGE_WIDTH=10

# One jq pass for every field. Joined on US (\u001f) rather than tab: tab is an IFS
# whitespace character, so runs of absent fields would collapse into one delimiter
# and shift every later value left. join renders an absent field as an empty
# string on its own, so no per-field default is needed.
IFS=$'\x1f' read -r model cwd used five five_at week week_at < <(jq -r '[
  .model.display_name,
  .workspace.current_dir,
  .context_window.used_percentage,
  .rate_limits.five_hour.used_percentage,
  .rate_limits.five_hour.resets_at,
  .rate_limits.seven_day.used_percentage,
  .rate_limits.seven_day.resets_at
] | join("\u001f")')

# Read .git/HEAD instead of forking git: git costs ~50ms per run here and the
# status line repaints constantly, while everything else in this script is a
# builtin. Stays empty when HEAD is detached, matching `branch --show-current`.
branch=""
d=$cwd
while [ -n "$d" ] && [ ! -e "$d/.git" ]; do d=${d%/*}; done
if [ -n "$d" ]; then
  gitdir=$d/.git
  # A linked worktree or submodule has .git as a file pointing at the real gitdir.
  [ -f "$gitdir" ] && { read -r _ gitdir < "$gitdir"; [[ $gitdir == /* ]] || gitdir=$d/$gitdir; }
  read -r head < "$gitdir/HEAD" 2>/dev/null
  [[ $head == ref:*refs/heads/* ]] && branch=${head#*refs/heads/}
fi

# Bright colors only: dim renders unreadably on this terminal. Real escape bytes,
# not backslash-033 for a later printf '%b' to expand: %b would rescan the
# interpolated model and branch names too, expanding any escape they contain.
CYAN=$'\033[96m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
MAGENTA=$'\033[95m'
RESET=$'\033[0m'

parts=("${CYAN}${model}${RESET}")

[ -n "$branch" ] && parts+=("${GREEN}${branch}${RESET}")

if [ -n "$used" ]; then
  printf -v pct '%.0f' "$used"
  filled=$(( (pct * GAUGE_WIDTH + 50) / 100 ))
  [ "$filled" -gt "$GAUGE_WIDTH" ] && filled=$GAUGE_WIDTH
  printf -v on '%*s' "$filled" ''
  printf -v off '%*s' "$(( GAUGE_WIDTH - filled ))" ''
  parts+=("${YELLOW}${on// /●}${off// /○} ${pct}%${RESET}")
fi

# label, used %, reset epoch, date format -> appends "5h:23% (→14:30)" to rl;
# appends nothing when there is no data for the window.
rl_window() {
  local when out
  [ -n "$2" ] || return
  printf -v out '%s:%.0f%%' "$1" "$2"
  [ -n "$3" ] && printf -v when "%($4)T" "$3" 2>/dev/null && out="$out (→$when)"
  rl+=("$out")
}

# The 5h window resets within the day, the 7d window days out — hence the coarser format.
rl=()
rl_window 5h "$five" "$five_at" '%H:%M'
rl_window 7d "$week" "$week_at" '%m/%d %H:%M'
[ ${#rl[@]} -gt 0 ] && parts+=("${MAGENTA}${rl[*]}${RESET}")

printf -v line '%s | ' "${parts[@]}"
printf '%s' "${line% | }"
