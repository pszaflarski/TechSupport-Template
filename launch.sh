#!/usr/bin/env bash
set -u

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Launch inside an explicit GUI terminal if double-clicked from Desktop/Caja.
# This avoids desktop defaults like uxterm -x failing before launch.sh runs.
if [ ! -t 0 ] && [ "${1:-}" != "--in-terminal" ]; then
    APP_WM_CLASS="com.canonical.Terminal.TechSupport"
    if command -v mate-terminal >/dev/null 2>&1; then
        exec mate-terminal --disable-factory --class="$APP_WM_CLASS" -t "Tech Support" -e "'$SCRIPT_PATH' --in-terminal"
    elif command -v gnome-terminal >/dev/null 2>&1; then
        if grep -Iq -- '--app-id' "$(command -v gnome-terminal)" 2>/dev/null; then
            exec gnome-terminal --app-id="$APP_WM_CLASS" --class="$APP_WM_CLASS" --title="Tech Support" -- "$SCRIPT_PATH" --in-terminal
        else
            exec gnome-terminal --class="$APP_WM_CLASS" --title="Tech Support" -- "$SCRIPT_PATH" --in-terminal
        fi
    elif command -v ptyxis >/dev/null 2>&1; then
        exec ptyxis --title="Tech Support" -- "$SCRIPT_PATH" --in-terminal
    elif command -v kgx >/dev/null 2>&1; then
        exec kgx --title="Tech Support" -- "$SCRIPT_PATH" --in-terminal
    elif command -v xfce4-terminal >/dev/null 2>&1; then
        exec xfce4-terminal --disable-server --class="$APP_WM_CLASS" --title="Tech Support" -e "'$SCRIPT_PATH' --in-terminal"
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

# 2. Resolve model (defaults to free-tier Flash; override in git-ignored .env)
TECHSUPPORT_MODEL="${TECHSUPPORT_MODEL:-gemini-3.8-flash-high}"
if [ -f "$SCRIPT_DIR/.env" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in
            ""|\#*) continue ;;
            TECHSUPPORT_MODEL=*)
                val="${line#TECHSUPPORT_MODEL=}"
                val="${val#"${val%%[![:space:]]*}"}"
                val="${val%"${val##*[![:space:]]}"}"
                val="${val#\"}" ; val="${val%\"}"
                val="${val#\'}" ; val="${val%\'}"
                TECHSUPPORT_MODEL="$val"
                ;;
        esac
    done < "$SCRIPT_DIR/.env"
fi

# 3. Launch agy attached directly to the TTY for clean interactive rendering
AGY_ARGS=(--mode auto --dangerously-skip-permissions)
if [ -n "$TECHSUPPORT_MODEL" ] && [ "$TECHSUPPORT_MODEL" != "default" ]; then
    AGY_ARGS=(--model "$TECHSUPPORT_MODEL" "${AGY_ARGS[@]}")
fi
agy "${AGY_ARGS[@]}" -i "hi"

echo ""
read -rp "Session ended. Press Enter to close..."
