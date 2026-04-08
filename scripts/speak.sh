#!/bin/bash
# Callout TTS - Main speech engine wrapper
# Reads text from stdin, file, or cache and speaks it via Kokoro TTS or macOS say
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CACHE_FILE="/tmp/callout-last-response.txt"
LOG_FILE="/tmp/callout.log"

# Configuration via environment (set in settings.json or overridden per-call)
VOICE="${CALLOUT_VOICE:-af_heart}"
SPEED="${CALLOUT_SPEED:-1.0}"
ENGINE="${CALLOUT_ENGINE:-auto}"
MAX_CHARS="${CALLOUT_MAX_CHARS:-5000}"
AUDIO_DUCK="${CALLOUT_AUDIO_DUCK:-true}"

log() {
  echo "[$(date '+%H:%M:%S')] [callout] $1" >> "$LOG_FILE"
}

detect_engine() {
  if [ "$ENGINE" != "auto" ]; then
    echo "$ENGINE"
    return
  fi
  if command -v kokoro-tts &>/dev/null; then
    echo "kokoro"
  elif command -v say &>/dev/null; then
    echo "say"
  else
    echo "none"
  fi
}

list_voices() {
  local engine
  engine=$(detect_engine)
  echo "Engine: $engine"
  echo "Current voice: $VOICE"
  echo "Current speed: $SPEED"
  echo ""
  case "$engine" in
    kokoro)
      echo "=== Kokoro Voices (54 total) ==="
      echo ""
      echo "American English Female:"
      echo "  af_alloy, af_aoede, af_bella, af_heart, af_jessica,"
      echo "  af_kore, af_nicole, af_nova, af_river, af_sarah, af_sky"
      echo ""
      echo "American English Male:"
      echo "  am_adam, am_echo, am_eric, am_fenrir, am_liam,"
      echo "  am_michael, am_onyx, am_puck"
      echo ""
      echo "British English Female:"
      echo "  bf_alice, bf_emma, bf_isabella, bf_lily"
      echo ""
      echo "British English Male:"
      echo "  bm_daniel, bm_fable, bm_george, bm_lewis"
      echo ""
      echo "French: ff_siwis"
      echo "Italian: if_sara, im_nicola"
      echo "Japanese: jf_alpha, jf_gongitsune, jf_nezumi, jf_tebukuro, jm_kumo"
      echo "Mandarin: zf_xiaobei, zf_xiaoni, zf_xiaoxiao, zf_xiaoyi,"
      echo "          zm_yunjian, zm_yunxi, zm_yunxia, zm_yunyang"
      ;;
    say)
      echo "=== macOS say voices ==="
      say -v '?' 2>/dev/null | head -30
      echo "..."
      echo "(Run 'say -v ?' for full list)"
      ;;
    *)
      echo "No TTS engine found. Run install.sh to set up Kokoro TTS."
      ;;
  esac
}

show_config() {
  local engine
  engine=$(detect_engine)
  echo "=== Callout TTS Configuration ==="
  echo ""
  echo "Engine:    $engine (CALLOUT_ENGINE=$ENGINE)"
  echo "Voice:     $VOICE (CALLOUT_VOICE)"
  echo "Speed:     $SPEED (CALLOUT_SPEED)"
  echo "Max chars: $MAX_CHARS (CALLOUT_MAX_CHARS)"
  echo "Auto-TTS:  $([ -f /tmp/callout-auto-enabled ] && echo 'ON' || echo 'OFF')"
  echo "Ducking:   $AUDIO_DUCK (CALLOUT_AUDIO_DUCK)"
  echo ""
  echo "Override in ~/.claude/settings.json under env:{}"
  echo "Or per-call: CALLOUT_VOICE=bf_emma /callout"
}

strip_markdown() {
  local text="$1"
  if command -v uv &>/dev/null && [ -f "$PLUGIN_ROOT/scripts/strip_markdown.py" ]; then
    echo "$text" | uv run --project "$PLUGIN_ROOT" python "$PLUGIN_ROOT/scripts/strip_markdown.py" 2>>"$LOG_FILE" || echo "$text"
  else
    # Fallback: basic sed-based markdown stripping
    echo "$text" \
      | sed 's/```[a-z]*//g' \
      | sed 's/```//g' \
      | sed 's/\*\*//g' \
      | sed 's/\*//g' \
      | sed 's/^#\+ //g' \
      | sed 's/`[^`]*`//g' \
      | sed 's/\[([^]]*)\]([^)]*)/\1/g' \
      | sed '/^[|+-]/d' \
      | sed 's/https\?:\/\/[^ ]*//g' \
      | tr -s ' \n' ' '
  fi
}

