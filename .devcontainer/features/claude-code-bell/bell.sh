#!/bin/sh
# Hooks run with no controlling terminal, so `> /dev/tty` fails (ENXIO); write to
# claude's own tty instead. Must exit 0 — a non-zero Stop hook blocks the turn.
payload=$(cat 2>/dev/null)

# Stop fires per main-loop turn, not per user turn: dispatching background agents
# ends the turn immediately, and every completion notification starts and ends
# another one — /simplify fans out to 4 agents and so rings 5 times, the first
# within seconds of the prompt. Stay quiet until the fan-out drains.
#
# background_tasks comes straight off the payload and says what is running right
# now, so an agent that dies without reporting back cannot wedge the bell off —
# which is exactly what pairing dispatch ids against completion ids used to do.
# Anything unparseable leaves running empty and falls through to the bell.
#
# Which notifications deserve a bell is declared in claude-settings.json, not here.
running=$(printf '%s' "$payload" | jq '
	[select(.hook_event_name == "Stop") | .background_tasks[]?
	 | select(.type == "subagent")] | length' 2>/dev/null)
[ "${running:-0}" -gt 0 ] && exit 0

# The binary is `claude` on some installs and `claude.exe` on others — match both.
for t in $(ps -eo tty=,comm= 2>/dev/null | awk '$2 ~ /^claude(\.exe)?$/ {print $1}'); do
	case $t in
	pts/* | tty*) printf '\a' > "/dev/$t" 2>/dev/null; break ;;
	esac
done
exit 0
