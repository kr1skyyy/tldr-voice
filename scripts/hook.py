#!/usr/bin/env python3
"""Cursor hooks for spoken TL;DR summaries on Windows.

beforeSubmitPrompt clears the current turn.
afterAgentResponse appends assistant text.
stop asks Cursor for one follow-up when that turn was long.
"""
import json
import os
import sys
import time

MIN_WORDS = int(os.environ.get("TLDR_MIN_WORDS", "80"))
MIN_LINES = int(os.environ.get("TLDR_MIN_LINES", "8"))
TEXT_TYPES = {"text", "output_text"}


def data_dir():
    override = os.environ.get("TLDR_DATA_DIR")
    if override:
        path = override
    else:
        local = os.environ.get("LOCALAPPDATA")
        if local:
            path = os.path.join(local, "tldr-voice")
        else:
            path = os.path.join(os.path.expanduser("~"), ".local", "share", "tldr-voice")
    os.makedirs(path, exist_ok=True)
    return path


def muted():
    if os.environ.get("TLDR_MUTE") == "1":
        return True
    return os.path.isfile(os.path.join(data_dir(), "muted"))


def conversation_id(data):
    raw = str(data.get("conversation_id") or data.get("session_id") or "default")
    safe = "".join(ch for ch in raw if ch.isalnum() or ch in "-_")
    return safe or "default"


def turn_path(data):
    folder = os.path.join(data_dir(), "turns")
    os.makedirs(folder, exist_ok=True)
    return os.path.join(folder, conversation_id(data) + ".txt")


def read_turn(data):
    path = turn_path(data)
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def write_turn(data, text):
    path = turn_path(data)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def append_turn(data, text):
    text = (text or "").strip()
    if not text:
        return
    lock = turn_path(data) + ".lock"
    deadline = time.time() + 2
    while True:
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_RDWR)
            break
        except FileExistsError:
            if time.time() > deadline:
                try:
                    os.remove(lock)
                except OSError:
                    return
                continue
            time.sleep(0.02)
    try:
        existing = read_turn(data)
        if existing.rstrip().endswith(text):
            return
        if existing and not existing.endswith("\n"):
            existing += "\n"
        write_turn(data, existing + text + "\n")
    finally:
        os.close(fd)
        try:
            os.remove(lock)
        except OSError:
            return


def clear_turn(data):
    try:
        os.remove(turn_path(data))
    except OSError:
        return


def load_input():
    raw = sys.stdin.buffer.read()
    if not raw or not raw.strip(b" \t\r\n\x00"):
        return {}
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        text = raw.decode("utf-16")
    elif len(raw) > 3 and raw[1] == 0 and raw[3] == 0:
        text = raw.decode("utf-16-le")
    else:
        text = raw.decode("utf-8-sig")
    return json.loads(text.strip().lstrip("\ufeff"))


def emit(payload):
    encoded = json.dumps(payload, ensure_ascii=True).encode("ascii")
    sys.stdout.buffer.write(encoded + b"\n")


def content_blocks(entry):
    message = entry.get("message") or {}
    content = message.get("content")
    if content is None:
        content = entry.get("content")
    return content


def text_from_content(content):
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts = []
    for block in content:
        if isinstance(block, str):
            parts.append(block)
        elif isinstance(block, dict) and block.get("type") in TEXT_TYPES:
            parts.append(block.get("text") or "")
    return "\n".join(part for part in parts if part)


def is_user(entry):
    return (entry.get("role") or entry.get("type")) == "user"


def is_assistant(entry):
    return (entry.get("role") or entry.get("type")) == "assistant"


def is_tool_result_only(entry):
    content = content_blocks(entry)
    if not isinstance(content, list) or not content:
        return False
    types = [block.get("type") for block in content if isinstance(block, dict)]
    return bool(types) and "tool_result" in types and all(
        item in ("tool_result", "tool_use") for item in types
    )


def last_reply_from_transcript(path):
    if not path:
        return ""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.readlines()
    except OSError:
        return ""
    texts = []
    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if is_user(entry) and not is_tool_result_only(entry):
            break
        if is_assistant(entry):
            text = text_from_content(content_blocks(entry))
            if text:
                texts.append(text)
    return "\n".join(reversed(texts))


def is_long(reply):
    words = reply.split()
    lines = [line for line in reply.splitlines() if line.strip()]
    return len(words) >= MIN_WORDS or len(lines) >= MIN_LINES


def speak_command():
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "speak.ps1")
    quoted = script.replace("'", "''")
    return (
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File "
        "'%s' \"<summary>\"" % quoted
    )


def follow_up():
    return (
        "tldr-voice: your reply was long. Run this ONE command, then stop:\n"
        "%s\n"
        "Replace <summary> with NEW text for listening: 2 sentences, 3 max, under 60 words. "
        "Say what was done, whether it worked, and what the user must do next. "
        "No markdown, code, paths, URLs, or symbols. Do not include the project name. "
        "Do not repeat the reply. Use straight double quotes around the summary.\n"
        "After the command, write only that same summary as one text line starting with: "
        "TL;DR: "
    ) % speak_command()


def handle_stop(data):
    if muted():
        return
    status = data.get("status")
    if status in ("aborted", "error"):
        return
    if data.get("stop_hook_active"):
        return
    try:
        loop_count = int(data.get("loop_count") or 0)
    except (TypeError, ValueError):
        loop_count = 0
    if loop_count > 0:
        return
    captured = read_turn(data)
    transcript = data.get("last_assistant_message") or last_reply_from_transcript(
        data.get("transcript_path") or os.environ.get("CURSOR_TRANSCRIPT_PATH") or ""
    )
    reply = captured if len(captured.split()) >= len((transcript or "").split()) else transcript
    if not reply or not is_long(reply):
        return
    emit({"followup_message": follow_up()})


def run():
    data = load_input()
    event = data.get("hook_event_name") or ""
    if event == "beforeSubmitPrompt":
        clear_turn(data)
        emit({"continue": True})
        return
    if event == "afterAgentResponse":
        append_turn(data, data.get("text") or "")
        return
    if event in ("stop", "Stop", ""):
        handle_stop(data)


def main():
    try:
        run()
    except Exception as exc:
        sys.stderr.write("tldr-voice: %s\n" % exc)


if __name__ == "__main__":
    main()
