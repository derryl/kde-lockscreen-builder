#!/usr/bin/env bash
#
# preview.sh - Live-reload preview for the SDDM theme.
#
# Watches all QML, conf, and image files. On any change, kills the
# running qml6 process and relaunches the Preview.qml harness.
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
ENTR_PID=""

cleanup() {
    trap - SIGINT SIGTERM   # prevent re-entry
    [[ -n "$ENTR_PID" ]] && kill "$ENTR_PID" 2>/dev/null && wait "$ENTR_PID" 2>/dev/null
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

# Symlink the theme's components and assets into preview/ so QML's
# relative imports and asset paths resolve to the selected theme.
ln -sfn "$THEME_DIR/components" "$PROJECT_DIR/preview/components"
ln -sfn "$THEME_DIR/assets"     "$PROJECT_DIR/preview/assets"

echo "=== KDE Lockscreen Builder — Live Preview ==="
echo "Project: $PROJECT_DIR"
echo "Theme:   $THEME_NAME ($THEME_DIR)"
echo "Press Ctrl+C to stop"
echo ""

cd "$PROJECT_DIR"

while true; do
    find . \( -name '*.qml' -o -name '*.conf' -o -name '*.jpg' -o -name '*.png' -o -name '*.svg' \) \
        | entr -d -r qml6 preview/Preview.qml &
    ENTR_PID=$!
    wait "$ENTR_PID" || true
    ENTR_PID=""
done
