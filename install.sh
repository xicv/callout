#!/bin/bash
# Callout TTS Plugin - Install / Update Script
# Installs TTS dependencies and registers the plugin with Claude Code
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Callout TTS Plugin Installer${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# ─── Step 1: Check prerequisites ───
echo "Checking prerequisites..."

errors=0

# Check for jq
if command -v jq &>/dev/null; then
  echo -e "  ${GREEN}OK${NC} jq"
else
  echo -e "  ${RED}MISSING${NC} jq - install with: brew install jq"
  errors=$((errors + 1))
fi

# Check for uv (needed for Python deps and kokoro-tts)
if command -v uv &>/dev/null; then
  echo -e "  ${GREEN}OK${NC} uv"
else
  echo -e "  ${YELLOW}MISSING${NC} uv - install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
  echo -e "         (uv is needed for kokoro-tts; macOS 'say' will be used as fallback)"
fi

# Check for Claude Code
if command -v claude &>/dev/null; then
  echo -e "  ${GREEN}OK${NC} claude"
else
  echo -e "  ${YELLOW}WARN${NC} claude CLI not found in PATH (may still work if installed elsewhere)"
fi

if [ "$errors" -gt 0 ]; then
  echo ""
  echo -e "${RED}Missing required dependencies. Please install them first.${NC}"
  exit 1
fi

echo ""

# ─── Step 2: Install TTS engine ───
echo "Setting up TTS engine..."

ENGINE_CHOICE="say"

if command -v uv &>/dev/null; then
  echo ""
  echo "Choose TTS engine:"
  echo "  1. Kokoro TTS (recommended - high-quality neural TTS, 82M params, local)"
  echo "  2. macOS say (built-in, instant, decent quality)"
  echo ""
  read -rp "Enter choice (1-2) [default: 1]: " engine_input
  engine_input=${engine_input:-1}

  if [ "$engine_input" = "1" ]; then
    echo ""
    echo "Installing kokoro-tts via uv..."
    if uv tool install kokoro-tts 2>/dev/null || uv tool upgrade kokoro-tts 2>/dev/null; then
      echo -e "  ${GREEN}OK${NC} kokoro-tts installed"
      ENGINE_CHOICE="kokoro"

      # Download model files if not present
      MODEL_DIR="$HOME/.local/share/kokoro-tts"
      mkdir -p "$MODEL_DIR"

      if [ ! -f "$MODEL_DIR/kokoro-v1.0.onnx" ] || [ ! -f "$MODEL_DIR/voices-v1.0.bin" ]; then
        echo ""
        echo "Downloading Kokoro model files (~335MB total)..."

        if [ ! -f "$MODEL_DIR/kokoro-v1.0.onnx" ]; then
          echo "  Downloading kokoro-v1.0.onnx (310MB)..."
          curl -L -o "$MODEL_DIR/kokoro-v1.0.onnx" \
            "https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/kokoro-v1.0.onnx" 2>/dev/null
          echo -e "  ${GREEN}OK${NC} kokoro-v1.0.onnx"
        fi

        if [ ! -f "$MODEL_DIR/voices-v1.0.bin" ]; then
          echo "  Downloading voices-v1.0.bin (25MB)..."
          curl -L -o "$MODEL_DIR/voices-v1.0.bin" \
            "https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin" 2>/dev/null
          echo -e "  ${GREEN}OK${NC} voices-v1.0.bin"
        fi

        echo -e "  ${GREEN}OK${NC} Model files stored in $MODEL_DIR"
      else
        echo -e "  ${GREEN}OK${NC} Model files already present in $MODEL_DIR"
      fi
    else
      echo -e "  ${YELLOW}WARN${NC} kokoro-tts install failed, falling back to macOS say"
      ENGINE_CHOICE="say"
    fi
  fi
else
  echo -e "  Using macOS ${BLUE}say${NC} (install uv + kokoro-tts for better quality)"
fi

echo ""

# ─── Step 3: Install Python deps for markdown stripping ───
echo "Setting up Python dependencies..."
if command -v uv &>/dev/null; then
  (cd "$SCRIPT_DIR" && uv sync 2>/dev/null) && echo -e "  ${GREEN}OK${NC} Python deps" || echo -e "  ${YELLOW}WARN${NC} uv sync failed (sed-based fallback will be used)"
else
  echo -e "  ${YELLOW}SKIP${NC} uv not available (basic markdown stripping will be used)"
fi

echo ""

# ─── Step 4: Make scripts executable ───
echo "Setting permissions..."
chmod +x "$SCRIPT_DIR/scripts/"*.sh
chmod +x "$SCRIPT_DIR/scripts/"*.py 2>/dev/null || true
echo -e "  ${GREEN}OK${NC} Scripts are executable"

echo ""

# ─── Step 5: Choose default voice ───
echo "Choose default voice:"
if [ "$ENGINE_CHOICE" = "kokoro" ]; then
  echo "  1. af_heart   (American female, warm)"
  echo "  2. af_sky     (American female, clear)"
  echo "  3. af_bella   (American female, expressive)"
  echo "  4. am_adam    (American male)"
  echo "  5. am_michael (American male, deep)"
  echo "  6. bf_emma    (British female)"
  echo "  7. bm_daniel  (British male)"
  echo "  8. Custom (enter voice name)"
  echo ""
  read -rp "Enter choice (1-8) [default: 1]: " voice_input
  voice_input=${voice_input:-1}

  case "$voice_input" in
    1) VOICE="af_heart" ;;
    2) VOICE="af_sky" ;;
    3) VOICE="af_bella" ;;
    4) VOICE="am_adam" ;;
    5) VOICE="am_michael" ;;
    6) VOICE="bf_emma" ;;
    7) VOICE="bm_daniel" ;;
    8)
      read -rp "Enter voice name: " VOICE
      VOICE=${VOICE:-af_heart}
      ;;
    *) VOICE="af_heart" ;;
  esac
