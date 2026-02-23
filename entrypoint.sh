#!/bin/sh
set -e

HOME_DIR="/home/node"
VOLUME="/data"

if [ ! -d "$VOLUME" ]; then
  echo "FATAL: /data volume not mounted — data WILL be lost on restart" >&2
  exit 1
fi

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

persist_to_volume ".openclaw"
persist_to_volume ".cache"
persist_to_volume ".local"
persist_to_volume ".agents"
persist_to_volume ".config"
persist_to_volume ".brew"

mkdir -p "$VOLUME/bin"
export PATH="$VOLUME/bin:$PATH"

# Persist Homebrew prefix across restarts
# Homebrew on Linux installs to /home/linuxbrew/.linuxbrew (not under $HOME_DIR)
BREW_SYSTEM="/home/linuxbrew/.linuxbrew"
BREW_VOLUME="$VOLUME/linuxbrew"
mkdir -p "$BREW_VOLUME"
if [ ! -L "$BREW_SYSTEM" ]; then
  if [ -d "$BREW_SYSTEM" ]; then
    cp -a "$BREW_SYSTEM/." "$BREW_VOLUME/" 2>/dev/null || true
    rm -rf "$BREW_SYSTEM"
  fi
  mkdir -p "$(dirname "$BREW_SYSTEM")"
  ln -sf "$BREW_VOLUME" "$BREW_SYSTEM"
fi
if [ -d "$BREW_SYSTEM/bin" ]; then
  export PATH="$BREW_SYSTEM/bin:$PATH"
fi
# Also add ~/.brew/bin if user installed brew under $HOME_DIR
if [ -d "$HOME_DIR/.brew/bin" ]; then
  export PATH="$HOME_DIR/.brew/bin:$PATH"
fi

if [ -d "/app/skills" ]; then
  mkdir -p "$VOLUME/.openclaw"
  ln -sfn /app/skills "$VOLUME/.openclaw/skills"
fi

exec "$@"
