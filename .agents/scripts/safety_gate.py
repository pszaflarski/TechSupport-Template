#!/usr/bin/env python3
"""PreToolUse safety gate blocking destructive commands and interactive sudo."""

import json
import os
import re
import sys

BANNED_PATTERNS = [
    re.compile(
        r"\b(mkfs(\.[a-z0-9]+)?|fdisk|sfdisk|cfdisk|parted|gdisk|wipefs|diskpart|format\.com)\b",
        re.IGNORECASE,
    ),
    re.compile(r"\bdd\s+[^;|&\n]*of=/dev/(sd|nvme|mmcblk|vd|hd)", re.IGNORECASE),
    re.compile(
        r"\b(update-grub|grub-install|grub-mkconfig|bcdedit|bootrec)\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[a-zA-Z]*\s+/(?:\s|$|\*|(?:bin|boot|dev|etc|lib|lib64|opt|proc|root|run|sbin|sys|usr|var)(?:/|\s|$))",
        re.IGNORECASE,
    ),
    re.compile(
        r"\b(rd|rmdir)\s+/s\s+/q\s+c:\\(windows|users|program files)\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\bsystemctl\s+(stop|disable|mask)\s+(ssh|sshd|tailscaled|ufw|firewalld)\b",
        re.IGNORECASE,
    ),
    re.compile(r"\btailscale\s+(down|logout)\b", re.IGNORECASE),
    re.compile(r"\bufw\s+disable\b", re.IGNORECASE),
    re.compile(
        r"\bnetsh\s+advfirewall\s+set\s+\S+\s+state\s+off\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"Set-MpPreference\s+[^;|&\n]*-DisableRealtimeMonitoring\s+\$?true",
        re.IGNORECASE,
    ),
]

INTERACTIVE_SUDO_PATTERN = re.compile(
    r"(?:^|\n|&&|\|\||;|\||\$\(|`)\s*sudo(?:\s+(?!-n\b|--non-interactive\b)|$)",
    re.IGNORECASE,
)


def emit(decision: str, reason: str = "") -> None:
    payload = {"decision": decision}
    if reason:
        payload["reason"] = reason
    sys.stdout.write(json.dumps(payload) + "\n")


def contains_banned_op(text: str) -> bool:
    if not text:
        return False
    return any(pattern.search(text) for pattern in BANNED_PATTERNS)


def main() -> int:
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        emit("allow")
        return 0

    tool_call = data.get("toolCall") or {}
    tool_name = str(tool_call.get("name") or "").lower()
    args = tool_call.get("args") or {}

    if tool_name == "run_command":
        cmd = str(args.get("CommandLine") or args.get("commandLine") or "")
        if contains_banned_op(cmd):
            emit(
                "deny",
                "Blocked by TechSupport safety gate: destructive or security-disabling operation is prohibited.",
            )
            return 0
        if INTERACTIVE_SUDO_PATTERN.search(cmd):
            emit(
                "deny",
                "Interactive sudo is blocked. Follow the PRIVILEGE ESCALATION PROTOCOL in AGENTS.md (write temp_fix.sh and create the Fix Issue banana desktop shortcut with pkexec).",
            )
            return 0

    elif tool_name in ("write_file", "edit_file"):
        target_path = str(args.get("Path") or args.get("path") or "")
        basename = os.path.basename(target_path.replace("\\", "/")).lower()
        if basename.startswith("temp_fix."):
            content = str(
                args.get("Content")
                or args.get("content")
                or args.get("Replacement")
                or args.get("replacement")
                or ""
            )
            if contains_banned_op(content):
                emit(
                    "deny",
                    "Blocked by TechSupport safety gate: destructive or security-disabling operation in temp_fix script is prohibited.",
                )
                return 0

    emit("allow")
    return 0


if __name__ == "__main__":
    sys.exit(main())
