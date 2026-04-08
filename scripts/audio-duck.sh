#!/bin/bash
# Audio Ducking - Lowers Apple Music volume during TTS playback
# Usage: audio-duck.sh [duck|restore]

DUCK_LEVEL="${CALLOUT_DUCK_LEVEL:-5}"
VOLUME_FILE="/tmp/callout-music-volume.txt"
LOG_FILE="/tmp/callout.log"

log() {
  echo "[$(date '+%H:%M:%S')] [duck] $1" >> "$LOG_FILE"
}

is_music_running() {
  pgrep -x "Music" >/dev/null 2>&1
}

get_music_volume() {
  osascript -e 'tell application "Music" to get sound volume' 2>/dev/null
}

set_music_volume() {
  osascript -e "tell application \"Music\" to set sound volume to $1" 2>/dev/null
}

duck() {
  if ! is_music_running; then
    log "Apple Music not running"
    return 0
  fi

  local vol
  vol=$(get_music_volume)
  if [ -z "$vol" ]; then
    return 0
  fi

  echo "$vol" > "$VOLUME_FILE"

  local ducked=$((vol * DUCK_LEVEL / 100))
  if [ "$ducked" -lt 3 ]; then
    ducked=3
  fi

  set_music_volume "$ducked"
  log "Ducked $vol -> $ducked"
}

restore() {
  if [ ! -f "$VOLUME_FILE" ]; then
    return 0
  fi

  local vol
  vol=$(cat "$VOLUME_FILE")

  if is_music_running && [ -n "$vol" ]; then
    set_music_volume "$vol"
    log "Restored to $vol"
  fi

  rm -f "$VOLUME_FILE"
}

case "${1:-}" in
  duck) duck ;;
  restore) restore ;;
  *) echo "Usage: $0 [duck|restore]" ;;
esac
