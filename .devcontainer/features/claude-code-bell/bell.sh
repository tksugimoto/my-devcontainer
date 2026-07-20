#!/bin/sh
# Hooks run with no controlling terminal, so `> /dev/tty` fails (ENXIO); write to
# claude's own tty instead. Must exit 0 — a non-zero Stop hook blocks the turn.
# The binary is `claude` on some installs and `claude.exe` on others — match both.
for t in $(ps -eo tty=,comm= 2>/dev/null | awk '$2 ~ /^claude(\.exe)?$/ {print $1}'); do
	case $t in
	pts/* | tty*) printf '\a' > "/dev/$t" 2>/dev/null; break ;;
	esac
done
exit 0
