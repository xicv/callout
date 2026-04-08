#!/bin/bash
# Callout SessionEnd Hook - Cleanup this session's TTS processes and temp files

LOG_FILE="/tmp/callout.log"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)

echo "[$(date '+%H:%M:%S')] [cleanup] Session $session_id ending" >> "$LOG_FILE"

# Kill this session's TTS process if still running
pid_file="/tmp/callout-${session_id}-pid"
if [ -f "$pid_file" ]; then
  tts_pid=$(cat "$pid_file")
  kill -9 "$tts_pid" 2>/dev/null || true
fi

# Clean only this session's temp files
rm -f "/tmp/callout-${session_id}-response.txt" 2>/dev/null
rm -f "/tmp/callout-${session_id}-auto" 2>/dev/null
rm -f "/tmp/callout-${session_id}-pid" 2>/dev/null
rm -f /tmp/callout-input.?????? 2>/dev/null

echo "[$(date '+%H:%M:%S')] [cleanup] Session $session_id cleaned" >> "$LOG_FILE"

exit 0
