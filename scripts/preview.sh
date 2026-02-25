#!/usr/bin/env bash
#
# preview.sh - Live-reload preview for the SDDM theme.
#
# Watches all QML, conf, and image files. On any change, kills the
# running qml6 process and relaunches the Preview.qml harness.
#
# Usage:  ./scripts/preview.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== SDDM Theme Preview ==="
echo "Project: $PROJECT_DIR"
echo "Press Ctrl+C to stop"
echo ""

cd "$PROJECT_DIR"

while true; do
    find . \( -name '*.qml' -o -name '*.conf' -o -name '*.jpg' -o -name '*.png' -o -name '*.svg' \) \
        | entr -d -r qml6 preview/Preview.qml
done
