#!/bin/bash
# PreCompact Hook: Save critical state before context auto-compaction
# Preserves task context, git state, and active files so agents can
# recover smoothly after compaction reduces their conversation history.

set -euo pipefail

# Load shared JSON utilities
source "$(cd "$(dirname "$0")" && pwd)/lib/json-helpers.sh"

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SNAPSHOT_DIR="${PROJECT_ROOT}/.claude/compaction-snapshots"
mkdir -p "$SNAPSHOT_DIR"

TIMESTAMP=$(date +%Y%m%dT%H%M%S)
SNAPSHOT_FILE="${SNAPSHOT_DIR}/${TIMESTAMP}.json"

# Collect git state
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
GIT_DIFF_STAT=$(git diff --stat 2>/dev/null | tail -1 || echo "no changes")
RAW_MODIFIED=$(git diff --name-only 2>/dev/null | head -20 || echo "")
RAW_COMMITS=$(git log --oneline -5 2>/dev/null || echo "")

# Build proper JSON arrays from newline-delimited lists
MODIFIED_FILES=$(build_json_array "$RAW_MODIFIED")
RECENT_COMMITS=$(build_json_array "$RAW_COMMITS")

# Collect custom notes if they exist
NOTES=""
NOTES_FILE="${PROJECT_ROOT}/.claude/precompact-notes.md"
if [ -f "$NOTES_FILE" ]; then
  NOTES=$(cat "$NOTES_FILE" | tr '\n' ' ' | head -c 500)
fi

# Escape string fields for safe JSON embedding
GIT_BRANCH_ESC=$(escape_json_string "$GIT_BRANCH")
GIT_DIFF_STAT_ESC=$(escape_json_string "$GIT_DIFF_STAT")
NOTES_ESC=$(escape_json_string "$NOTES")
AGENT_NAME_ESC=$(escape_json_string "${CLAUDE_AGENT_NAME:-unknown}")

# Write structured JSON snapshot
cat > "$SNAPSHOT_FILE" << SNAPSHOT_EOF
{
  "timestamp": "${TIMESTAMP}",
  "git_branch": "${GIT_BRANCH_ESC}",
  "git_diff_summary": "${GIT_DIFF_STAT_ESC}",
  "modified_files": ${MODIFIED_FILES},
  "recent_commits": ${RECENT_COMMITS},
  "custom_notes": "${NOTES_ESC}",
  "agent_name": "${AGENT_NAME_ESC}"
}
SNAPSHOT_EOF

echo "State snapshot saved to ${SNAPSHOT_FILE}"

# Never block compaction
exit 0
