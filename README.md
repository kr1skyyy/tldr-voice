# tldr-voice

Spoken TL;DR for Claude Code. After a long reply, Claude says a 2-3 sentence summary out loud and shows it as a `🔊 TL;DR:` line, so you don't have to read the whole wall of text.

- **Fully local.** Uses [Piper](https://github.com/OHF-Voice/piper1-gpl) TTS on your CPU. No API calls, no extra model costs.
- **Only when needed.** Short replies stay silent. Long replies (150+ words or 15+ lines) get a summary.
- **Never reads the long reply.** Claude writes a new summary for listening. The script cuts anything past 3 sentences.
- **Multi-session aware.** If you run Claude in several projects at once, it says the project name first.

## Install

In Claude Code:

```
/plugin marketplace add OWNER/claude-tldr-voice
/plugin install tldr-voice@tldr-voice
```

Then install Piper and the default voice (~60 MB). Needs [uv](https://docs.astral.sh/uv/) or pipx:

```bash
~/.claude/plugins/cache/tldr-voice/tldr-voice/*/scripts/setup.sh
```

Or just ask Claude: "set up tldr-voice".

Restart Claude Code. Ask something with a long answer. You should hear the summary.

## Requirements

- Linux or macOS
- Python 3 (for the hook)
- `uv` or `pipx` (to install Piper)
- Audio player: `pw-play`, `paplay`, `aplay` (Linux) or `afplay` (macOS)

Without Piper, it falls back to `say` (macOS) or `spd-say` (Linux).

## Settings

Set these env vars in your shell profile:

| Variable | Default | What it does |
|---|---|---|
| `TLDR_MUTE` | `0` | `1` turns the voice off |
| `TLDR_VOICE` | `en_US-hfc_female-medium` | Piper voice name |
| `TLDR_VOICE_DIR` | `~/.local/share/piper-voices` | Where voices live |
| `TLDR_SAY_PROJECT` | `auto` | `auto`, `always`, or `never` say the project name |
| `TLDR_MIN_WORDS` | `150` | Reply words that trigger a summary |
| `TLDR_MIN_LINES` | `15` | Reply lines that trigger a summary |

Other voices: browse [piper-voices](https://huggingface.co/rhasspy/piper-voices), then run `scripts/setup.sh <voice-name>` and set `TLDR_VOICE`.

## How it works

1. `hooks/hooks.json` registers a **Stop hook** (`scripts/stop-hook.py`). It runs after every reply.
2. If the reply is long, the hook asks Claude for one more step: write a short summary for listening.
3. Claude runs `scripts/speak.sh "<summary>"`. Piper makes the audio, which plays in the background.
4. Claude shows the same summary as a `🔊 TL;DR:` line.

The hook runs only once per reply, so it cannot loop.

## Uninstall

```
/plugin uninstall tldr-voice@tldr-voice
```

## License

MIT
