#!/usr/bin/env bash
# Speak text aloud with local Piper TTS. Returns immediately; audio plays in background.
# Usage: speak.sh "Text to speak."
# Env: TLDR_VOICE (default en_US-hfc_female-medium), TLDR_VOICE_DIR, TLDR_MUTE=1 to disable,
#      TLDR_SAY_PROJECT=auto|always|never.
set -euo pipefail

[[ "${TLDR_MUTE:-0}" == "1" ]] && exit 0

text="${*:-}"
[[ -z "$text" ]] && { echo "usage: speak.sh \"text\"" >&2; exit 1; }

# Hard cap: never speak more than 3 sentences / 70 words, even if given a long reply
text="$(printf '%s' "$text" | tr '\n' ' ' | grep -oE '[^.!?]+[.!?]*' | head -n 3 | tr '\n' ' ')"
text="$(printf '%s' "$text" | awk '{n = NF > 70 ? 70 : NF; for (i = 1; i <= n; i++) printf "%s%s", $i, (i < n ? " " : ""); }')"

voice="${TLDR_VOICE:-en_US-hfc_female-medium}"
voice_dir="${TLDR_VOICE_DIR:-$HOME/.local/share/piper-voices}"
model="$voice_dir/$voice.onnx"
piper_bin="$(command -v piper || echo "$HOME/.local/bin/piper")"
lock="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/tldr-voice-$(id -u).pid"

# Working folder of a process (Linux /proc, macOS lsof)
project_root() {
  if [[ -e "/proc/$1/cwd" ]]; then
    readlink "/proc/$1/cwd" 2>/dev/null || true
  elif command -v lsof >/dev/null; then
    lsof -a -d cwd -p "$1" -Fn 2>/dev/null | sed -n 's/^n//p' || true
  fi
}

# Say the project name first when Claude runs in more than one project at once
my_root="$(project_root "${CLAUDE_PID:-0}")"
[[ -z "$my_root" ]] && my_root="${CLAUDE_PROJECT_DIR:-$PWD}"
roots="$(for p in $(pgrep -x claude 2>/dev/null); do project_root "$p"; done | sort -u | grep -c . || true)"
say_project="${TLDR_SAY_PROJECT:-auto}"
if [[ "$say_project" == "always" ]] || { [[ "$say_project" == "auto" ]] && (( roots > 1 )); }; then
  if [[ "$my_root" == "$HOME" ]]; then name="home folder"; else name="$(basename "$my_root")"; fi
  name="${name//[-_.]/ }"
  text="Project ${name}. ${text}"
fi

# Stop previous summary if still talking
if [[ -f "$lock" ]]; then
  kill "$(cat "$lock")" 2>/dev/null || true
  rm -f "$lock"
fi

play_wav() {
  if command -v pw-play >/dev/null; then pw-play "$1"
  elif command -v paplay >/dev/null; then paplay "$1"
  elif command -v afplay >/dev/null; then afplay "$1"
  else aplay -q "$1"; fi
}

if [[ ! -x "$piper_bin" || ! -f "$model" ]]; then
  echo "tldr-voice: Piper or voice '$voice' not found. Run: $(dirname "$0")/setup.sh" >&2
fi

play() {
  local wav
  wav="$(mktemp "${TMPDIR:-/tmp}/tldr-voice.XXXXXX")"
  if [[ -x "$piper_bin" && -f "$model" ]]; then
    printf '%s' "$text" | "$piper_bin" -m "$model" -f "$wav" >/dev/null 2>&1
    play_wav "$wav"
  elif command -v say >/dev/null; then
    say "$text"
  elif command -v spd-say >/dev/null; then
    spd-say -w -- "$text"
  fi
  rm -f "$wav" "$lock"
}

play </dev/null >/dev/null 2>&1 &
echo $! > "$lock"
disown
