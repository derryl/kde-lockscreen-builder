#!/usr/bin/env bash
#
# test-sddm.sh - Full-fidelity test using the real SDDM greeter.
#
# Opens sddm-greeter-qt6 in test mode, loading the theme from the
# project directory. Shows real user list, session list, and keyboard
# state. Login/power actions won't actually execute in test mode.
#
# Usage:  ./scripts/test-sddm.sh [-theme <name>]
#
# Options:
#   -theme <name>   Test the theme in themes/<name>/ (default: "default")
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
            echo "  -theme <name>   Test the theme in themes/<name>/ (default: \"default\")"
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

echo "=== KDE Lockscreen Builder — SDDM Test Mode ==="
echo "Theme: $THEME_NAME ($THEME_DIR)"
echo ""

sddm-greeter-qt6 --test-mode --theme "$THEME_DIR"
