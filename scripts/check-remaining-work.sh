#!/bin/bash
# check-remaining-work.sh - Progress monitor for TeammateIdle hook
# Runs when a teammate goes idle, checking if there's remaining work.
# Includes loop detection: warns if the same TODOs persist across 3+ checks.
#
# Usage in settings.json:
#   "TeammateIdle": [{ "hooks": [{ "type": "command", "command": "./agent-team-templates/scripts/check-remaining-work.sh" }] }]

set -euo pipefail

# Cross-platform temp directory
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TMPDIR="${TMPDIR:-${PROJECT_ROOT}/.claude/tmp}"
mkdir -p "$TMPDIR"
STATE_DIR="$PROJECT_ROOT/.claude"
STATE_FILE="$STATE_DIR/remaining-work-state.txt"

mkdir -p "$STATE_DIR"

echo "=== Remaining Work Check ==="

# 1. Check for TODO/FIXME/HACK comments in recently modified files
RECENT_FILES=$(git diff --name-only HEAD~5 2>/dev/null || find . -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.js" -o -name "*.jsx" -mmin -30 2>/dev/null | head -20)

CURRENT_TODOS=""
if [ -n "$RECENT_FILES" ]; then
    # Capture actual TODO lines for comparison (file:line format)
    CURRENT_TODOS=$(echo "$RECENT_FILES" | xargs grep -n 'TODO\|FIXME\|HACK\|XXX' 2>/dev/null | sort || echo "")
    TODO_COUNT=$(echo "$CURRENT_TODOS" | grep -c . 2>/dev/null || echo 0)
    if [ "$TODO_COUNT" -gt 0 ]; then
        echo "[INFO] Found $TODO_COUNT TODO/FIXME markers in recently modified files"
    fi
fi

# 2. Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNCOMMITTED" -gt 0 ]; then
    echo "[INFO] $UNCOMMITTED uncommitted file(s) detected"
fi

# 3. Check for untracked files in src/
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | grep -c "^src/" 2>/dev/null || echo 0)
if [ "$UNTRACKED" -gt 0 ]; then
    echo "[INFO] $UNTRACKED untracked source file(s) - may need to be committed"
fi

# 4. Loop detection - compare TODOs with previous snapshots
if [ -n "$CURRENT_TODOS" ]; then
    hash_cmd() { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1" 2>/dev/null || python3 -c "import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$1"; }
    CURRENT_SNAPSHOT=$(echo "$CURRENT_TODOS" | hash_cmd /dev/stdin 2>/dev/null | cut -d' ' -f1 || echo "none")

    # State file format: "count:hash" per line (most recent at bottom)
    CONSECUTIVE=0
    if [ -f "$STATE_FILE" ]; then
        PREV_HASH=$(tail -1 "$STATE_FILE" 2>/dev/null | cut -d: -f2 || echo "")
        if [ "$PREV_HASH" = "$CURRENT_SNAPSHOT" ]; then
            # Same TODOs - increment count from last line
            CONSECUTIVE=$(tail -1 "$STATE_FILE" | cut -d: -f1 || echo 0)
            CONSECUTIVE=$((CONSECUTIVE + 1))
        else
            # Different TODOs - reset
            CONSECUTIVE=1
        fi
    else
        CONSECUTIVE=1
    fi

    # Write current state (overwrite to keep file small)
    echo "${CONSECUTIVE}:${CURRENT_SNAPSHOT}" > "$STATE_FILE"

    if [ "$CONSECUTIVE" -ge 3 ]; then
        echo ""
        echo "[WARN] Possible loop: same TODOs detected across $CONSECUTIVE consecutive checks. Agent may be stuck."
        echo "[WARN] Stuck TODOs:"
        echo "$CURRENT_TODOS" | head -15 | while IFS= read -r line; do
            echo "  $line"
        done
        if [ "$(echo "$CURRENT_TODOS" | wc -l)" -gt 15 ]; then
            echo "  ... and more"
        fi
    fi
else
    # No TODOs found - clean state
    rm -f "$STATE_FILE"
fi

echo "=== Check Complete ==="
exit 0
