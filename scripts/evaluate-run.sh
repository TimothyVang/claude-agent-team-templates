#!/bin/bash
# evaluate-run.sh - Post-run report generator
# Parses .claude/agent-team-log.jsonl and produces a markdown summary.
# Uses bash + grep/sed/awk only (no bc, no jq) for cross-platform compatibility.
#
# Usage:
#   ./agent-team-templates/scripts/evaluate-run.sh
#   ./agent-team-templates/scripts/evaluate-run.sh /path/to/custom-log.jsonl

set -euo pipefail

# Cross-platform temp directory
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TMPDIR="${TMPDIR:-${PROJECT_ROOT}/.claude/tmp}"
mkdir -p "$TMPDIR"

LOG_FILE="${1:-${PROJECT_ROOT}/.claude/agent-team-log.jsonl}"
TIMESTAMP=$(date +%Y%m%dT%H%M%S)
REPORT_FILE="${PROJECT_ROOT}/.claude/run-report-${TIMESTAMP}.md"

if [ ! -f "$LOG_FILE" ]; then
    echo "[ERROR] Log file not found: $LOG_FILE"
    exit 1
fi

echo "=== Evaluating run log: $LOG_FILE ==="

# --- Parse counts using grep/awk ---
TOTAL_ENTRIES=$(grep -c . "$LOG_FILE" 2>/dev/null || echo 0)
SUCCESS_COUNT=$(grep -c '"status":"success"' "$LOG_FILE" 2>/dev/null || echo 0)
FAILURE_COUNT=$(grep -c '"status":"failure"' "$LOG_FILE" 2>/dev/null || echo 0)
RETRY_COUNT=$(grep -c '"event_type":"error_recovery"' "$LOG_FILE" 2>/dev/null || echo 0)
ESCALATION_COUNT=$(grep -c '"event_type":"error_recovery_escalation"' "$LOG_FILE" 2>/dev/null || echo 0)
TASK_COMPLETED=$(grep -c '"event_type":"TaskCompleted"' "$LOG_FILE" 2>/dev/null || echo 0)

# Task completion rate (integer math only)
TOTAL_TASKS=$((TASK_COMPLETED + FAILURE_COUNT))
if [ "$TOTAL_TASKS" -gt 0 ]; then
    COMPLETION_RATE=$(( (TASK_COMPLETED * 100) / TOTAL_TASKS ))
else
    COMPLETION_RATE=0
fi

# --- Extract time span ---
FIRST_TIMESTAMP=$(grep -m1 '"timestamp"' "$LOG_FILE" 2>/dev/null | sed 's/.*"timestamp":"\([^"]*\)".*/\1/' || echo "unknown")
LAST_TIMESTAMP=$(grep '"timestamp"' "$LOG_FILE" 2>/dev/null | tail -1 | sed 's/.*"timestamp":"\([^"]*\)".*/\1/' || echo "unknown")

# --- Collect unique agents ---
AGENTS=$(grep -o '"agent_role":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u | sed 's/"agent_role":"//;s/"//' | tr '\n' ', ' | sed 's/,$//' || echo "unknown")

# --- Flagged patterns ---
FLAGGED_RETRIES=""
if [ "$RETRY_COUNT" -gt 0 ]; then
    FLAGGED_RETRIES="- $RETRY_COUNT automated retry attempt(s) detected"
fi
FLAGGED_ESCALATIONS=""
if [ "$ESCALATION_COUNT" -gt 0 ]; then
    FLAGGED_ESCALATIONS="- $ESCALATION_COUNT escalation(s) to human required"
fi

# --- Write report ---
mkdir -p "$(dirname "$REPORT_FILE")"
cat > "$REPORT_FILE" << REPORT_EOF
# Agent Team Run Report
Generated: ${TIMESTAMP}

## Summary
| Metric | Value |
|--------|-------|
| Total log entries | ${TOTAL_ENTRIES} |
| Tasks completed | ${TASK_COMPLETED} |
| Task completion rate | ${COMPLETION_RATE}% |
| Successes | ${SUCCESS_COUNT} |
| Failures | ${FAILURE_COUNT} |
| Retry attempts | ${RETRY_COUNT} |
| Escalations | ${ESCALATION_COUNT} |

## Time Span
- First entry: ${FIRST_TIMESTAMP}
- Last entry:  ${LAST_TIMESTAMP}

## Agents Active
${AGENTS}

## Flagged Patterns
${FLAGGED_RETRIES:-None}
${FLAGGED_ESCALATIONS:-}

## Log File
\`${LOG_FILE}\`
REPORT_EOF

echo "Report written to: $REPORT_FILE"
exit 0
