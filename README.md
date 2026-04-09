# Callout — Text-to-Speech for Claude Code

Speak Claude Code responses aloud using [Kokoro TTS](https://github.com/hexgrad/kokoro) (local, 82M params, #1 on TTS Arena) with macOS `say` as fallback.

## Features

- `/callout` — speak the last response on demand
- `/callout Hello world` — speak custom text
- `/callout --auto-on` — automatically speak every response
- 54 voices (American, British, French, Italian, Japanese, Mandarin)
- Configurable voice, speed, and engine
- Audio ducking (lowers Apple Music while speaking)
- Smart interruption — stops playback when you start typing
- Silent operation — no output noise, just audio
- Multi-session isolation — each Claude Code session gets its own cache
- Markdown stripping for clean speech output
- File reading — `/callout path/to/file.txt` reads a file aloud

## Quick Start

```bash
git clone https://github.com/xicv/callout.git
cd callout
./install.sh
```

The installer handles everything:
1. Installs `kokoro-tts` via `uv`
2. Downloads model files (~335MB) to `~/.local/share/kokoro-tts/`
3. Registers the plugin hooks with Claude Code
4. Creates the `/callout` skill in `~/.claude/skills/`
5. Lets you pick your default voice

Then restart Claude Code and use `/callout`.

## Usage

| Command | Description |
|---|---|
| `/callout` | Speak the last response |
| `/callout Hello world` | Speak custom text |
| `/callout --voice=bf_emma` | Use a specific voice |
| `/callout --speed=1.5` | Faster speech |
| `/callout --voice=am_adam --speed=0.8 Hello` | Combine flags with text |
| `/callout --auto-on` | Auto-speak every response |
| `/callout --auto-off` | Disable auto-speak |
| `/callout --list-voices` | Show all 54 voices |
| `/callout --config` | Show current settings |
| `/callout --stop` | Stop playback mid-speech |
| `/callout path/to/file.txt` | Read a file aloud |

### Stopping Playback

Two ways to cancel TTS mid-speech:
- **Start typing** your next message — the interrupt hook kills playback automatically
- **`/callout --stop`** — manual stop command

## Configuration

Set environment variables in `~/.claude/settings.json` under `env`:

| Variable | Default | Description |
|---|---|---|
| `CALLOUT_VOICE` | `af_heart` | Voice name (see `--list-voices`) |
| `CALLOUT_SPEED` | `1.0` | Speed multiplier (0.5–2.0) |
| `CALLOUT_ENGINE` | `auto` | `kokoro`, `say`, or `auto` |
| `CALLOUT_MAX_CHARS` | `5000` | Max characters to speak |
| `CALLOUT_AUDIO_DUCK` | `true` | Lower Apple Music during speech |
| `CALLOUT_DUCK_LEVEL` | `5` | Duck volume (% of original) |

## Available Voices

**American English** — Female: `af_alloy`, `af_aoede`, `af_bella`, `af_heart`, `af_jessica`, `af_kore`, `af_nicole`, `af_nova`, `af_river`, `af_sarah`, `af_sky` | Male: `am_adam`, `am_echo`, `am_eric`, `am_fenrir`, `am_liam`, `am_michael`, `am_onyx`, `am_puck`

**British English** — Female: `bf_alice`, `bf_emma`, `bf_isabella`, `bf_lily` | Male: `bm_daniel`, `bm_fable`, `bm_george`, `bm_lewis`

**Other** — French: `ff_siwis` | Italian: `if_sara`, `im_nicola` | Japanese: `jf_alpha`, `jf_gongitsune`, `jf_nezumi`, `jf_tebukuro`, `jm_kumo` | Mandarin: `zf_xiaobei`, `zf_xiaoni`, `zf_xiaoxiao`, `zf_xiaoyi`, `zm_yunjian`, `zm_yunxi`, `zm_yunxia`, `zm_yunyang`

## Architecture

```
callout/
├── .claude-plugin/
│   ├── plugin.json           # Plugin manifest + hooks
│   └── marketplace.json      # Local marketplace config
├── scripts/
│   ├── speak.sh              # Main TTS engine (kokoro → say fallback)
│   ├── cache-response.sh     # Stop hook: caches last response
│   ├── interrupt.sh          # Kills playback on new prompt
│   ├── cleanup.sh            # SessionEnd cleanup
│   ├── strip_markdown.py     # Markdown → plain text (mistune)
│   └── audio-duck.sh         # macOS Apple Music ducking
├── settings.json             # Default env config
├── install.sh                # One-command setup
├── uninstall.sh              # Clean removal
├── pyproject.toml            # Python deps
└── LICENSE                   # Apache 2.0
```

**How it works:**
1. **Stop hook** caches every Claude response to `/tmp/callout-{session_id}-response.txt`
2. **`/callout`** reads the session-scoped cache, strips markdown, pipes to Kokoro TTS streaming
3. **UserPromptSubmit hook** kills only the current session's TTS process (via PID tracking)
4. **SessionEnd hook** cleans up only the current session's temp files

Each session is isolated — running multiple Claude Code instances won't cross-talk. The `/callout` skill is a minimal SKILL.md that delegates all logic to `speak.sh` via `${CLAUDE_SESSION_ID}`, keeping Claude's processing fast.

## Prerequisites

- [Claude Code](https://claude.ai/code)
- [uv](https://astral.sh/uv) (for kokoro-tts and Python deps)
- [jq](https://jqlang.github.io/jq/) (usually pre-installed on macOS)
- macOS (for `say` fallback and audio ducking)

## Uninstall

```bash
./uninstall.sh
```

Interactively removes:
- `/callout` skill from `~/.claude/skills/`
- Plugin registration and marketplace from Claude Code
- Plugin cache from `~/.claude/plugins/cache/`
- Temp files and logs
- (Optional) Model files from `~/.local/share/kokoro-tts/` (~335MB)
- (Optional) `kokoro-tts` CLI tool

## Credits

- [Kokoro TTS](https://github.com/hexgrad/kokoro) — 82M param open-source TTS model (Apache 2.0)
- [kokoro-tts CLI](https://github.com/nazdridoy/kokoro-tts) — CLI wrapper with streaming
- [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx) — ONNX runtime + model files
- [ktaletsk/claude-code-tts](https://github.com/ktaletsk/claude-code-tts) — reference implementation

## License

Apache 2.0
