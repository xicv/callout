#!/bin/bash
# Callout Interrupt Hook - Stops ongoing TTS for this session when user submits a new prompt

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG_FILE="/tmp/callout.log"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

echo "[$(date '+%H:%M:%S')] [interrupt] Session $session_id - stopping TTS" >> "$LOG_FILE"

# Kill only this session's TTS process via PID file
pid_file="/tmp/callout-${session_id}-pid"
if [ -n "$session_id" ] && [ -f "$pid_file" ]; then
  tts_pid=$(cat "$pid_file")
  if kill -0 "$tts_pid" 2>/dev/null; then
    kill -9 "$tts_pid" 2>/dev/null
    echo "[$(date '+%H:%M:%S')] [interrupt] Killed TTS PID $tts_pid [session=$session_id]" >> "$LOG_FILE"
  fi
  rm -f "$pid_file"

  # Restore audio ducking
  if [ -x "$PLUGIN_ROOT/scripts/audio-duck.sh" ]; then
    "$PLUGIN_ROOT/scripts/audio-duck.sh" restore
  fi
else
  # Fallback: no session ID or no PID file — kill all kokoro-tts (legacy behavior)
  if pkill -9 kokoro-tts 2>/dev/null; then
    echo "[$(date '+%H:%M:%S')] [interrupt] Killed kokoro-tts (no session PID)" >> "$LOG_FILE"
    if [ -x "$PLUGIN_ROOT/scripts/audio-duck.sh" ]; then
      "$PLUGIN_ROOT/scripts/audio-duck.sh" restore
    fi
  fi
fi

exit 0
