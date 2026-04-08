# Callout — Text-to-Speech for Claude Code

Speak Claude Code responses aloud using [Kokoro TTS](https://github.com/hexgrad/kokoro) (local, 82M params, #1 on TTS Arena) with macOS `say` as fallback.

## Features

- `/callout` — speak the last response on demand
- `/callout Hello world` — speak custom text
- `/callout --auto-on` — automatically speak every response
- 54 voices (American, British, French, Italian, Japanese, Mandarin)
- Configurable voice, speed, and engine
- Audio ducking (lowers Apple Music while speaking)
- Smart interruption (stops playback when you type)
- Markdown stripping for clean speech output

## Quick Start

```bash
git clone https://github.com/xicv/callout.git
cd callout
./install.sh
```

The installer handles everything:
1. Installs `kokoro-tts` via `uv`
2. Downloads model files (~335MB)
3. Registers the plugin hooks with Claude Code
4. Creates the `/callout` skill
5. Lets you pick your default voice

Then restart Claude Code and use `/callout`.

## Usage

| Command | Description |
|---|---|
| `/callout` | Speak the last response |
| `/callout Hello world` | Speak custom text |
| `/callout --voice=bf_emma` | Use a specific voice |
| `/callout --speed=1.5` | Faster speech |
| `/callout --auto-on` | Auto-speak every response |
| `/callout --auto-off` | Disable auto-speak |
| `/callout --list-voices` | Show all 54 voices |
| `/callout --config` | Show current settings |
| `/callout --stop` | Stop playback |

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
1. **Stop hook** caches every Claude response to `/tmp/callout-last-response.txt`
2. **`/callout`** reads the cache, strips markdown, pipes to Kokoro TTS
3. **UserPromptSubmit hook** kills any playing audio when you type
4. **SessionEnd hook** cleans up temp files

## Prerequisites

- [Claude Code](https://claude.ai/code)
- [uv](https://astral.sh/uv) (for kokoro-tts installation)
- [jq](https://jqlang.github.io/jq/) (usually pre-installed on macOS)
- macOS (for `say` fallback and audio ducking)

## Uninstall

```bash
./uninstall.sh
```

Interactively removes the skill, plugin registration, cache, temp files, and optionally the model files (~335MB) and kokoro-tts CLI.

## Credits

- [Kokoro TTS](https://github.com/hexgrad/kokoro) — 82M param open-source TTS model (Apache 2.0)
- [kokoro-tts CLI](https://github.com/nazdridoy/kokoro-tts) — CLI wrapper
- [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx) — ONNX runtime + model files

## License

Apache 2.0
