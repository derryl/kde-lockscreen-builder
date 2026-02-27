#!/usr/bin/env bash
#
# lint-qml.sh - Static analysis and runtime type-error check for QML files.
#
# Runs qmllint (static) on all QML source files, then launches the preview
# under xvfb for a few seconds to catch runtime type-assignment warnings.
#
# Usage:  ./scripts/lint-qml.sh [-theme <name>]
#
# Options:
#   -theme <name>   Lint a specific theme (default: lint all themes)
#
# Exit codes:
#   0  All checks passed
#   1  qmllint found issues or runtime errors detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# ── Parse arguments ─────────────────────────────────────────────
THEME_NAME=""

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
            echo "  -theme <name>   Lint a specific theme (default: lint all themes)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [-theme <name>]" >&2
            exit 1
            ;;
    esac
done

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

# Build list of theme directories to check.
if [[ -n "$THEME_NAME" ]]; then
    THEME_DIRS=("themes/$THEME_NAME")
    if [[ ! -d "${THEME_DIRS[0]}" ]]; then
        echo "Error: theme directory not found: ${THEME_DIRS[0]}" >&2
        exit 1
    fi
else
    THEME_DIRS=()
    for d in themes/*/; do
        [[ -d "$d" ]] && THEME_DIRS+=("${d%/}")
    done
fi

# ── Static analysis with qmllint ──────────────────────────────────
echo "=== qmllint: static analysis ==="

if [[ -z "$QMLLINT" ]]; then
    echo "SKIP: qmllint not found."
else
    QML_FILES=$(find "${THEME_DIRS[@]}" preview -name '*.qml' -not -path './.git/*')
    echo "Checking: $QML_FILES"
    echo ""

    # qmllint emits warnings for SDDM context properties (sddm, config,
    # userModel, etc.) that only exist at runtime. These are expected and
    # unavoidable. We capture the output and only fail on actual errors
    # (syntax errors, unknown components from our own code), not warnings
    # about unqualified/unresolved access to SDDM injected globals.
    LINT_OUTPUT=$($QMLLINT $QML_FILES 2>&1) || true
    if echo "$LINT_OUTPUT" | grep -qiE '^Error:'; then
        echo "$LINT_OUTPUT"
        echo "FAIL: qmllint found errors."
        FAILED=1
    else
        echo "PASS: qmllint clean (warnings only)."
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
trap 'rm -f "$STDERR_LOG" "$PROJECT_DIR/preview/components" "$PROJECT_DIR/preview/assets" "$PROJECT_DIR/preview/Main.qml"' EXIT

# Test with the default theme (or the specified one).
RUNTIME_THEME="${THEME_DIRS[0]}"
RUNTIME_THEME_DIR="$PROJECT_DIR/$RUNTIME_THEME"
# Symlink the theme's Main.qml, components, and assets into preview/ so QML resolves them.
ln -sfn "$RUNTIME_THEME_DIR/Main.qml"    "$PROJECT_DIR/preview/Main.qml"
ln -sfn "$RUNTIME_THEME_DIR/components"  "$PROJECT_DIR/preview/components"
ln -sfn "$RUNTIME_THEME_DIR/assets"      "$PROJECT_DIR/preview/assets"

# Run preview for 3 seconds under a virtual framebuffer, capture stderr.
# Use the Python preview host so SDDM context properties are injected.
PREVIEW_CMD="python3 $SCRIPT_DIR/preview-host.py $RUNTIME_THEME_DIR"
if command -v xvfb-run &>/dev/null; then
    timeout 3 xvfb-run -a $PREVIEW_CMD 2>"$STDERR_LOG" || true
elif [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    timeout 3 $PREVIEW_CMD 2>"$STDERR_LOG" || true
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