else
  echo "  1. Samantha (American female, default)"
  echo "  2. Daniel   (British male)"
  echo "  3. Karen    (Australian female)"
  echo "  4. Custom (enter voice name)"
  echo ""
  read -rp "Enter choice (1-4) [default: 1]: " voice_input
  voice_input=${voice_input:-1}

  case "$voice_input" in
    1) VOICE="Samantha" ;;
    2) VOICE="Daniel" ;;
    3) VOICE="Karen" ;;
    4)
      read -rp "Enter voice name: " VOICE
      VOICE=${VOICE:-Samantha}
      ;;
    *) VOICE="Samantha" ;;
  esac
fi

echo ""
echo -e "  Voice: ${GREEN}$VOICE${NC}"
echo ""

# ─── Step 6: Update plugin settings.json ───
echo "Writing plugin settings..."
cat > "$SCRIPT_DIR/settings.json" << SETTINGS_EOF
{
  "env": {
    "CALLOUT_VOICE": "$VOICE",
    "CALLOUT_SPEED": "1.0",
    "CALLOUT_ENGINE": "$ENGINE_CHOICE",
    "CALLOUT_AUTO": "false",
    "CALLOUT_MAX_CHARS": "5000",
    "CALLOUT_AUDIO_DUCK": "true",
    "CALLOUT_DUCK_LEVEL": "5"
  }
}
SETTINGS_EOF
echo -e "  ${GREEN}OK${NC} settings.json updated"

echo ""

# ─── Step 7: Register /callout skill ───
echo "Registering /callout skill..."

SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$SKILLS_DIR/callout"

# Write SKILL.md directly to user skills (plugin skills are namespaced, user skills are direct)
cat > "$SKILLS_DIR/callout/SKILL.md" << SKILL_EOF
---
name: callout
description: "Read Claude's last response aloud using text-to-speech. Supports voice, speed, and engine configuration. Use when: /callout, speak response, read aloud, TTS, text to speech."
---

# Callout - Text-to-Speech for Claude Code

