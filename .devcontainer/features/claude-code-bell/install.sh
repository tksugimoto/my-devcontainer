#!/bin/sh
# Runs as root at build time. The whole feature folder is copied into the
# container, so bell.sh sits next to this script — the workspace is NOT mounted
# yet, and nothing here may reference it.
set -e
cd "$(dirname "$0")"

command -v jq >/dev/null || { apt-get update && apt-get install -y --no-install-recommends jq; }

dest="${_REMOTE_USER_HOME:-$HOME}/.claude"
mkdir -p "$dest"
install -m 755 bell.sh "$dest/bell.sh"

# Merge, never overwrite: settings.json holds unrelated user preferences.
[ -s "$dest/settings.json" ] || echo '{}' > "$dest/settings.json"
jq -s '.[0] * .[1]' "$dest/settings.json" claude-settings.json > "$dest/settings.json.tmp"
mv "$dest/settings.json.tmp" "$dest/settings.json"

[ -n "$_REMOTE_USER" ] && chown -R "$_REMOTE_USER" "$dest"
exit 0
