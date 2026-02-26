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

# ── Locate Qt 6 tools ────────────────────────────────────────────
# Binary names and paths vary across distros:
#   Arch:   qmllint, qml6          (on PATH)
#   Ubuntu: qmllint, qml           (in /usr/lib/qt6/bin)
for candidate in /usr/lib/qt6/bin /usr/lib64/qt6/bin; do
    [[ -d "$candidate" ]] && export PATH="$candidate:$PATH"
done

find_tool() {
    for name in "$@"; do
        if command -v "$name" &>/dev/null; then
            echo "$name"
            return
        fi
    done
    echo ""
}

QMLLINT=$(find_tool qmllint qmllint6)
QML_RUNTIME=$(find_tool qml6 qml)

FAILED=0

# ── Static analysis with qmllint ──────────────────────────────────
echo "=== qmllint: static analysis ==="

if [[ -z "$QMLLINT" ]]; then
    echo "SKIP: qmllint not found."
else
    QML_FILES=$(find . -name '*.qml' -not -path './.git/*')
    echo "Checking: $QML_FILES"
    echo ""

    if ! $QMLLINT $QML_FILES; then
        echo "FAIL: qmllint found issues."
        FAILED=1
    else
        echo "PASS: qmllint clean."
    fi
fi
echo ""

# ── Runtime type-error check ──────────────────────────────────────
echo "=== Runtime: checking for type errors ==="

if [[ -z "$QML_RUNTIME" ]]; then
    echo "SKIP: qml runtime not found (tried qml6, qml)."
    echo ""
    exit $FAILED
fi

# Use the Basic style to avoid Breeze/Plasma-specific errors that only
# occur outside a full Plasma session (e.g. T.Overlay in ComboBox).
export QT_QUICK_CONTROLS_STYLE=Basic

STDERR_LOG=$(mktemp)
trap 'rm -f "$STDERR_LOG"' EXIT

# Run preview for 3 seconds under a virtual framebuffer, capture stderr.
if command -v xvfb-run &>/dev/null; then
    timeout 3 xvfb-run -a "$QML_RUNTIME" preview/Preview.qml 2>"$STDERR_LOG" || true
elif [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    timeout 3 "$QML_RUNTIME" preview/Preview.qml 2>"$STDERR_LOG" || true
else
    echo "SKIP: no display and xvfb-run not available."
    echo ""
    exit $FAILED
fi

# Filter for errors we care about (type assignment, ReferenceError, TypeError).
if grep -E 'Unable to assign|ReferenceError|TypeError' "$STDERR_LOG" \
    | grep -v 'Cannot open:' \
    | grep -q .; then
    echo "FAIL: runtime type errors detected:"
    grep -E 'Unable to assign|ReferenceError|TypeError' "$STDERR_LOG" \
        | grep -v 'Cannot open:'
    FAILED=1
else
    echo "PASS: no runtime type errors."
fi
echo ""

exit $FAILED
