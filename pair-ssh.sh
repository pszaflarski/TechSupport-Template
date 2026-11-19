#!/usr/bin/env bash
set -euo pipefail

# Usage: ./pair-ssh.sh [remote_user] [tailscale_host_or_ip] [ssh_alias]

if ! command -v tailscale >/dev/null 2>&1 || ! tailscale status >/dev/null 2>&1; then
    echo "Tailscale does not appear to be connected on this machine."
    echo "Connect Tailscale first (e.g., 'tailscale status'), then re-run this script."
    exit 1
fi

REMOTE_USER="${1:-}"
TARGET_HOST="${2:-}"
SSH_ALIAS="${3:-sunshine-host}"

if [ -z "$TARGET_HOST" ]; then
    read -rp "Enter the remote host's Tailscale name or IP (e.g. gaming-pc or 100.x.y.z): " TARGET_HOST
fi
TARGET_HOST="$(printf '%s' "$TARGET_HOST" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [ -z "$TARGET_HOST" ]; then
    echo "Error: Remote host name or IP cannot be empty."
    exit 1
fi

# Resolve Tailscale IPv4 when given a Tailscale MagicDNS hostname so SSH bypasses local router DNS
RESOLVED_IP=""
if [[ ! "$TARGET_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "$TARGET_HOST" != *:* ]]; then
    RESOLVED_IP="$(tailscale ip -4 "$TARGET_HOST" 2>/dev/null | head -n1 || true)"
fi
HOST_IP="${RESOLVED_IP:-$TARGET_HOST}"

if [ -z "$REMOTE_USER" ]; then
    read -rp "Enter the remote username on $TARGET_HOST ($HOST_IP via Tailscale): " REMOTE_USER
fi
REMOTE_USER="$(printf '%s' "$REMOTE_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [ -z "$REMOTE_USER" ]; then
    echo "Error: Remote username cannot be empty."
    exit 1
fi

SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"
PUB_PATH="$KEY_PATH.pub"
CONFIG_PATH="$SSH_DIR/config"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ ! -f "$KEY_PATH" ] || [ ! -f "$PUB_PATH" ]; then
    HOST_SHORT="$(hostname -s 2>/dev/null || echo client)"
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "techsupport@${HOST_SHORT}"
fi

# Update ~/.ssh/config cleanly, preserving unrelated Host blocks
python3 - "$CONFIG_PATH" "$SSH_ALIAS" "$TARGET_HOST" "$HOST_IP" "$REMOTE_USER" <<'PYEOF'
import os
import re
import sys

config_path, ssh_alias, target_host, host_ip, remote_user = sys.argv[1:6]

aliases = [ssh_alias]
if target_host and target_host != ssh_alias and target_host != host_ip:
    aliases.append(target_host)
match_tokens = set(aliases)

new_block = (
    f"Host {' '.join(aliases)}\n"
    f"    HostName {host_ip}\n"
    f"    User {remote_user}\n"
    "    IdentityFile ~/.ssh/id_ed25519\n"
    "    IdentitiesOnly yes\n"
    "    StrictHostKeyChecking accept-new\n"
    "    ServerAliveInterval 15\n"
    "    ServerAliveCountMax 3\n"
)

existing = ""
if os.path.isfile(config_path):
    with open(config_path, "r", encoding="utf-8") as fh:
        existing = fh.read()

lines = existing.splitlines(keepends=True)
kept = []
skipping = False
for line in lines:
    stripped = line.strip()
    if re.match(r"^(Host|Match)\s+", stripped, re.IGNORECASE):
        tokens = stripped.split()[1:]
        if re.match(r"^Host\s+", stripped, re.IGNORECASE) and (match_tokens & set(tokens)):
            skipping = True
            continue
        skipping = False
    if not skipping:
        kept.append(line)

body = "".join(kept).rstrip("\n")
output = f"{body}\n\n{new_block}" if body else new_block

with open(config_path, "w", encoding="utf-8") as fh:
    fh.write(output)
os.chmod(config_path, 0o600)
PYEOF

# Inspect port 22 SSH banner to distinguish Windows OpenSSH vs Linux/POSIX OpenSSH
BANNER="$(python3 - "$HOST_IP" <<'PYEOF'
import socket
import sys

host = sys.argv[1]
try:
    with socket.create_connection((host, 22), timeout=5) as sock:
        sock.settimeout(5)
        data = sock.recv(256)
        sys.stdout.write(data.decode("utf-8", "replace").strip())
except Exception as exc:
    sys.stderr.write(f"Could not reach {host}:22 over Tailscale: {exc}\n")
    sys.exit(1)
PYEOF
)"

echo "Detected SSH server on $HOST_IP: $BANNER"
echo "Type your password for $REMOTE_USER@$HOST_IP when prompted..."

if [[ "$BANNER" == *Windows* ]] || [[ "$BANNER" == *windows* ]]; then
    ENC_CMD="$(python3 - "$PUB_PATH" <<'PYEOF'
import base64
import sys

pub_key = open(sys.argv[1], "r", encoding="utf-8").read().strip().replace("'", "''")
ps_script = f"""$ErrorActionPreference = 'Stop'
$k = '{pub_key}'
$noBom = New-Object System.Text.UTF8Encoding($false)

function Ensure-KeyLine([string]$Path, [string]$Key) {{
    $lines = @()
    if (Test-Path -LiteralPath $Path) {{
        $lines = @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | Where-Object {{ $_ -ne '' }})
    }}
    if ($lines -notcontains $Key) {{
        $lines += $Key
        [System.IO.File]::WriteAllLines($Path, [string[]]$lines, $noBom)
    }}
}}

$userSsh = Join-Path $env:USERPROFILE '.ssh'
New-Item -Force -ItemType Directory -Path $userSsh | Out-Null
Ensure-KeyLine -Path (Join-Path $userSsh 'authorized_keys') -Key $k

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {{
    $progSsh = 'C:\\ProgramData\\ssh'
    New-Item -Force -ItemType Directory -Path $progSsh | Out-Null
    $adminAuth = Join-Path $progSsh 'administrators_authorized_keys'
    Ensure-KeyLine -Path $adminAuth -Key $k
    & icacls.exe $adminAuth /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F' | Out-Null
}}

Write-Output "KEY_INSTALLED_OK (Admin=$isAdmin)"
"""
sys.stdout.write(base64.b64encode(ps_script.encode("utf-16le")).decode("ascii"))
PYEOF
)"
    ssh -o PubkeyAuthentication=no "$SSH_ALIAS" "powershell.exe -NoProfile -EncodedCommand $ENC_CMD"
else
    QUOTED_KEY="$(python3 - "$PUB_PATH" <<'PYEOF'
import shlex
import sys

pub_key = open(sys.argv[1], "r", encoding="utf-8").read().strip()
sys.stdout.write(shlex.quote(pub_key))
PYEOF
)"
    ssh -o PubkeyAuthentication=no "$SSH_ALIAS" \
        "umask 077 && mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && { grep -Fqx -- $QUOTED_KEY ~/.ssh/authorized_keys || printf '%s\n' $QUOTED_KEY >> ~/.ssh/authorized_keys; } && echo KEY_INSTALLED_OK"
fi

echo "Verifying unattended SSH access over Tailscale..."
if result="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_ALIAS" "echo OK" 2>&1)"; then
    echo "Success! Passwordless SSH over Tailscale works ($SSH_ALIAS): $result"
else
    echo "Warning: Key was uploaded, but BatchMode SSH check failed:"
    echo "$result"
    echo "Check that PubkeyAuthentication is enabled in the remote sshd_config."
    exit 1
fi
