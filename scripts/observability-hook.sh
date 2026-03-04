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

# Load shared JSON utilities
source "$(cd "$(dirname "$0")" && pwd)/lib/json-helpers.sh"

# Cross-platform temp directory
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TMPDIR="${TMPDIR:-${PROJECT_ROOT}/.claude/tmp}"
mkdir -p "$TMPDIR"
LOG_FILE="$PROJECT_ROOT/.claude/agent-team-log.jsonl"
START_TIME=$(date +%s%3N 2>/dev/null || echo "0")
# Validate %3N was actually expanded (some platforms output literal "%3N")
if [[ "$START_TIME" =~ [^0-9] ]]; then
    START_TIME=$(date +%s)000
fi

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
    FILES_TOUCHED=$(build_json_array "$RAW_FILES")
fi

# --- Calculate duration if possible ---
END_TIME=$(date +%s%3N 2>/dev/null || echo "0")
if [[ "$END_TIME" =~ [^0-9] ]]; then
    END_TIME=$(date +%s)000
fi
DURATION_MS=$(( END_TIME - START_TIME ))

# --- Escape string fields for safe JSON embedding ---
TIMESTAMP_ESC=$(escape_json_string "$TIMESTAMP")
EVENT_TYPE_ESC=$(escape_json_string "$EVENT_TYPE")
AGENT_ROLE_ESC=$(escape_json_string "$AGENT_ROLE")
ACTION_ESC=$(escape_json_string "$ACTION")
STATUS_ESC=$(escape_json_string "$STATUS")

# --- Ensure log directory exists ---
mkdir -p "$(dirname "$LOG_FILE")"

# --- Append JSON log entry ---
cat >> "$LOG_FILE" <<JSONEOF
{"timestamp":"$TIMESTAMP_ESC","event_type":"$EVENT_TYPE_ESC","agent_role":"$AGENT_ROLE_ESC","action":"$ACTION_ESC","files_touched":$FILES_TOUCHED,"status":"$STATUS_ESC","duration_ms":$DURATION_MS}
JSONEOF

# Silent success - observability should not block the agent
exit 0
