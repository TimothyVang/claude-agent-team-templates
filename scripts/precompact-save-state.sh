#!/bin/bash
# PreCompact Hook: Save critical state before context auto-compaction
# Preserves task context, git state, and active files so agents can
# recover smoothly after compaction reduces their conversation history.

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SNAPSHOT_DIR="${PROJECT_ROOT}/.claude/compaction-snapshots"
mkdir -p "$SNAPSHOT_DIR"

TIMESTAMP=$(date +%Y%m%dT%H%M%S)
SNAPSHOT_FILE="${SNAPSHOT_DIR}/${TIMESTAMP}.json"

# Collect git state
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
GIT_DIFF_STAT=$(git diff --stat 2>/dev/null | tail -1 || echo "no changes")
MODIFIED_FILES=$(git diff --name-only 2>/dev/null | head -20 | tr '\n' ',' | sed 's/,$//')
RECENT_COMMITS=$(git log --oneline -5 2>/dev/null | tr '\n' '|' | sed 's/|$//')

# Collect custom notes if they exist
NOTES=""
NOTES_FILE="${PROJECT_ROOT}/.claude/precompact-notes.md"
if [ -f "$NOTES_FILE" ]; then
  NOTES=$(cat "$NOTES_FILE" | tr '\n' ' ' | head -c 500)
fi

# Write structured JSON snapshot
cat > "$SNAPSHOT_FILE" << SNAPSHOT_EOF
{
  "timestamp": "${TIMESTAMP}",
  "git_branch": "${GIT_BRANCH}",
  "git_diff_summary": "${GIT_DIFF_STAT}",
  "modified_files": "${MODIFIED_FILES}",
  "recent_commits": "${RECENT_COMMITS}",
  "custom_notes": "${NOTES}",
  "agent_name": "${CLAUDE_AGENT_NAME:-unknown}"
}
SNAPSHOT_EOF

echo "State snapshot saved to ${SNAPSHOT_FILE}"

# Never block compaction
exit 0
