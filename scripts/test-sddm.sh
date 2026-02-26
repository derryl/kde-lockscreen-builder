#!/usr/bin/env bash
#
# test-sddm.sh - Full-fidelity test using the real SDDM greeter.
#
# Opens sddm-greeter-qt6 in test mode, loading the theme from the
# project directory. Shows real user list, session list, and keyboard
# state. Login/power actions won't actually execute in test mode.
#
# Usage:  ./scripts/test-sddm.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== KDE Lockscreen Builder — SDDM Test Mode ==="
echo "Theme: $PROJECT_DIR"
echo ""

sddm-greeter-qt6 --test-mode --theme "$PROJECT_DIR"
