#!/bin/bash
# observability-hook.sh - Agent activity logger
# Appends structured JSON to .claude/agent-team-log.jsonl
#
# Captures: timestamp, event_type, agent_role, action, files_touched, status, duration_ms
# Works for PostToolUse, TaskCompleted, and TeammateIdle hooks.
#
# Usage in settings.json:
#   "PostToolUse": [{ "hooks": [{ "type": "command",
#     "command": "./agent-team-templates/scripts/observability-hook.sh" }] }]

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="$PROJECT_ROOT/.claude/agent-team-log.jsonl"
START_TIME="${EPOCHREALTIME:-$(date +%s)}"

# --- Resolve fields ---
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EVENT_TYPE="${CLAUDE_HOOK_EVENT:-${1:-unknown}}"
AGENT_ROLE="${CLAUDE_AGENT_NAME:-unknown}"
ACTION="${2:-"Hook triggered"}"
STATUS="${3:-success}"

# --- Gather files touched (from recent git diff if available) ---
FILES_TOUCHED="[]"
if git rev-parse --is-inside-work-tree &>/dev/null; then
    RAW_FILES=$(git diff --name-only HEAD 2>/dev/null || git diff --name-only 2>/dev/null || echo "")
    if [ -n "$RAW_FILES" ]; then
        # Build JSON array from file list
        FILES_TOUCHED="["
        FIRST=true
        while IFS= read -r f; do
            if [ -n "$f" ]; then
                if [ "$FIRST" = true ]; then
                    FIRST=false
                else
                    FILES_TOUCHED="$FILES_TOUCHED,"
                fi
                FILES_TOUCHED="$FILES_TOUCHED\"$f\""
            fi
        done <<< "$RAW_FILES"
        FILES_TOUCHED="$FILES_TOUCHED]"
    fi
fi

# --- Calculate duration if possible ---
END_TIME="${EPOCHREALTIME:-$(date +%s)}"
DURATION_MS=0
if command -v bc &>/dev/null 2>&1; then
    DURATION_MS=$(echo "($END_TIME - $START_TIME) * 1000" | bc 2>/dev/null | cut -d. -f1 || echo 0)
fi

# --- Ensure log directory exists ---
mkdir -p "$(dirname "$LOG_FILE")"

# --- Append JSON log entry ---
cat >> "$LOG_FILE" <<JSONEOF
{"timestamp":"$TIMESTAMP","event_type":"$EVENT_TYPE","agent_role":"$AGENT_ROLE","action":"$ACTION","files_touched":$FILES_TOUCHED,"status":"$STATUS","duration_ms":$DURATION_MS}
JSONEOF

# Silent success - observability should not block the agent
exit 0
