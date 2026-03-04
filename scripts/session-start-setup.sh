#!/bin/bash
# session-start-setup.sh - Environment setup for SessionStart hook
# Runs at the start of every Claude Code session to ensure the environment is ready.
# This is the first "deterministic" step in the Blueprint pattern.
#
# Usage in settings.json:
#   "SessionStart": [{ "hooks": [{ "type": "command", "command": "./agent-team-templates/scripts/session-start-setup.sh" }] }]

set -euo pipefail

# Cross-platform temp directory
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TMPDIR="${TMPDIR:-${PROJECT_ROOT}/.claude/tmp}"
mkdir -p "$TMPDIR"

echo "=== Session Start Setup ==="

# 1. Verify git is clean (warn if dirty)
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "[WARN] Working directory has uncommitted changes"
fi

# 2. Install dependencies if needed
if [ -f "$PROJECT_ROOT/package.json" ]; then
    if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
        echo "[SETUP] Installing npm dependencies..."
        cd "$PROJECT_ROOT" && npm install --silent 2>/dev/null || echo "[WARN] npm install failed"
    fi
elif [ -f "$PROJECT_ROOT/requirements.txt" ]; then
    echo "[INFO] Python project detected. Ensure venv is active."
elif [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
    echo "[INFO] Python project detected (pyproject.toml). Ensure venv is active."
fi

# 3. Check for required environment variables
if [ -f "$PROJECT_ROOT/.env.example" ]; then
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        echo "[WARN] .env file missing. Copy from .env.example and fill in values."
    fi
fi

# 4. Verify key tools are available
for tool in git node npm; do
    if command -v "$tool" &>/dev/null; then
        echo "[OK] $tool: $(command -v $tool)"
    fi
done

# 5. Display branch info
BRANCH=$(git branch --show-current 2>/dev/null || echo "not a git repo")
echo "[INFO] Current branch: $BRANCH"

echo "=== Setup Complete ==="
exit 0
