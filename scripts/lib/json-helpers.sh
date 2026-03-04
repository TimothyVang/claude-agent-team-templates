#!/bin/bash
# json-helpers.sh - Shared JSON utilities for agent-team hook scripts
# Source this file: source "$(cd "$(dirname "$0")" && pwd)/lib/json-helpers.sh"
#
# Provides safe JSON string construction without jq dependency.
# All functions write to stdout; callers capture via $(...).

# --- escape_json_string "$value" ---
# Escapes a string for safe embedding in a JSON value.
# Handles: backslash, double-quote, newline, carriage return, tab, control chars.
#
# Usage:
#   SAFE=$(escape_json_string "$RAW_VALUE")
#   echo "{\"key\":\"$SAFE\"}"
escape_json_string() {
    local input="${1:-}"
    # Process character by character via sed pipeline:
    # 1. Escape backslashes first (must be first to avoid double-escaping)
    # 2. Escape double quotes
    # 3. Escape control characters
    printf '%s' "$input" \
        | sed \
            -e 's/\\/\\\\/g' \
            -e 's/"/\\"/g' \
            -e 's/\t/\\t/g' \
        | tr '\n' '\036' \
        | sed 's/\x1e/\\n/g' \
        | tr '\r' '\036' \
        | sed 's/\x1e/\\r/g'
}

# --- build_json_array "$newline_delimited_list" ---
# Converts a newline-delimited list of strings into a JSON array.
# Each element is escaped via escape_json_string.
# Empty input produces "[]".
#
# Usage:
#   FILES=$(git diff --name-only)
#   JSON_ARRAY=$(build_json_array "$FILES")
#   # => ["src/foo.ts","src/bar.ts"]
build_json_array() {
    local input="${1:-}"

    # Handle empty input
    if [ -z "$input" ]; then
        printf '[]'
        return
    fi

    local result="["
    local first=true
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        local escaped
        escaped=$(escape_json_string "$line")
        if [ "$first" = true ]; then
            first=false
        else
            result="$result,"
        fi
        result="$result\"$escaped\""
    done <<< "$input"

    # If no non-empty lines were found
    if [ "$first" = true ]; then
        printf '[]'
        return
    fi

    result="$result]"
    printf '%s' "$result"
}
