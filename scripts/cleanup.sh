#!/bin/bash
# Callout SessionEnd Hook - Cleanup TTS processes and temp files

LOG_FILE="/tmp/callout.log"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)

echo "[$(date '+%H:%M:%S')] [cleanup] Session $session_id ending" >> "$LOG_FILE"

# Kill running TTS processes
pkill -9 kokoro-tts 2>/dev/null || true

# Clean temp files
rm -f /tmp/callout-input.?????? 2>/dev/null
rm -f /tmp/callout-last-response.txt 2>/dev/null
rm -f /tmp/callout-auto-enabled 2>/dev/null

echo "[$(date '+%H:%M:%S')] [cleanup] Done" >> "$LOG_FILE"

exit 0
