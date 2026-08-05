#!/bin/sh
# Hooks run with no controlling terminal, so `> /dev/tty` fails (ENXIO); write to
# claude's own tty instead. Must exit 0 — a non-zero Stop hook blocks the turn.

# Stop fires per main-loop turn, not per user turn: dispatching background agents
# ends the turn immediately, and every completion notification starts and ends
# another one — /simplify fans out to 4 agents and so rings 5 times, the first
# within seconds of the prompt. Stay quiet until the fan-out drains.
#
# background_tasks comes straight off the payload and says what is running right
# now, so an agent that dies without reporting back cannot wedge the bell off —
# which is exactly what pairing dispatch ids against completion ids used to do.
#
# claude-settings.json picks which events reach this script; this is the one rule
# it cannot express, because Stop takes no matcher. Every other event rings — jq
# exits non-zero on false, on unparseable input and on empty stdin alike.
jq -e '.hook_event_name == "Stop"
       and any(.background_tasks[]?; .type == "subagent")' >/dev/null 2>&1 && exit 0

# The binary is `claude` on some installs and `claude.exe` on others — match both.
for t in $(ps -eo tty=,comm= 2>/dev/null | awk '$2 ~ /^claude(\.exe)?$/ {print $1}'); do
	case $t in
	pts/* | tty*) printf '\a' > "/dev/$t" 2>/dev/null; break ;;
	esac
done
exit 0
