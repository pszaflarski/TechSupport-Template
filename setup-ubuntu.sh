#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DESKTOP_DIR="${XDG_DESKTOP_DIR:-$HOME/Desktop}"
DESKTOP_FILE="$DESKTOP_DIR/TechSupport.desktop"
SETTINGS_FILE="$HOME/.gemini/antigravity-cli/settings.json"

chmod +x "$SCRIPT_DIR/launch.sh" "$SCRIPT_DIR/setup-ubuntu.sh" "$SCRIPT_DIR/pair-ssh.sh"
chmod +x "$SCRIPT_DIR/.agents/scripts/safety_gate.py" "$SCRIPT_DIR/.agents/scripts/export_session_log.py"

mkdir -p "$SCRIPT_DIR/logs" "$DESKTOP_DIR"

# Create LOCAL_ENV.md from template if not already present
if [ ! -f "$SCRIPT_DIR/LOCAL_ENV.md" ] && [ -f "$SCRIPT_DIR/LOCAL_ENV.example.md" ]; then
    cp "$SCRIPT_DIR/LOCAL_ENV.example.md" "$SCRIPT_DIR/LOCAL_ENV.md"
    echo "Created $SCRIPT_DIR/LOCAL_ENV.md from template. Update it with this machine's details."
fi

# Install trusted Desktop launcher (Terminal=false because launch.sh opens an explicit terminal)
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Tech Support
Comment=Start Personal Tech Support
Exec=$SCRIPT_DIR/launch.sh
Icon=$SCRIPT_DIR/assets/support.png
Terminal=false
StartupNotify=true
Categories=Utility;
EOF

chmod +x "$DESKTOP_FILE"
gio set "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true
gio set "$DESKTOP_FILE" metadata::caja-trusted-launcher true 2>/dev/null || true

# Add TechSupport directory to trustedWorkspaces in agy settings.json
python3 - "$SETTINGS_FILE" "$SCRIPT_DIR" <<'PYEOF'
import json
import os
import sys

settings_path, workspace_dir = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(settings_path), exist_ok=True)

data = {}
if os.path.isfile(settings_path):
    with open(settings_path, "r", encoding="utf-8") as fh:
        raw = fh.read().strip()
        if raw:
            data = json.loads(raw)

trusted = data.get("trustedWorkspaces")
if not isinstance(trusted, list):
    trusted = []

if workspace_dir not in trusted:
    trusted.append(workspace_dir)
data["trustedWorkspaces"] = trusted

with open(settings_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PYEOF

echo "Ubuntu TechSupport setup complete:"
echo "  Desktop launcher: $DESKTOP_FILE"
echo "  Trusted workspace: $SCRIPT_DIR"
