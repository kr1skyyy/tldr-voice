#!/usr/bin/env bash
# Install Piper TTS and download a voice for tldr-voice.
# Usage: setup.sh [voice-name]   (default en_US-hfc_female-medium)
# Voices: https://huggingface.co/rhasspy/piper-voices
set -euo pipefail

voice="${1:-${TLDR_VOICE:-en_US-hfc_female-medium}}"
voice_dir="${TLDR_VOICE_DIR:-$HOME/.local/share/piper-voices}"

if command -v piper >/dev/null || [[ -x "$HOME/.local/bin/piper" ]]; then
  echo "Piper already installed."
elif command -v uv >/dev/null; then
  uv tool install piper-tts
elif command -v pipx >/dev/null; then
  pipx install piper-tts
else
  echo "Need uv or pipx to install Piper. Install uv: https://docs.astral.sh/uv/" >&2
  exit 1
fi

mkdir -p "$voice_dir"
if [[ -f "$voice_dir/$voice.onnx" ]]; then
  echo "Voice $voice already downloaded."
else
  echo "Downloading voice $voice (~60 MB)..."
  if command -v uv >/dev/null; then
    uv tool run --from piper-tts python -m piper.download_voices "$voice" --data-dir "$voice_dir"
  else
    "$(pipx environment --value PIPX_LOCAL_VENVS)/piper-tts/bin/python" -m piper.download_voices "$voice" --data-dir "$voice_dir"
  fi
fi

"$(dirname "$0")/speak.sh" "Voice summaries are ready."
echo "Done. You should hear a test sentence."
