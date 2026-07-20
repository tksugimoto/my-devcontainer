#!/bin/sh
# Hooks run with no controlling terminal, so `> /dev/tty` fails (ENXIO); write to
# claude's own tty instead. Must exit 0 — a non-zero Stop hook blocks the turn.
for t in $(ps -o tty= -C claude 2>/dev/null); do
	case $t in
	pts/* | tty*) printf '\a' > "/dev/$t" 2>/dev/null; break ;;
	esac
done
exit 0
