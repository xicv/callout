#!/bin/bash
# Callout Stop Hook - Caches Claude's last response for /callout to read
# If auto-TTS is enabled, also speaks the response immediately
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CACHE_FILE="/tmp/callout-last-response.txt"
LOG_FILE="/tmp/callout.log"

log() {
  echo "[$(date '+%H:%M:%S')] [cache] $1" >> "$LOG_FILE"
}

log "Stop hook triggered"

# Small delay to ensure transcript is fully written
sleep 0.5

# Read hook input JSON from stdin
input=$(cat)

# Extract transcript path
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -z "$transcript_path" ]; then
  log "No transcript_path in hook input"
  exit 0
fi

# Expand tilde
transcript_path="${transcript_path/#\~/$HOME}"

if [ ! -f "$transcript_path" ]; then
  log "Transcript file not found: $transcript_path"
  exit 0
fi

# Extract Claude's last response text from transcript
# Walk messages in reverse to find the final assistant text
claude_response=""
while IFS= read -r line; do
  message_type=$(echo "$line" | jq -r '.type' 2>/dev/null)

  if [ "$message_type" = "assistant" ]; then
    text=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null | tr '\n' ' ')
    if [ -n "$text" ]; then
      claude_response="$text"
      break
    fi
  fi
done < <(tail -r "$transcript_path" 2>/dev/null || tac "$transcript_path" 2>/dev/null)

if [ -z "$claude_response" ]; then
  log "No assistant text found in transcript"
  exit 0
fi

# Check for TTS_SUMMARY marker - prefer summary over full response
if echo "$claude_response" | grep -q "<!-- TTS_SUMMARY"; then
  tts_summary=$(echo "$claude_response" | awk '
    {
      start = index($0, "<!-- TTS_SUMMARY")
      if (start > 0) {
        rest = substr($0, start + 16)
        end = index(rest, "TTS_SUMMARY -->")
        if (end > 0) {
          content = substr(rest, 1, end - 1)
          gsub(/^[[:space:]]+/, "", content)
          gsub(/[[:space:]]+$/, "", content)
          print content
        }
      }
    }
  ')
  if [ -n "$tts_summary" ]; then
    log "Using TTS_SUMMARY content"
    claude_response="$tts_summary"
  fi
fi

# Cache the response
echo "$claude_response" > "$CACHE_FILE"
log "Cached response (${#claude_response} chars) to $CACHE_FILE"

# Auto-TTS: if enabled, speak immediately
if [ -f /tmp/callout-auto-enabled ]; then
  log "Auto-TTS enabled, speaking response"
  echo "$claude_response" | bash "$PLUGIN_ROOT/scripts/speak.sh" &
fi

exit 0
