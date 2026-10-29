#!/usr/bin/env bash
# Install Piper TTS and download a voice for tldr-voice.
# Usage: setup.sh [voice-name]   (default en_US-hfc_female-medium)
# Uses uv or pipx when present, else a private Python venv. No sudo needed.
# Voices: https://huggingface.co/rhasspy/piper-voices
set -euo pipefail

voice="${1:-${TLDR_VOICE:-en_US-hfc_female-medium}}"
voice_dir="${TLDR_VOICE_DIR:-$HOME/.local/share/piper-voices}"
data_dir="${TLDR_DATA_DIR:-$HOME/.local/share/tldr-voice}"
venv="$data_dir/venv"

# Python that can run "python -m piper"
piper_python() {
  local bin
  if [[ -x "$venv/bin/python" ]] && "$venv/bin/python" -c 'import piper' 2>/dev/null; then
    echo "$venv/bin/python"; return
  fi
  bin="$(command -v piper || echo "$HOME/.local/bin/piper")"
  if [[ -x "$bin" ]]; then
    # piper's console script starts with a shebang to its own interpreter
    head -n 1 "$bin" | sed -n 's/^#!//p'
  fi
}

if [[ -n "$(piper_python)" ]]; then
  echo "Piper already installed."
elif command -v uv >/dev/null; then
  uv tool install piper-tts
elif command -v pipx >/dev/null; then
  pipx install piper-tts
elif command -v python3 >/dev/null; then
  echo "Installing Piper in $venv ..."
  mkdir -p "$data_dir"
  python3 -m venv "$venv" || {
    echo "python3 venv failed. On Debian/Ubuntu: sudo apt install python3-venv" >&2; exit 1; }
  "$venv/bin/pip" install --quiet --upgrade pip
  "$venv/bin/pip" install --quiet piper-tts
else
  echo "Need python3 to install Piper." >&2
  exit 1
fi

py="$(piper_python)"
[[ -z "$py" ]] && { echo "Piper install failed." >&2; exit 1; }

mkdir -p "$voice_dir"
if [[ -f "$voice_dir/$voice.onnx" ]]; then
  echo "Voice $voice already downloaded."
else
  echo "Downloading voice $voice (~60 MB)..."
  "$py" -m piper.download_voices "$voice" --data-dir "$voice_dir"
fi

"$(dirname "$0")/speak.sh" "Voice summaries are ready."
echo "Done. You should hear a test sentence."
