#!/usr/bin/env bash
#
# lint-qml.sh - Static analysis and runtime type-error check for QML files.
#
# Runs qmllint (static) on all QML source files, then launches the preview
# under xvfb for a few seconds to catch runtime type-assignment warnings.
#
# Usage:  ./scripts/lint-qml.sh
#
# Exit codes:
#   0  All checks passed
#   1  qmllint found issues or runtime errors detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

FAILED=0

# ── Static analysis with qmllint ──────────────────────────────────
echo "=== qmllint: static analysis ==="

QML_FILES=$(find . -name '*.qml' -not -path './.git/*')
echo "Checking: $QML_FILES"
echo ""

if ! qmllint $QML_FILES; then
    echo "FAIL: qmllint found issues."
    FAILED=1
else
    echo "PASS: qmllint clean."
fi
echo ""

# ── Runtime type-error check ──────────────────────────────────────
echo "=== Runtime: checking for type errors ==="

STDERR_LOG=$(mktemp)
trap 'rm -f "$STDERR_LOG"' EXIT

# Run preview for 3 seconds under a virtual framebuffer, capture stderr.
if command -v xvfb-run &>/dev/null; then
    timeout 3 xvfb-run -a qml6 preview/Preview.qml 2>"$STDERR_LOG" || true
elif [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    timeout 3 qml6 preview/Preview.qml 2>"$STDERR_LOG" || true
else
    echo "SKIP: no display and xvfb-run not available."
    echo ""
    exit $FAILED
fi

# Filter for errors we care about (type assignment, ReferenceError, TypeError).
# Ignore the Breeze ComboBox warnings — those are from KDE's own style code.
if grep -E 'Unable to assign|ReferenceError|TypeError' "$STDERR_LOG" \
    | grep -v 'qrc:.*breeze' \
    | grep -v 'Cannot open:' \
    | grep -q .; then
    echo "FAIL: runtime type errors detected:"
    grep -E 'Unable to assign|ReferenceError|TypeError' "$STDERR_LOG" \
        | grep -v 'qrc:.*breeze' \
        | grep -v 'Cannot open:'
    FAILED=1
else
    echo "PASS: no runtime type errors."
fi
echo ""

exit $FAILED
