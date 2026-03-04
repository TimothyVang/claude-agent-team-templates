#!/bin/bash
# PreToolUse security check — blocks path traversal and sensitive file access
# Matches: Read, Edit, Write tools
# Referenced by settings-template.json PreToolUse hook.
# See reference/security-guardrails.md Section 2-3 for full context.

set -euo pipefail

INPUT="${CLAUDE_TOOL_INPUT:-}"
FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"

# Combine both sources for checking
CHECK_TEXT="${INPUT} ${FILE_PATH}"

# --- Path Traversal Detection (OWASP AI Agent #3) ---
if echo "$CHECK_TEXT" | grep -qE '(\.\./|\.\.\\)'; then
  echo "BLOCKED: Path traversal detected (../ pattern)."
  echo "All file paths must be absolute or relative to the project root without '../'."
  exit 1
fi

# --- Sensitive File Blocking ---
SENSITIVE_PATTERNS=(
  '\.env$'
  '\.env\.'
  'credentials\.'
  'secrets\.'
  '\.pem$'
  '\.key$'
  '\.p12$'
  'id_rsa'
  'id_ed25519'
  '\.keystore$'
  '\.jks$'
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
  if echo "$CHECK_TEXT" | grep -qiE "$pattern"; then
    echo "BLOCKED: Access to sensitive file matching pattern: $pattern"
    echo "If this is intentional, access the file manually outside Claude Code."
    exit 1
  fi
done

exit 0
