---
name: tldr-voice
description: Speak a 2-3 sentence spoken summary of a long response aloud using local Piper TTS, so the user does not have to read a wall of text. A Stop hook triggers it automatically after long replies. Use it yourself ONLY when the user explicitly asks ("say it", "read me the summary", "tldr out loud", /tldr-voice), or asks to set up, test, mute, or change the voice.
---

# TL;DR Voice

After a long text reply, speak an EXTRA short audio summary of it. Runs fully local (Piper TTS). No API calls.

The long reply is never spoken. It stays as normal text. The voice only says a new, separate 2-3 sentence summary written for listening. Never pass the reply text (or any part of it) to the script. The script also cuts anything past 3 sentences / 70 words.

Scripts live in this plugin's `scripts/` folder, two levels up from this skill's base directory: `<skill base dir>/../../scripts/`.

## When to use

A Stop hook (`scripts/stop-hook.py`) triggers this automatically after long replies (150+ words or 15+ lines). When it fires, follow its instruction: run speak.sh once, then write the same summary as one text line starting with `🔊 TL;DR:`.

Do NOT call it on your own otherwise, or the user hears it twice. Only exception: the user explicitly asks ("say it", "read it to me", `/tldr-voice`). Then speak a summary of the last long reply.

Skip if the user said "mute", "quiet", "no voice", or `TLDR_MUTE=1` is set.

## First-time setup

If speak.sh prints "Piper or voice ... not found", run `scripts/setup.sh`. It installs Piper with `uv` (or `pipx`) and downloads the default voice (~60 MB). Pass a voice name to get another voice: `scripts/setup.sh en_GB-alan-medium`.

## Writing the spoken summary

- 2 sentences. 3 max. Under ~60 words.
- Say: what was done, did it work, what the user must do next (if anything).
- Plain speech. No markdown, no code, no file paths, no URLs, no emoji, no bullet symbols.
- Spell out symbols: say "version two" not "v2", "and" not "&".
- Name things by meaning, not by path: "the config file" not "~/.config/app/settings.json".
- Use straight double quotes around the argument. Escape any `"` or `$` inside, or avoid them.
- Do not add the project name. The script adds it when needed.

Example:

```bash
<plugin>/scripts/speak.sh "I fixed the login bug and all tests pass. You need to restart the server to see the change."
```

## Settings (env vars)

- `TLDR_MUTE=1` turns voice off.
- `TLDR_VOICE` picks another Piper voice (default `en_US-hfc_female-medium`).
- `TLDR_VOICE_DIR` voice folder (default `~/.local/share/piper-voices`).
- `TLDR_SAY_PROJECT` = `auto` (default: say "Project <name>." first when Claude sessions run in 2+ different project folders), `always`, or `never`.
- `TLDR_MIN_WORDS` / `TLDR_MIN_LINES` reply size that triggers the hook (default 150 / 15).
