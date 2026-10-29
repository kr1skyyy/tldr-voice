#!/usr/bin/env python3
"""Claude Code Stop hook: after a long reply, ask Claude to speak a short summary.

Short replies pass through. Long ones get one follow-up step where Claude runs
speak.sh with a fresh 2-3 sentence summary. Env: TLDR_MUTE=1, TLDR_MIN_WORDS.
"""
import json
import os
import sys

SPEAK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "speak.sh")
MIN_WORDS = int(os.environ.get("TLDR_MIN_WORDS", "150"))
MIN_LINES = int(os.environ.get("TLDR_MIN_LINES", "15"))


def last_reply_from_transcript(path):
    """Assistant text written since the last real user prompt."""
    texts = []
    try:
        with open(path) as f:
            lines = f.readlines()
    except OSError:
        return ""
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        msg = entry.get("message") or {}
        content = msg.get("content")
        if entry.get("type") == "user":
            is_tool_result = isinstance(content, list) and any(
                isinstance(c, dict) and c.get("type") == "tool_result" for c in content
            )
            if not is_tool_result:
                break
        elif entry.get("type") == "assistant" and isinstance(content, list):
            for c in content:
                if isinstance(c, dict) and c.get("type") == "text":
                    texts.append(c.get("text", ""))
    return "\n".join(reversed(texts))


def main():
    if os.environ.get("TLDR_MUTE") == "1":
        return
    data = json.load(sys.stdin)
    # Second stop after Claude spoke the summary: let it end
    if data.get("stop_hook_active"):
        return
    reply = data.get("last_assistant_message") or last_reply_from_transcript(
        data.get("transcript_path", "")
    )
    lines = [l for l in reply.splitlines() if l.strip()]
    if len(reply.split()) < MIN_WORDS and len(lines) < MIN_LINES:
        return
    print(json.dumps({
        "decision": "block",
        "reason": (
            "tldr-voice: your reply was long. Run this ONE Bash command:\n"
            f'{SPEAK} "<summary>"\n'
            "After it, write only the same summary as text, on one line starting with: 🔊 TL;DR: \n"
            "The summary is NEW text for listening: 2 sentences (3 max), under 60 words, "
            "what was done, did it work, what the user must do next. No markdown, code, "
            "paths, URLs or symbols. Do not include the project name. Do not repeat the reply."
        ),
    }))


if __name__ == "__main__":
    main()
