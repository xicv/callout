#!/bin/bash
# Callout Interrupt Hook - Stops ongoing TTS when user submits a new prompt

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG_FILE="/tmp/callout.log"

echo "[$(date '+%H:%M:%S')] [interrupt] Stopping TTS playback" >> "$LOG_FILE"

# Kill kokoro-tts processes
if pkill -9 kokoro-tts 2>/dev/null; then
  echo "[$(date '+%H:%M:%S')] [interrupt] Killed kokoro-tts" >> "$LOG_FILE"

  # Restore audio ducking
  if [ -x "$PLUGIN_ROOT/scripts/audio-duck.sh" ]; then
    "$PLUGIN_ROOT/scripts/audio-duck.sh" restore
  fi
fi

# Kill macOS say processes started by callout (not system say)
if pkill -f "say -v.*callout" 2>/dev/null; then
  echo "[$(date '+%H:%M:%S')] [interrupt] Killed say process" >> "$LOG_FILE"

  if [ -x "$PLUGIN_ROOT/scripts/audio-duck.sh" ]; then
    "$PLUGIN_ROOT/scripts/audio-duck.sh" restore
  fi
fi

exit 0
