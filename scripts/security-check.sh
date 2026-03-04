#!/bin/bash
# PreToolUse security check — blocks dangerous Bash commands
# Referenced by settings-template.json PreToolUse hook.
# See reference/security-guardrails.md for full OWASP context.

set -euo pipefail

INPUT="${CLAUDE_TOOL_INPUT:-}"

# Dangerous patterns (exit 1 = block)
BLOCKED_PATTERNS=(
  'rm -rf /'
  'rm -rf ~'
  'DROP TABLE'
  'DROP DATABASE'
  'git push.*--force.*main'
  'git push.*--force.*master'
  'chmod 777'
  'curl.*|.*sh'
  'wget.*|.*bash'
  '> /dev/sd'
  'mkfs\.'
  'dd if='
  ':(){ :|:& };:'
  'kill -9 1'
  'shutdown'
  'reboot'
  'git push.*-f '
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$INPUT" | grep -qiE "$pattern"; then
    echo "BLOCKED: Dangerous command detected matching pattern: $pattern"
    echo "If this is intentional, run the command manually outside Claude Code."
    exit 1
  fi
done

exit 0
