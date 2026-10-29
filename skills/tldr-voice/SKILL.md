---
name: tldr-voice
description: >-
  Speak a 2-3 sentence spoken summary of a long response aloud using local
  Piper TTS, so the user does not have to read a wall of text. A Stop hook
  triggers it automatically after long replies. Use it yourself ONLY when the
  user explicitly asks ("say it", "read me the summary", "tldr out loud",
  /tldr-voice), or asks to set up, test, mute, or change the voice.
---

# TL;DR Voice

After a long text reply, speak an EXTRA short audio summary of it. Runs fully local (Piper TTS). No API calls.

The long reply is never spoken. It stays as normal text. The voice only says a new, separate 2-3 sentence summary written for listening. Never pass the reply text (or any part of it) to the script. The script also cuts anything past 3 sentences / 70 words.

When a stop hook tells you to run a command, run that command once. Do not also pick the other platform's script.

## When to use

A Stop hook triggers this automatically after long replies (150+ words or 15+ lines in Claude Code, 80+ words or 8+ lines in Cursor). When it fires, follow its instruction: run the speak script once, then write the same summary as one text line.

On Claude Code the line starts with `🔊 TL;DR:`. On Cursor it starts with `TL;DR:`.

Do NOT call it on your own otherwise, or the user hears it twice. Only exception: the user explicitly asks ("say it", "read it to me", `/tldr-voice`). Then speak a summary of the last long reply.

Skip if the user said "mute", "quiet", "no voice", or `TLDR_MUTE=1` is set.

## Claude Code (Linux and macOS)

Scripts live in this plugin's `scripts/` folder, two levels up from this skill's base directory: `<skill base dir>/../../scripts/`.

A SessionStart hook installs Piper and the voice in the background on first start (log: `~/.local/share/tldr-voice/setup.log`). If speak.sh still prints "Piper or voice ... not found", run `scripts/setup.sh`. Pass a voice name to get another voice: `scripts/setup.sh en_GB-alan-medium`.

```bash
<plugin>/scripts/speak.sh "I fixed the login bug and all tests pass. You need to restart the server to see the change."
```

## Cursor on Windows

Run Windows PowerShell. Put the summary in straight double quotes. Avoid `"` and `$` inside it.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin>\scripts\speak.ps1" "I fixed the login bug and all tests pass. Restart the server to see the change."
```

Resolve the script in this order:

1. The path in the hook message.
2. `scripts/speak.ps1` in the current workspace, if that file exists.
3. `%USERPROFILE%\.cursor\plugins\local\tldr-voice\scripts\speak.ps1`

If speak.ps1 says Piper is not installed, run `scripts/setup.ps1`. Create or delete `%LOCALAPPDATA%\tldr-voice\muted` to mute or unmute without restarting Cursor.

## Writing the spoken summary

- 2 sentences. 3 max. Under ~60 words.
- Say: what was done, did it work, what the user must do next (if anything).
- Plain speech. No markdown, no code, no file paths, no URLs, no emoji, no bullet symbols.
- Spell out symbols: say "version two" not "v2", "and" not "&".
- Name things by meaning, not by path: "the config file" not "~/.config/app/settings.json".
- Use straight double quotes around the argument. Escape any `"` or `$` inside, or avoid them.
- Do not add the project name. The script adds it when needed.

## Settings (env vars)

- `TLDR_MUTE=1` turns voice off.
- `TLDR_VOICE` picks another Piper voice (default `en_US-hfc_female-medium`).
- `TLDR_VOICE_DIR` voice folder. Claude default: `~/.local/share/piper-voices`. Cursor default: `%LOCALAPPDATA%\tldr-voice\voices`.
- `TLDR_SAY_PROJECT` = `auto` (say the project name when more than one project is active), `always`, or `never`.
- `TLDR_MIN_WORDS` / `TLDR_MIN_LINES` reply size that triggers the hook (default 150 / 15).
