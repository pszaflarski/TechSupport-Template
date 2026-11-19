#!/usr/bin/env bash
set -u

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIX_SCRIPT="${1:-$PROJECT_DIR/temp_fix.sh}"
MODE_FLAG="${2:-}"
TITLE="Tech Support — Fix Issue"

has_display() {
    [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]
}

show_result_zenity() {
    local rc="$1"
    if [ "$rc" -eq 0 ]; then
        zenity --info --title="$TITLE" \
            --text="Done! Go back to Tech Support and type 'done'." 2>/dev/null || true
    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then
        zenity --info --title="$TITLE" \
            --text="Cancelled — no changes were made." 2>/dev/null || true
    else
        zenity --warning --title="$TITLE" \
            --text="Done, but something may have failed. Go back to Tech Support and type 'done' so I can check." 2>/dev/null || true
    fi
}

show_result_kdialog() {
    local rc="$1"
    if [ "$rc" -eq 0 ]; then
        kdialog --title "$TITLE" \
            --msgbox "Done! Go back to Tech Support and type 'done'." 2>/dev/null || true
    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then
        kdialog --title "$TITLE" \
            --msgbox "Cancelled — no changes were made." 2>/dev/null || true
    else
        kdialog --title "$TITLE" \
            --sorry "Done, but something may have failed. Go back to Tech Support and type 'done' so I can check." 2>/dev/null || true
    fi
}

if [ ! -f "$FIX_SCRIPT" ]; then
    MSG="Could not find the fix script. Go back to Tech Support and ask to try again."
    if has_display && command -v zenity >/dev/null 2>&1; then
        zenity --error --title="$TITLE" --text="$MSG" 2>/dev/null || true
    elif has_display && command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$TITLE" --error "$MSG" 2>/dev/null || true
    else
        echo "$MSG" >&2
    fi
    exit 1
fi

if has_display && command -v zenity >/dev/null 2>&1; then
    RC_FILE="$(mktemp)"
    trap 'rm -f "$RC_FILE"' EXIT

    (
        rc=0
        pkexec /bin/bash "$FIX_SCRIPT" >/dev/null 2>&1 || rc=$?
        echo "$rc" > "$RC_FILE"
        echo "100"
    ) | zenity --progress --pulsate --no-cancel --auto-close \
        --title="$TITLE" \
        --text="Working! Please wait..." >/dev/null 2>&1 || true

    RC=1
    if [ -s "$RC_FILE" ]; then
        RC="$(cat "$RC_FILE")"
    fi
    show_result_zenity "$RC"
    exit "$RC"
fi

if has_display && command -v kdialog >/dev/null 2>&1; then
    DBUS_REF="$(kdialog --title "$TITLE" --progressbar "Working! Please wait..." 0 2>/dev/null || true)"
    RC=0
    pkexec /bin/bash "$FIX_SCRIPT" >/dev/null 2>&1 || RC=$?

    if [ -n "$DBUS_REF" ]; then
        read -r K_SVC K_OBJ <<< "$DBUS_REF"
        if command -v qdbus6 >/dev/null 2>&1; then
            qdbus6 "$K_SVC" "$K_OBJ" close >/dev/null 2>&1 || true
        elif command -v qdbus >/dev/null 2>&1; then
            qdbus "$K_SVC" "$K_OBJ" close >/dev/null 2>&1 || true
        fi
    fi

    show_result_kdialog "$RC"
    exit "$RC"
fi

if [ ! -t 0 ] && [ "$MODE_FLAG" != "--in-terminal" ] && has_display; then
    if command -v mate-terminal >/dev/null 2>&1; then
        exec mate-terminal --disable-factory -t "$TITLE" -e "'$SCRIPT_PATH' '$FIX_SCRIPT' --in-terminal"
    elif command -v gnome-terminal >/dev/null 2>&1; then
        exec gnome-terminal --title="$TITLE" -- "$SCRIPT_PATH" "$FIX_SCRIPT" --in-terminal
    elif command -v ptyxis >/dev/null 2>&1; then
        exec ptyxis --title="$TITLE" -- "$SCRIPT_PATH" "$FIX_SCRIPT" --in-terminal
    elif command -v kgx >/dev/null 2>&1; then
        exec kgx --title="$TITLE" -- "$SCRIPT_PATH" "$FIX_SCRIPT" --in-terminal
    elif command -v xfce4-terminal >/dev/null 2>&1; then
        exec xfce4-terminal --title="$TITLE" -e "'$SCRIPT_PATH' '$FIX_SCRIPT' --in-terminal"
    elif command -v konsole >/dev/null 2>&1; then
        exec konsole -p tabtitle="$TITLE" -e "$SCRIPT_PATH" "$FIX_SCRIPT" --in-terminal
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
        exec x-terminal-emulator -e "$SCRIPT_PATH" "$FIX_SCRIPT" --in-terminal
    fi
fi

echo "Working! Please wait..."
RC=0
pkexec /bin/bash "$FIX_SCRIPT" >/dev/null 2>&1 || RC=$?
if [ "$RC" -eq 0 ]; then
    echo "Done! Go back to Tech Support and type 'done'."
elif [ "$RC" -eq 126 ] || [ "$RC" -eq 127 ]; then
    echo "Cancelled — no changes were made."
else
    echo "Done, but something may have failed. Go back to Tech Support and type 'done' so I can check."
fi
read -rp "Press Enter to close..." || true
exit "$RC"
