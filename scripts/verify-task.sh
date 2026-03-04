#!/bin/bash
# verify-task.sh - Quality gate for TaskCompleted hook
# Runs automatically when any teammate marks a task as completed.
# Validates that the deliverable meets minimum quality standards.
#
# Exit codes:
#   0 = all checks passed
#   1 = hard block (second consecutive failure of same type - escalate)
#   2 = feedback + continue (first failure - agent gets guidance to fix)
#
# Usage in settings.json:
#   "TaskCompleted": [{ "hooks": [{ "type": "command", "command": "./agent-team-templates/scripts/verify-task.sh" }] }]

set -euo pipefail

# Cross-platform temp directory
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TMPDIR="${TMPDIR:-${PROJECT_ROOT}/.claude/tmp}"
mkdir -p "$TMPDIR"
STATE_FILE="$TMPDIR/verify-task-attempts-$(basename "$PROJECT_ROOT")"
ERRORS=0
FAILED_CHECKS=""

echo "=== Task Completion Verification ==="

# 1. Check for uncommitted changes (teammate should have clean state)
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "[WARN] Uncommitted changes detected. Teammate should commit before marking task complete."
fi

# 2. Run linter if config exists
if [ -f "$PROJECT_ROOT/package.json" ]; then
    if grep -q '"lint"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        echo "[CHECK] Running lint..."
        (cd "$PROJECT_ROOT" && npm run lint --silent 2>/dev/null) || {
            echo "[FAIL] Lint check failed"
            ERRORS=$((ERRORS + 1))
            FAILED_CHECKS="${FAILED_CHECKS}lint,"
        }
    fi
elif [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/setup.py" ]; then
    if command -v ruff &>/dev/null; then
        echo "[CHECK] Running ruff..."
        ruff check "$PROJECT_ROOT" --quiet 2>/dev/null || {
            echo "[FAIL] Ruff check failed"
            ERRORS=$((ERRORS + 1))
            FAILED_CHECKS="${FAILED_CHECKS}ruff,"
        }
    fi
fi

# 3. Run typecheck if config exists
if [ -f "$PROJECT_ROOT/tsconfig.json" ]; then
    echo "[CHECK] Running typecheck..."
    (cd "$PROJECT_ROOT" && npx tsc --noEmit --pretty 2>/dev/null) || {
        echo "[FAIL] TypeScript check failed"
        ERRORS=$((ERRORS + 1))
        FAILED_CHECKS="${FAILED_CHECKS}typecheck,"
    }
elif [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
    if command -v mypy &>/dev/null; then
        echo "[CHECK] Running mypy..."
        mypy "$PROJECT_ROOT" --no-error-summary 2>/dev/null || {
            echo "[FAIL] mypy check failed"
            ERRORS=$((ERRORS + 1))
            FAILED_CHECKS="${FAILED_CHECKS}mypy,"
        }
    fi
fi

# 4. Run tests if test command exists
if [ -f "$PROJECT_ROOT/package.json" ]; then
    if grep -q '"test"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        echo "[CHECK] Running tests..."
        (cd "$PROJECT_ROOT" && npm test --silent 2>/dev/null) || {
            echo "[FAIL] Tests failed"
            ERRORS=$((ERRORS + 1))
            FAILED_CHECKS="${FAILED_CHECKS}tests,"
        }
    fi
elif [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
    if command -v pytest &>/dev/null; then
        echo "[CHECK] Running pytest..."
        pytest "$PROJECT_ROOT" -q --tb=short 2>/dev/null || {
            echo "[FAIL] Tests failed"
            ERRORS=$((ERRORS + 1))
            FAILED_CHECKS="${FAILED_CHECKS}tests,"
        }
    fi
fi

# 5. Summary with attempt tracking
echo "=== Verification Complete ==="

if [ $ERRORS -gt 0 ]; then
    # Check if this is a repeated failure
    PREV_FAILURES=""
    if [ -f "$STATE_FILE" ]; then
        PREV_FAILURES=$(cat "$STATE_FILE" 2>/dev/null || echo "")
    fi

    # Compare current failures with previous
    if [ "$PREV_FAILURES" = "$FAILED_CHECKS" ] && [ -n "$PREV_FAILURES" ]; then
        # Same checks failed twice in a row - hard block
        echo "[RESULT] $ERRORS check(s) failed AGAIN (same failures as last attempt)."
        echo "[BLOCK] Hard failure: repeated failures on: $FAILED_CHECKS"
        echo "[BLOCK] Escalating - agent should notify the team lead."
        rm -f "$STATE_FILE"
        exit 1
    else
        # First failure - save state, provide feedback, let agent retry
        echo "$FAILED_CHECKS" > "$STATE_FILE"
        echo "[RESULT] $ERRORS check(s) failed (first attempt)."
        echo ""
        echo "=== Agent Feedback ==="
        echo "[FEEDBACK] The following checks failed: $FAILED_CHECKS"
        echo "[FEEDBACK] Please fix these issues and try completing the task again."
        echo "[FEEDBACK] If the same checks fail again, the task will be hard-blocked."
        exit 2
    fi
else
    # All passed - clean up state file
    rm -f "$STATE_FILE"
    echo "[RESULT] All checks passed."
    exit 0
fi
