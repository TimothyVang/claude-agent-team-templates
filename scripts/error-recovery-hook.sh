#!/bin/bash
# error-recovery-hook.sh - Multi-tier error recovery for TaskCompleted
# Runs after verify-task.sh fails, attempting automated recovery before escalating.
#
# Exit codes:
#   0 = success (verification passed on retry)
#   1 = hard failure (all tiers exhausted, block the agent)
#   2 = feedback + continue (agent gets guidance, keeps working)
#
# Usage in settings.json:
#   "TaskCompleted": [{ "hooks": [{ "type": "command",
#     "command": "./agent-team-templates/scripts/error-recovery-hook.sh" }] }]

set -euo pipefail

# Cross-platform temp directory
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TMPDIR="${TMPDIR:-${PROJECT_ROOT}/.claude/tmp}"
mkdir -p "$TMPDIR"
RETRY_STATE_FILE="$TMPDIR/error-recovery-attempts-$(basename "$PROJECT_ROOT")"
MAX_RETRIES=3
LOG_FILE="$PROJECT_ROOT/.claude/agent-team-log.jsonl"

# --- Auto-detect verification command ---
detect_verify_cmd() {
    if [ -n "${1:-}" ]; then
        echo "$1"
        return
    fi
    if [ -f "$PROJECT_ROOT/package.json" ]; then
        if grep -q '"test"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            echo "cd '$PROJECT_ROOT' && npm test"
            return
        fi
    fi
    if command -v pytest &>/dev/null && [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
        echo "pytest '$PROJECT_ROOT' -q --tb=short"
        return
    fi
    echo ""
}

VERIFY_CMD=$(detect_verify_cmd "${1:-}")

if [ -z "$VERIFY_CMD" ]; then
    echo "[RECOVERY] No verification command detected or provided. Skipping."
    exit 0
fi

# --- Read current attempt count ---
ATTEMPT=0
if [ -f "$RETRY_STATE_FILE" ]; then
    ATTEMPT=$(cat "$RETRY_STATE_FILE" 2>/dev/null || echo 0)
fi

# --- Tier 1: Retry with exponential backoff ---
echo "=== Tier 1: Retry with backoff ==="
for i in 1 2 3; do
    DELAY=$((2 ** i))
    echo "[RETRY] Attempt $i/$MAX_RETRIES (waiting ${DELAY}s)..."
    sleep "$DELAY"

    if eval "$VERIFY_CMD" >/dev/null 2>&1; then
        echo "[RECOVERY] Verification passed on retry attempt $i."
        rm -f "$RETRY_STATE_FILE"
        exit 0
    fi
done
echo "[RECOVERY] Tier 1 exhausted. All $MAX_RETRIES retries failed."

# --- Tier 2: Undo-and-retry ---
echo ""
echo "=== Tier 2: Undo and retry ==="

# Only attempt git operations if we have commits to undo
if git log --oneline -1 &>/dev/null; then
    echo "[RECOVERY] Stashing current state..."
    git stash push -m "error-recovery-hook auto-stash" 2>/dev/null || true

    echo "[RECOVERY] Soft-resetting last commit..."
    git reset --soft HEAD~1 2>/dev/null || {
        echo "[RECOVERY] Could not reset last commit. Restoring stash."
        git stash pop 2>/dev/null || true
    }

    echo "[RECOVERY] Restoring working state..."
    git stash pop 2>/dev/null || true

    # Capture what failed for feedback
    FAIL_OUTPUT=$(eval "$VERIFY_CMD" 2>&1 || true)

    ATTEMPT=$((ATTEMPT + 1))
    echo "$ATTEMPT" > "$RETRY_STATE_FILE"

    echo ""
    echo "=== Agent Feedback (Tier 2) ==="
    echo "[FEEDBACK] Verification still failing after undo-and-retry."
    echo "[FEEDBACK] Failed command: $VERIFY_CMD"
    echo "[FEEDBACK] Output:"
    echo "$FAIL_OUTPUT" | head -30
    echo ""
    echo "[FEEDBACK] Suggestions:"
    echo "  - Review the error output above and fix the underlying issue"
    echo "  - Ensure all changed files are syntactically correct"
    echo "  - Run the verification command manually to debug"
    exit 2
else
    echo "[RECOVERY] No git commits to undo. Skipping tier 2."
fi

# --- Tier 3: Human escalation ---
echo ""
echo "=== Tier 3: Human escalation ==="
echo "[ESCALATE] All automated recovery tiers exhausted."
echo "[ESCALATE] Manual intervention required."
echo ""
echo "[ACTION] Please notify the team lead about this failure."
echo "[ACTION] Relevant context:"
echo "  - Project: $PROJECT_ROOT"
echo "  - Verify command: $VERIFY_CMD"
echo "  - Attempts: $ATTEMPT"

# Log to observability file
mkdir -p "$(dirname "$LOG_FILE")"
cat >> "$LOG_FILE" <<JSONEOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","event_type":"error_recovery_escalation","agent_role":"${CLAUDE_AGENT_NAME:-unknown}","action":"All recovery tiers exhausted","status":"failure","verify_cmd":"$VERIFY_CMD","attempts":$ATTEMPT}
JSONEOF

rm -f "$RETRY_STATE_FILE"
exit 2