Read the last response or custom text aloud using Kokoro TTS (local, high-quality) with macOS \`say\` as fallback.

The plugin root is at \`$SCRIPT_DIR\`. Use this path for all script references below.

## Behavior

Parse the arguments and execute the appropriate action using the Bash tool:

### If arguments contain \`--stop\`:
\`\`\`bash
bash $SCRIPT_DIR/scripts/interrupt.sh
\`\`\`
Report: "Stopped TTS playback."

### If arguments contain \`--auto-on\`:
\`\`\`bash
echo "true" > /tmp/callout-auto-enabled
\`\`\`
Report: "Auto-TTS enabled. Responses will be spoken automatically."

### If arguments contain \`--auto-off\`:
\`\`\`bash
rm -f /tmp/callout-auto-enabled
\`\`\`
Report: "Auto-TTS disabled."

### If arguments contain \`--list-voices\`:
\`\`\`bash
CLAUDE_PLUGIN_ROOT=$SCRIPT_DIR bash $SCRIPT_DIR/scripts/speak.sh --list-voices
\`\`\`

### If arguments contain \`--config\`:
\`\`\`bash
CLAUDE_PLUGIN_ROOT=$SCRIPT_DIR bash $SCRIPT_DIR/scripts/speak.sh --config
\`\`\`

### If arguments contain custom text (no flags):
Speak the provided text:
\`\`\`bash
echo "\$ARGUMENTS" | CLAUDE_PLUGIN_ROOT=$SCRIPT_DIR bash $SCRIPT_DIR/scripts/speak.sh
\`\`\`

### If no arguments (just \`/callout\`):
Read the cached last response:
\`\`\`bash
CLAUDE_PLUGIN_ROOT=$SCRIPT_DIR bash $SCRIPT_DIR/scripts/speak.sh --from-cache
\`\`\`

### Passing voice/speed overrides:
Extract \`--voice=NAME\` and \`--speed=N\` from arguments and pass them:
\`\`\`bash
CALLOUT_VOICE="NAME" CALLOUT_SPEED="N" CLAUDE_PLUGIN_ROOT=$SCRIPT_DIR bash $SCRIPT_DIR/scripts/speak.sh --from-cache
\`\`\`

## Important
- Always run TTS commands in background so they don't block: append \`&\` or use the script's built-in async mode
- If the cached response file doesn't exist, tell the user there's no recent response to read
- Keep the response to the user brief - just confirm what action was taken
SKILL_EOF
echo -e "  ${GREEN}OK${NC} /callout skill installed"

# ─── Step 8: Register plugin with Claude Code ───
echo "Registering plugin hooks..."

PLUGIN_REGISTERED=false

if command -v claude &>/dev/null; then
  # Add marketplace if not already added
  claude plugin marketplace add "$SCRIPT_DIR" --scope user 2>/dev/null || true
  # Install plugin for hooks
  if claude plugin install callout@callout-tts --scope user 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} Plugin hooks registered"
    PLUGIN_REGISTERED=true
  else
    echo -e "  ${YELLOW}WARN${NC} Plugin install failed (hooks may need manual registration)"
  fi
fi

if [ "$PLUGIN_REGISTERED" = "false" ]; then
  echo ""
  echo -e "  ${YELLOW}Manual registration:${NC}"
  echo "  Run these commands in Claude Code:"
  echo ""
  echo "    claude plugin marketplace add $SCRIPT_DIR --scope user"
  echo "    claude plugin install callout@callout-tts --scope user"
fi

echo ""

# ─── Done ───
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo "Plugin location: $SCRIPT_DIR"
echo "TTS engine:      $ENGINE_CHOICE"
echo "Default voice:   $VOICE"
echo ""
echo "Usage in Claude Code:"
echo "  /callout              Speak the last response"
echo "  /callout Hello world  Speak custom text"
echo "  /callout --auto-on    Enable auto-speak mode"
echo "  /callout --auto-off   Disable auto-speak mode"
echo "  /callout --list-voices Show available voices"
echo "  /callout --config     Show current configuration"
echo "  /callout --stop       Stop current playback"
echo ""
echo "Configuration (in ~/.claude/settings.json env):"
echo "  CALLOUT_VOICE   Voice name (current: $VOICE)"
echo "  CALLOUT_SPEED   Speed multiplier 0.5-2.0 (default: 1.0)"
echo "  CALLOUT_ENGINE  'kokoro', 'say', or 'auto' (current: $ENGINE_CHOICE)"
echo ""
echo "Logs: tail -f /tmp/callout.log"
echo ""
