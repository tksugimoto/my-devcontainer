#!/bin/sh
# Runs as root at build time. The whole feature folder is copied into the
# container, so bell.sh sits next to this script — the workspace is NOT mounted
# yet, and nothing here may reference it.
set -e
cd "$(dirname "$0")"

# jq parses the hook payload at runtime and merges the settings fragment below.
# It ships in the devcontainer base images, so this normally does nothing.
if ! command -v jq >/dev/null; then
  apt-get update
  apt-get install -y --no-install-recommends jq
  rm -rf /var/lib/apt/lists/*
fi

dest="${_REMOTE_USER_HOME:-$HOME}/.claude"
mkdir -p "$dest"
install -m 755 bell.sh "$dest/bell.sh"

# Merge, never overwrite: settings.json holds unrelated user preferences.
[ -s "$dest/settings.json" ] || echo '{}' > "$dest/settings.json"
jq -s '.[0] * .[1]' "$dest/settings.json" claude-settings.json > "$dest/settings.json.tmp"
mv "$dest/settings.json.tmp" "$dest/settings.json"

# Only what this feature touched: ~/.claude also holds session and project history,
# which is thousands of inodes on a persisted home and needs no ownership change.
if [ -n "$_REMOTE_USER" ]; then
  chown "$_REMOTE_USER" "$dest" "$dest/bell.sh" "$dest/settings.json"
fi
