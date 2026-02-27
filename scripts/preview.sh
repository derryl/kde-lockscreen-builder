#!/usr/bin/env bash
#
# preview.sh - Live-reload preview for the SDDM theme.
#
# Launches the QML preview window once, then watches for file changes.
# On any change, touches a signal file that the QML Loader polls, causing
# it to reload components in-place without restarting the window.
#
# Usage:  ./scripts/preview.sh [-theme <name>]
#
# Options:
#   -theme <name>   Preview the theme in themes/<name>/ (default: "default")
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Parse arguments ─────────────────────────────────────────────
THEME_NAME="default"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -theme)
            THEME_NAME="${2:?Error: -theme requires a name}"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-theme <name>]"
            echo ""
            echo "Options:"
            echo "  -theme <name>   Preview the theme in themes/<name>/ (default: \"default\")"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [-theme <name>]" >&2
            exit 1
            ;;
    esac
done

THEME_DIR="$PROJECT_DIR/themes/$THEME_NAME"

if [[ ! -d "$THEME_DIR" ]]; then
    echo "Error: theme directory not found: $THEME_DIR" >&2
    echo "" >&2
    echo "Available themes:" >&2
    for d in "$PROJECT_DIR"/themes/*/; do
        [[ -d "$d" ]] && echo "  $(basename "$d")" >&2
    done
    exit 1
fi

# ── Setup ───────────────────────────────────────────────────────
SIGNAL_FILE="$PROJECT_DIR/preview/.reload-signal"
QML_PID=""
ENTR_PID=""

cleanup() {
    trap - SIGINT SIGTERM   # prevent re-entry
    [[ -n "$ENTR_PID" ]] && kill "$ENTR_PID" 2>/dev/null && wait "$ENTR_PID" 2>/dev/null
    [[ -n "$QML_PID" ]]  && kill "$QML_PID"  2>/dev/null && wait "$QML_PID"  2>/dev/null
    rm -f "$SIGNAL_FILE"
    rm -f "$PROJECT_DIR/preview/components" "$PROJECT_DIR/preview/assets"
    echo ""
    echo "Preview stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM

# Force the Basic Qt Quick Controls style so the standalone preview doesn't
# load Breeze, which depends on Plasma-specific overlay types that are
# unavailable outside a full Plasma session.
export QT_QUICK_CONTROLS_STYLE=Basic
# Allow QML's XMLHttpRequest to read local files so the hot-reload
# file watcher can poll the signal file.
export QML_XHR_ALLOW_FILE_READ=1

# Symlink the theme's components and assets into preview/ so QML's
# relative imports and asset paths resolve to the selected theme.
ln -sfn "$THEME_DIR/components" "$PROJECT_DIR/preview/components"
ln -sfn "$THEME_DIR/assets"     "$PROJECT_DIR/preview/assets"

# Create the initial signal file so the QML poller has something to read.
touch "$SIGNAL_FILE"

echo "=== KDE Lockscreen Builder — Live Preview ==="
echo "Project: $PROJECT_DIR"
echo "Theme:   $THEME_NAME ($THEME_DIR)"
echo "Hot reload: editing theme files will update the preview in-place"
echo "Press Ctrl+C to stop"
echo ""

cd "$PROJECT_DIR"

# Launch qml6 once — it stays running for the entire session.
qml6 preview/Preview.qml &
QML_PID=$!

# Watch for file changes and touch the signal file to trigger QML reload.
# Using entr without -r so it doesn't kill/restart anything.
while true; do
    find . \( -name '*.qml' -o -name '*.conf' -o -name '*.jpg' -o -name '*.png' -o -name '*.svg' \) \
        -not -name '.reload-signal' \
        | entr -d -p sh -c 'date +%s%N > "'"$SIGNAL_FILE"'"' &
    ENTR_PID=$!
    wait "$ENTR_PID" || true
    ENTR_PID=""

    # If qml6 exited on its own (user closed window), stop everything.
    if ! kill -0 "$QML_PID" 2>/dev/null; then
        echo "Preview window closed."
        rm -f "$SIGNAL_FILE"
        rm -f "$PROJECT_DIR/preview/components" "$PROJECT_DIR/preview/assets"
        exit 0
    fi
done
