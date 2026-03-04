#!/bin/bash
# circuit-breaker.sh - State machine tracking consecutive tool failures
#
# States: CLOSED (normal) → OPEN (tripped) → HALF-OPEN (testing) → CLOSED/OPEN
# Transitions:
#   CLOSED  → OPEN      after 3 consecutive failures
#   OPEN    → HALF-OPEN after 60s cooldown
#   HALF-OPEN → CLOSED  on success
#   HALF-OPEN → OPEN    on failure
#
# State format: flat-file key=value (one line per field)
#   <tool>.state=CLOSED|OPEN|HALF-OPEN
#   <tool>.failures=<int>
#   <tool>.opened_at=<epoch>
#
# Commands:
#   record-failure <tool>   Record a tool failure
#   record-success <tool>   Record a tool success
#   check <tool>            Check if tool is allowed (exit 0=allowed, 1=blocked)
#   status                  Print all circuit states
#
# Usage:
#   ./circuit-breaker.sh record-failure bash
#   ./circuit-breaker.sh check bash || echo "Tool blocked, skipping"

set -euo pipefail

# Cross-platform temp directory
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TMPDIR="${TMPDIR:-${PROJECT_ROOT}/.claude/tmp}"
mkdir -p "$TMPDIR"

STATE_FILE="${PROJECT_ROOT}/.claude/circuit-breaker-state.txt"
FAILURE_THRESHOLD=3
COOLDOWN_SECS=60

mkdir -p "$(dirname "$STATE_FILE")"

# Initialize state file if absent
if [ ! -f "$STATE_FILE" ]; then
    : > "$STATE_FILE"
fi

COMMAND="${1:-status}"
TOOL="${2:-}"
NOW=$(date +%s)

# --- Read a field from the flat-file state ---
# Usage: read_field <tool> <field>
# Returns the value or empty string if not found
read_field() {
    local tool="$1" field="$2"
    grep "^${tool}\\.${field}=" "$STATE_FILE" 2>/dev/null \
        | head -1 \
        | sed "s/^${tool}\\.${field}=//" \
        || echo ""
}

# --- Write/update tool state in flat file ---
# Usage: write_state <tool> <state> <failures> <opened_at>
write_state() {
    local tool="$1" state="$2" failures="$3" opened_at="$4"
    local tmp_file="${STATE_FILE}.tmp"

    # Remove existing entries for this tool, then append new ones
    grep -v "^${tool}\\." "$STATE_FILE" > "$tmp_file" 2>/dev/null || : > "$tmp_file"
    echo "${tool}.state=${state}" >> "$tmp_file"
    echo "${tool}.failures=${failures}" >> "$tmp_file"
    echo "${tool}.opened_at=${opened_at}" >> "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
}

case "$COMMAND" in
    record-failure)
        [ -z "$TOOL" ] && { echo "[ERROR] Usage: $0 record-failure <tool>"; exit 1; }
        STATE=$(read_field "$TOOL" "state")
        STATE="${STATE:-CLOSED}"
        FAILURES=$(read_field "$TOOL" "failures")
        FAILURES="${FAILURES:-0}"
        # Validate FAILURES is numeric before arithmetic
        if ! echo "$FAILURES" | grep -qE '^[0-9]+$'; then
            FAILURES=0
        fi
        FAILURES=$(( FAILURES + 1 ))
        if [ "$FAILURES" -ge "$FAILURE_THRESHOLD" ] || [ "$STATE" = "HALF-OPEN" ]; then
            write_state "$TOOL" "OPEN" "$FAILURES" "$NOW"
            echo "[CIRCUIT] $TOOL → OPEN (${FAILURES} consecutive failures)"
        else
            write_state "$TOOL" "CLOSED" "$FAILURES" "0"
            echo "[CIRCUIT] $TOOL failure #${FAILURES}/${FAILURE_THRESHOLD}"
        fi
        ;;

    record-success)
        [ -z "$TOOL" ] && { echo "[ERROR] Usage: $0 record-success <tool>"; exit 1; }
        STATE=$(read_field "$TOOL" "state")
        STATE="${STATE:-CLOSED}"
        if [ "$STATE" = "HALF-OPEN" ]; then
            write_state "$TOOL" "CLOSED" "0" "0"
            echo "[CIRCUIT] $TOOL → CLOSED (recovered)"
        else
            write_state "$TOOL" "CLOSED" "0" "0"
            echo "[CIRCUIT] $TOOL OK"
        fi
        ;;

    check)
        [ -z "$TOOL" ] && { echo "[ERROR] Usage: $0 check <tool>"; exit 1; }
        STATE=$(read_field "$TOOL" "state")
        STATE="${STATE:-CLOSED}"
        OPENED_AT=$(read_field "$TOOL" "opened_at")
        OPENED_AT="${OPENED_AT:-0}"
        # Validate OPENED_AT is numeric
        if ! echo "$OPENED_AT" | grep -qE '^[0-9]+$'; then
            OPENED_AT=0
        fi
        if [ "$STATE" = "OPEN" ]; then
            ELAPSED=$(( NOW - OPENED_AT ))
            if [ "$ELAPSED" -ge "$COOLDOWN_SECS" ]; then
                write_state "$TOOL" "HALF-OPEN" "0" "$OPENED_AT"
                echo "[CIRCUIT] $TOOL → HALF-OPEN (cooldown elapsed, test allowed)"
                exit 0
            else
                REMAINING=$(( COOLDOWN_SECS - ELAPSED ))
                echo "[CIRCUIT] $TOOL OPEN — blocked for ${REMAINING}s more"
                exit 1
            fi
        fi
        echo "[CIRCUIT] $TOOL ALLOWED (state: $STATE)"
        exit 0
        ;;

    status)
        echo "=== Circuit Breaker Status ==="
        echo "State file: $STATE_FILE"
        if [ -s "$STATE_FILE" ]; then
            cat "$STATE_FILE"
        else
            echo "(no tool states recorded)"
        fi
        echo ""
        ;;

    *)
        echo "Usage: $0 {record-failure|record-success|check|status} [tool]"
        exit 1
        ;;
esac
