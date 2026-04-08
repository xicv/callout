#!/bin/bash
# Callout TTS Plugin - Uninstall Script
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Callout TTS Plugin - Uninstall${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# ─── Step 1: Remove user-level skill ───
if [ -d "$HOME/.claude/skills/callout" ]; then
  rm -rf "$HOME/.claude/skills/callout"
  echo -e "${GREEN}OK${NC} Removed /callout skill from ~/.claude/skills/"
else
  echo -e "${YELLOW}SKIP${NC} No skill found at ~/.claude/skills/callout"
fi

# ─── Step 2: Remove plugin registration ───
if command -v claude &>/dev/null; then
  claude plugin uninstall callout@callout-tts --scope user 2>/dev/null && \
    echo -e "${GREEN}OK${NC} Plugin unregistered from Claude Code" || \
    echo -e "${YELLOW}SKIP${NC} Plugin was not registered"

  claude plugin marketplace remove callout-tts --scope user 2>/dev/null && \
    echo -e "${GREEN}OK${NC} Marketplace removed" || \
    echo -e "${YELLOW}SKIP${NC} Marketplace was not registered"
fi

# ─── Step 3: Remove plugin cache ───
if [ -d "$HOME/.claude/plugins/cache/callout-tts" ]; then
  rm -rf "$HOME/.claude/plugins/cache/callout-tts"
  echo -e "${GREEN}OK${NC} Removed plugin cache"
fi

# ─── Step 4: Clean temp files ───
rm -f /tmp/callout-last-response.txt
rm -f /tmp/callout-auto-enabled
rm -f /tmp/callout-input.*
rm -f /tmp/callout-music-volume.txt
rm -f /tmp/callout.log
echo -e "${GREEN}OK${NC} Temp files cleaned"

echo ""

# ─── Step 5: Optional - Remove model files ───
MODEL_DIR="$HOME/.local/share/kokoro-tts"
if [ -d "$MODEL_DIR" ]; then
  model_size=$(du -sh "$MODEL_DIR" 2>/dev/null | cut -f1)
  echo "Kokoro model files found at $MODEL_DIR ($model_size)"
  read -rp "Remove model files? (y/N): " remove_models
  if [ "$remove_models" = "y" ] || [ "$remove_models" = "Y" ]; then
    rm -rf "$MODEL_DIR"
    echo -e "${GREEN}OK${NC} Model files removed"
  else
    echo -e "${YELLOW}KEPT${NC} Model files at $MODEL_DIR"
  fi
fi

echo ""

# ─── Step 6: Optional - Remove kokoro-tts CLI ───
if command -v kokoro-tts &>/dev/null; then
  echo "kokoro-tts CLI is installed at $(command -v kokoro-tts)"
  read -rp "Uninstall kokoro-tts? (y/N): " remove_kokoro
  if [ "$remove_kokoro" = "y" ] || [ "$remove_kokoro" = "Y" ]; then
    uv tool uninstall kokoro-tts 2>/dev/null && \
      echo -e "${GREEN}OK${NC} kokoro-tts uninstalled" || \
      echo -e "${RED}FAIL${NC} Could not uninstall kokoro-tts"
  else
    echo -e "${YELLOW}KEPT${NC} kokoro-tts CLI"
  fi
fi

echo ""

# ─── Step 7: Optional - Remove plugin source ───
echo "Plugin source files are at: $SCRIPT_DIR"
read -rp "Remove plugin source directory? (y/N): " remove_source
if [ "$remove_source" = "y" ] || [ "$remove_source" = "Y" ]; then
  echo -e "${YELLOW}NOTE${NC} Run this after the script exits:"
  echo "  rm -rf $SCRIPT_DIR"
else
  echo -e "${YELLOW}KEPT${NC} Plugin source at $SCRIPT_DIR"
fi

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
echo ""
