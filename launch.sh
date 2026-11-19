#!/usr/bin/env bash
set -u

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Launch inside an explicit GUI terminal if double-clicked from Desktop/Caja.
# This avoids desktop defaults like uxterm -x failing before launch.sh runs.
if [ ! -t 0 ] && [ "${1:-}" != "--in-terminal" ]; then
    if command -v mate-terminal >/dev/null 2>&1; then
        exec mate-terminal --disable-factory -t "Tech Support" -e "'$SCRIPT_PATH' --in-terminal"
    elif command -v gnome-terminal >/dev/null 2>&1; then
        exec gnome-terminal --title="Tech Support" -- "$SCRIPT_PATH" --in-terminal
    elif command -v xfce4-terminal >/dev/null 2>&1; then
        exec xfce4-terminal --title="Tech Support" -e "'$SCRIPT_PATH' --in-terminal"
    elif command -v konsole >/dev/null 2>&1; then
        exec konsole -p tabtitle="Tech Support" -e "$SCRIPT_PATH" --in-terminal
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
        exec x-terminal-emulator -e "$SCRIPT_PATH" --in-terminal
    fi
fi

cd "$SCRIPT_DIR" || exit 1
mkdir -p logs

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

if ! command -v agy >/dev/null 2>&1; then
    echo "Tech Support could not find the 'agy' assistant on this computer."
    echo "Please ask your family helper to check the installation."
    read -rp "Press Enter to close..."
    exit 1
fi

check_online() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsIm 4 https://clients3.google.com/generate_204 >/dev/null 2>&1 && return 0
    fi
    ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && return 0
    ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && return 0
    return 1
}

# 1. Pre-flight internet check & gentle Wi-Fi recovery
if ! check_online; then
    echo "No internet detected. Attempting automatic Wi-Fi reset..."
    if command -v nmcli >/dev/null 2>&1; then
        nmcli networking off >/dev/null 2>&1 || true
        sleep 2
        nmcli networking on >/dev/null 2>&1 || true
        if command -v nm-online >/dev/null 2>&1; then
            nm-online -q -t 15 >/dev/null 2>&1 || true
        else
            sleep 8
        fi
    else
        sleep 5
    fi

    if ! check_online; then
        echo "Still offline. Please check that Wi-Fi is turned on or restart your router."
        read -rp "Press Enter to close..."
        exit 1
    fi
fi

# 2. Launch agy attached directly to the TTY for clean interactive rendering
agy --mode auto --dangerously-skip-permissions -i "hi"

echo ""
read -rp "Session ended. Press Enter to close..."
