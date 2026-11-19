#!/usr/bin/env python3
"""Stop hook exporting readable conversation logs to TechSupport/logs/."""

import datetime
import json
import re
import sys
from pathlib import Path

USER_REQ_RE = re.compile(r"<USER_REQUEST>\s*(.*?)\s*</USER_REQUEST>", re.DOTALL)


def extract_user_text(raw: str) -> str:
    match = USER_REQ_RE.search(raw)
    return (match.group(1) if match else raw).strip()


def main() -> int:
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
        transcript_str = data.get("transcriptPath") or ""
        conv_id = str(data.get("conversationId") or "unknown")
        if transcript_str:
            transcript_path = Path(transcript_str)
            full_path = transcript_path.with_name("transcript_full.jsonl")
            source_path = full_path if full_path.is_file() else transcript_path
            if source_path.is_file():
                entries = []
                with source_path.open("r", encoding="utf-8", errors="replace") as fh:
                    for line in fh:
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            step = json.loads(line)
                        except Exception:
                            continue
                        step_type = step.get("type")
                        content = step.get("content")
                        if not isinstance(content, str) or not content.strip():
                            continue
                        ts = step.get("created_at") or ""
                        if step_type == "USER_INPUT":
                            text = extract_user_text(content)
                            if text:
                                entries.append(f"[{ts}] USER: {text}")
                        elif step_type == "PLANNER_RESPONSE":
                            entries.append(f"[{ts}] ASSISTANT: {content.strip()}")

                if entries:
                    logs_dir = Path(__file__).resolve().parents[2] / "logs"
                    logs_dir.mkdir(parents=True, exist_ok=True)
                    date_str = datetime.date.today().strftime("%Y-%m-%d")
                    short_id = conv_id[:8] if conv_id else "session"
                    out_path = logs_dir / f"session_{date_str}_{short_id}.log"
                    header = f"=== TechSupport Session {conv_id} ===\n\n"
                    out_path.write_text(
                        header + "\n\n".join(entries) + "\n", encoding="utf-8"
                    )
    except Exception:
        pass

    sys.stdout.write(json.dumps({"decision": "allow"}) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