speak_kokoro() {
  local text="$1"
  local tmpfile
  tmpfile=$(mktemp /tmp/callout-input.XXXXXX)
  chmod 600 "$tmpfile"
  echo "$text" > "$tmpfile"

  log "Speaking ${#text} chars with kokoro voice=$VOICE speed=$SPEED"

  # Audio ducking
  if [ "$AUDIO_DUCK" = "true" ] && [ -x "$PLUGIN_ROOT/scripts/audio-duck.sh" ]; then
    "$PLUGIN_ROOT/scripts/audio-duck.sh" duck
  fi

  # Model files location
  local model_dir="${CALLOUT_MODEL_DIR:-$HOME/.local/share/kokoro-tts}"
  local model_args=""
  if [ -f "$model_dir/kokoro-v1.0.onnx" ]; then
    model_args="--model $model_dir/kokoro-v1.0.onnx --voices $model_dir/voices-v1.0.bin"
  fi

  kokoro-tts "$tmpfile" --voice "$VOICE" --speed "$SPEED" --stream $model_args >>"$LOG_FILE" 2>&1 &
  local tts_pid=$!

  # Restore audio when TTS finishes
  if [ "$AUDIO_DUCK" = "true" ] && [ -x "$PLUGIN_ROOT/scripts/audio-duck.sh" ]; then
    (
      while kill -0 "$tts_pid" 2>/dev/null; do sleep 0.5; done
      "$PLUGIN_ROOT/scripts/audio-duck.sh" restore
      rm -f "$tmpfile"
    ) &
  else
    (
      while kill -0 "$tts_pid" 2>/dev/null; do sleep 0.5; done
      rm -f "$tmpfile"
    ) &
  fi
}

speak_say() {
  local text="$1"
  local rate
  # Convert speed multiplier to words-per-minute (default ~175 wpm)
  rate=$(echo "$SPEED" | awk '{printf "%d", $1 * 175}')

  log "Speaking ${#text} chars with say voice=$VOICE rate=$rate"

  if [ "$AUDIO_DUCK" = "true" ] && [ -x "$PLUGIN_ROOT/scripts/audio-duck.sh" ]; then
    "$PLUGIN_ROOT/scripts/audio-duck.sh" duck
  fi

  say -v "$VOICE" -r "$rate" "$text" &
  local tts_pid=$!

  if [ "$AUDIO_DUCK" = "true" ] && [ -x "$PLUGIN_ROOT/scripts/audio-duck.sh" ]; then
    (
      while kill -0 "$tts_pid" 2>/dev/null; do sleep 0.5; done
      "$PLUGIN_ROOT/scripts/audio-duck.sh" restore
    ) &
  fi
}

speak() {
  local text="$1"
  local engine
  engine=$(detect_engine)

  if [ -z "$text" ] || [ ${#text} -lt 2 ]; then
    log "No text to speak"
    echo "No text to speak."
    return 1
  fi

  # Truncate to max chars
  text="${text:0:$MAX_CHARS}"

  # Strip markdown
  text=$(strip_markdown "$text")

  if [ -z "$text" ] || [ ${#text} -lt 2 ]; then
    log "Text empty after markdown stripping"
    echo "No speakable text after cleaning."
    return 1
  fi

  # Kill any existing TTS playback first
  pkill -9 kokoro-tts 2>/dev/null || true

  case "$engine" in
    kokoro)
      speak_kokoro "$text"
      ;;
    say)
      # For macOS say, use Samantha as default if voice looks like a kokoro voice
      if [[ "$VOICE" =~ ^[a-z][a-z]_ ]]; then
        VOICE="Samantha"
      fi
      speak_say "$text"
      ;;
    *)
      echo "No TTS engine available. Run: bash $PLUGIN_ROOT/install.sh"
      return 1
      ;;
  esac
}

# --- Main ---
case "${1:-}" in
  --list-voices)
    list_voices
    ;;
  --config)
    show_config
    ;;
  --from-cache)
    if [ ! -f "$CACHE_FILE" ]; then
      echo "No cached response found. Ask Claude something first, then run /callout."
      exit 1
    fi
    text=$(cat "$CACHE_FILE")
    speak "$text"
    echo "Speaking last response ($(echo "$text" | wc -c | tr -d ' ') chars)..."
    ;;
  *)
    # Read from stdin if no file argument
    if [ -t 0 ] && [ -n "${1:-}" ]; then
      speak "$*"
    elif [ ! -t 0 ]; then
      text=$(cat)
      speak "$text"
    else
      echo "Usage: speak.sh [--from-cache | --list-voices | --config | TEXT]"
      echo "  Or pipe text: echo 'hello' | speak.sh"
    fi
    ;;
esac
