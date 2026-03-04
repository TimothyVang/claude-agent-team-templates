#!/bin/bash
# post-edit-lint.sh - Quick lint check for PostToolUse hook on Edit/Write
# Runs after every file edit to catch issues immediately.
# This implements Stripe's insight: catch ~60% of issues before any push.
#
# Usage in settings.json:
#   "PostToolUse": [{
#     "matcher": { "tool_name": "Edit|Write" },
#     "hooks": [{ "type": "command", "command": "./agent-team-templates/scripts/post-edit-lint.sh" }]
#   }]
#
# Environment: The edited file path is available via $CLAUDE_TOOL_INPUT_FILE_PATH

set -euo pipefail

# Cross-platform temp directory
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TMPDIR="${TMPDIR:-${PROJECT_ROOT}/.claude/tmp}"
mkdir -p "$TMPDIR"

FILE="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"

if [ -z "$FILE" ]; then
    exit 0
fi

# Get file extension
EXT="${FILE##*.}"

case "$EXT" in
    ts|tsx)
        # Quick TypeScript/ESLint check on just the changed file
        if command -v npx &>/dev/null && [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/tsconfig.json" ]; then
            npx eslint "$FILE" --quiet 2>/dev/null || echo "[LINT] Issues in $FILE"
        fi
        ;;
    js|jsx)
        if command -v npx &>/dev/null; then
            npx eslint "$FILE" --quiet 2>/dev/null || echo "[LINT] Issues in $FILE"
        fi
        ;;
    py)
        if command -v ruff &>/dev/null; then
            ruff check "$FILE" --quiet 2>/dev/null || echo "[LINT] Issues in $FILE"
        elif command -v flake8 &>/dev/null; then
            flake8 "$FILE" --quiet 2>/dev/null || echo "[LINT] Issues in $FILE"
        fi
        ;;
    go)
        if command -v gofmt &>/dev/null; then
            gofmt -l "$FILE" 2>/dev/null | grep -q . && echo "[LINT] Format issues in $FILE"
        fi
        ;;
esac

exit 0
