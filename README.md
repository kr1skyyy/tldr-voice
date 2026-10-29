# tldr-voice

Spoken TL;DR for Claude Code and Cursor. After a long reply, the agent says a 2-3 sentence summary out loud and shows it as a TL;DR line, so you don't have to read the whole wall of text.

- **Fully local.** Uses [Piper](https://github.com/OHF-Voice/piper1-gpl) TTS on your CPU. No API calls, no extra model costs.
- **Only when needed.** Short replies stay silent. Longer replies get a summary: 150+ words or 15+ lines in Claude Code, 80+ words or 8+ lines in Cursor.
- **Never reads the long reply.** The agent writes a new summary for listening. The script cuts anything past 3 sentences.
- **Multi-session aware.** If more than one project is active, it says the project name first.

## Claude Code (Linux and macOS)

```
/plugin marketplace add kr1skyyy/tldr-voice
/plugin install tldr-voice@tldr-voice
```

On the next start, the plugin installs Piper and the default voice (~60 MB) in the background. You hear "Voice summaries are ready." when it is done. It uses `uv` or `pipx` if you have them, else a private Python venv in `~/.local/share/tldr-voice`. No sudo needed. Log: `~/.local/share/tldr-voice/setup.log`.

To skip auto-install, set `TLDR_AUTO_SETUP=0` and run `scripts/setup.sh` yourself.

Then ask something with a long answer. You should hear the summary.

### Requirements

- Linux or macOS
- Python 3 (for the hook)
- Python 3 with `venv` (on Debian/Ubuntu: `sudo apt install python3-venv`), or `uv`/`pipx`
- Audio player: `pw-play`, `paplay`, `aplay` (Linux) or `afplay` (macOS)

Without Piper, it falls back to `say` (macOS) or `spd-say` (Linux).

### Uninstall

```
/plugin uninstall tldr-voice@tldr-voice
```

## Cursor (Windows)

Cursor hooks live in `hooks/cursor.json` and `.cursor/hooks.json`. The Claude hook file `hooks/hooks.json` is unchanged.

Project hooks in `.cursor/hooks.json` run while this workspace is open. To use it in every project, link the folder into Cursor's local plugins and reload Cursor:

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.cursor\plugins\local\tldr-voice" -Target (Resolve-Path .).Path
```

Run that from this repository.

On the next agent chat, Piper and the default voice install in the background. You hear "Voice summaries are ready." when that finishes. Log: `%LOCALAPPDATA%\tldr-voice\setup.log`. Until Piper is ready, Windows speech speaks instead.

To skip auto-install, set `TLDR_AUTO_SETUP=0` and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

Then ask something with a long answer. After the reply, Cursor runs one short follow-up that speaks the summary and prints `TL;DR:`.

### Requirements

- Windows 10 or later
- Cursor
- PowerShell 5.1 (included with Windows)
- Python 3 from [python.org](https://www.python.org/downloads/) with the `py` launcher on PATH

Set user environment variables in Windows, then restart Cursor. A PowerShell profile is not loaded for hooks.

Mute without restarting Cursor by creating `%LOCALAPPDATA%\tldr-voice\muted`. Delete that file to unmute.

### Uninstall

Remove `%USERPROFILE%\.cursor\plugins\local\tldr-voice`, then reload Cursor. Delete `%LOCALAPPDATA%\tldr-voice` to remove the Windows voice and Piper install.

## Settings

Set these env vars in your shell profile (Claude) or as Windows user environment variables (Cursor):

| Variable | Default | What it does |
|---|---|---|
| `TLDR_MUTE` | `0` | `1` turns the voice off |
| `TLDR_VOICE` | `en_US-hfc_female-medium` | Piper voice name |
| `TLDR_VOICE_DIR` | Claude: `~/.local/share/piper-voices`. Cursor: `%LOCALAPPDATA%\tldr-voice\voices` | Where voices live |
| `TLDR_DATA_DIR` | Claude: `~/.local/share/tldr-voice`. Cursor: `%LOCALAPPDATA%\tldr-voice` | Install, logs, and the Windows mute flag |
| `TLDR_SAY_PROJECT` | `auto` | `auto`, `always`, or `never` say the project name |
| `TLDR_MIN_WORDS` | `80` on Cursor, `150` on Claude Code | Reply words that trigger a summary |
| `TLDR_MIN_LINES` | `8` on Cursor, `15` on Claude Code | Reply lines that trigger a summary |
| `TLDR_AUTO_SETUP` | `1` | `0` turns off auto-install of Piper |

Other voices: browse [piper-voices](https://huggingface.co/rhasspy/piper-voices), then run `scripts/setup.sh <voice-name>` or `scripts/setup.ps1 <voice-name>` and set `TLDR_VOICE`.

## How it works

Claude Code:

1. A **SessionStart** hook (`scripts/ensure-setup.sh`) installs Piper and the voice if missing.
2. `hooks/hooks.json` registers a **Stop** hook (`scripts/stop-hook.py`). It runs after every reply.
3. If the reply is long, the hook asks Claude for one more step: write a short summary for listening.
4. Claude runs `scripts/speak.sh "<summary>"`. Piper makes the audio, which plays in the background.
5. Claude shows the same summary as a `🔊 TL;DR:` line.

Cursor on Windows:

1. A **sessionStart** hook (`scripts/ensure-setup.ps1`) installs Piper and the voice if missing.
2. **afterAgentResponse** stores the reply text. **beforeSubmitPrompt** clears it for the next turn.
3. The **stop** hook (`scripts/hook.py`) runs when the agent finishes. A long reply produces one follow-up.
4. Cursor runs `scripts/speak.ps1 "<summary>"`. Piper writes a WAV and Windows plays it. Windows speech is the fallback.
5. Cursor shows the same summary as a `TL;DR:` line.

The hook runs only once per reply, so it cannot loop.

## License

MIT
