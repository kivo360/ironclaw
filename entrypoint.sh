#!/bin/sh
set -e

HOME_DIR="/home/node"
VOLUME="/data"

persist_to_volume() {
  dir_name="$1"
  home_path="$HOME_DIR/$dir_name"
  volume_path="$VOLUME/$dir_name"

  mkdir -p "$volume_path"

  if [ ! -L "$home_path" ]; then
    if [ -d "$home_path" ]; then
      cp -a "$home_path/." "$volume_path/" 2>/dev/null || true
      rm -rf "$home_path"
    fi
    ln -sf "$volume_path" "$home_path"
  fi
}

if [ -d "$VOLUME" ]; then
  persist_to_volume ".openclaw"
  persist_to_volume ".cache"
fi

exec "$@"
