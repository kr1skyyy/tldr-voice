#!/usr/bin/env bash
# SessionStart hook: if Piper or the voice is missing, run setup.sh once in the background.
# Disable with TLDR_AUTO_SETUP=0. Log: ~/.local/share/tldr-voice/setup.log
set -uo pipefail

[[ "${TLDR_AUTO_SETUP:-1}" == "0" ]] && exit 0

here="$(cd "$(dirname "$0")" && pwd)"
voice="${TLDR_VOICE:-en_US-hfc_female-medium}"
voice_dir="${TLDR_VOICE_DIR:-$HOME/.local/share/piper-voices}"
data_dir="${TLDR_DATA_DIR:-$HOME/.local/share/tldr-voice}"

has_piper() {
  command -v piper >/dev/null || [[ -x "$HOME/.local/bin/piper" || -x "$data_dir/venv/bin/piper" ]]
}

has_piper && [[ -f "$voice_dir/$voice.onnx" ]] && exit 0

mkdir -p "$data_dir"
# Skip if another session is already installing
exec 9>"$data_dir/setup.lock"
flock -n 9 2>/dev/null || { command -v flock >/dev/null && exit 0; }

# Background setup keeps fd 9 open, so the lock holds until it finishes
nohup "$here/setup.sh" >"$data_dir/setup.log" 2>&1 </dev/null &
echo "tldr-voice: installing Piper voice in the background (log: $data_dir/setup.log)."
exit 0
