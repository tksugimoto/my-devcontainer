#!/bin/bash
# Claude Code status line: model name, git branch, context usage (gauge), rate limits.
# Reads the status line JSON on stdin. Every section disappears when its field is absent.

# Reset times render in the container's timezone, set by containerEnv in
# devcontainer.json. The fallback keeps the line correct outside this devcontainer.
export TZ="${TZ:-Asia/Tokyo}"

GAUGE_WIDTH=10

# One jq pass for every field. Joined on US (\u001f) rather than tab: tab is an IFS
# whitespace character, so runs of absent fields would collapse into one delimiter
# and shift every later value left.
IFS=$'\x1f' read -r model cwd used five five_at week week_at < <(jq -r '[
  .model.display_name                    // "",
  .workspace.current_dir                 // "",
  .context_window.used_percentage        // "",
  .rate_limits.five_hour.used_percentage // "",
  .rate_limits.five_hour.resets_at       // "",
  .rate_limits.seven_day.used_percentage // "",
  .rate_limits.seven_day.resets_at       // ""
] | join("\u001f")')

branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# Bright colors only: dim renders unreadably on this terminal.
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
MAGENTA='\033[95m'
RESET='\033[0m'

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

# label, used %, reset epoch, date format -> rl_out="5h:23% (→14:30)"; empty when no data.
rl_window() {
  local when
  rl_out=""
  [ -n "$2" ] || return
  printf -v rl_out '%s:%.0f%%' "$1" "$2"
  [ -n "$3" ] || return
  printf -v when "%($4)T" "$3" 2>/dev/null && rl_out="$rl_out (→$when)"
}

# The 5h window resets within the day, the 7d window days out — hence the coarser format.
rl=()
rl_window 5h "$five" "$five_at" '%H:%M'
[ -n "$rl_out" ] && rl+=("$rl_out")
rl_window 7d "$week" "$week_at" '%m/%d %H:%M'
[ -n "$rl_out" ] && rl+=("$rl_out")
[ ${#rl[@]} -gt 0 ] && parts+=("${MAGENTA}${rl[*]}${RESET}")

printf -v line '%s | ' "${parts[@]}"
printf '%b' "${line% | }"
