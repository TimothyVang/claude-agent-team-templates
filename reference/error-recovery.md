# Error Recovery Reference

> Deep-dive companion to [AGENT-TEAM-PLANNING-TEMPLATE.md](../AGENT-TEAM-PLANNING-TEMPLATE.md) Section 6: Error Recovery & Failure Handling.
> See also: [role-prompt-patterns.md](./role-prompt-patterns.md) for escalation message formats.

---

## Error Classification (12 Categories)

Every failure an agent team can encounter falls into one of these categories. Each entry includes a concrete example, how to detect it, the recommended recovery tier, and a hook code snippet.

### Recovery Tier Reference

| Tier | Action | Token Cost | Use When |
|------|--------|-----------|----------|
| T1 - Retry | Retry same action (max 2x) | Low | Transient failures |
| T2 - Fallback | Try alternative approach | Medium | Tool/method unavailable |
| T3 - Escalate | Message lead or human | Low | Ambiguity, permissions, drift |
| T4 - Abort | Stop task, preserve state | None | Unrecoverable or dangerous |

---

### 1. Input Validation Failure

**What**: Task description is ambiguous, missing required fields, or contains contradictory instructions.

**Example**: Task says "refactor the auth module" but no file paths are specified and multiple auth modules exist.

**Detection**: Agent asks clarifying questions in first 2 tool calls instead of making progress. Output contains phrases like "I'm not sure which..." or "Could you clarify...".

**Recovery Tier**: T3 - Escalate to lead with specific questions.

```bash
# Hook: detect spinning on ambiguous input (verify-task.sh)
if echo "$TASK_OUTPUT" | grep -qiE "(not sure|unclear|which (one|file)|please clarify)"; then
  echo "WARN: Agent appears confused by task input. Escalating."
  echo "feedback: Task description may be ambiguous. Please clarify scope." >&2
  exit 2  # feedback + continue
fi
```

### 2. Tool Not Found

**What**: Agent attempts to call a tool that is not available in its current environment.

**Example**: Agent tries to use `mcp__github__create_pr` but the GitHub MCP server is not configured.

**Detection**: Tool call returns error containing "tool not found", "unknown tool", or "not available".

**Recovery Tier**: T2 - Fallback to alternative tool (e.g., use `gh` CLI via Bash instead).

```bash
# Hook: detect tool-not-found and suggest alternatives (post-tool-use.sh)
if echo "$TOOL_ERROR" | grep -qiE "(tool not found|unknown tool|not available)"; then
  echo "feedback: Tool unavailable. Try Bash with CLI equivalent." >&2
  exit 2
fi
```

### 3. Parameter Mismatch

**What**: Correct tool, wrong arguments — missing required params, wrong types, or invalid values.

**Example**: Calling `Edit` with `old_string` that doesn't exist in the file (non-unique match or stale content).

**Detection**: Tool returns error about missing/invalid parameters. Edit tool returns "old_string not found in file".

**Recovery Tier**: T1 - Retry after reading the file to get current content.

```bash
# Hook: detect edit failures and force re-read (post-tool-use.sh)
if [ "$TOOL_NAME" = "Edit" ] && echo "$TOOL_ERROR" | grep -q "old_string"; then
  echo "feedback: Edit failed — file content changed. Re-read the file before retrying." >&2
  exit 2
fi
```

### 4. API Failure

**What**: Upstream API (GitHub, npm registry, external service) returns 4xx/5xx error.

**Example**: `gh pr create` fails with "422 Unprocessable Entity" because the branch has no commits ahead of base.

**Detection**: HTTP status codes >= 400 in tool output. Error messages from CLI tools referencing API responses.

**Recovery Tier**: T1 for 5xx (retry once), T2 for 4xx (fix request), T3 for persistent failures.

```bash
# Hook: classify API errors (post-tool-use.sh)
if echo "$TOOL_OUTPUT" | grep -qE "HTTP (5[0-9]{2})"; then
  echo "feedback: Server error — retry once, then escalate." >&2
  exit 2
elif echo "$TOOL_OUTPUT" | grep -qE "HTTP (4[0-9]{2})"; then
  echo "feedback: Client error — check parameters and fix request." >&2
  exit 2
fi
```

### 5. Auth/Permission Denied

**What**: Agent lacks permissions to perform the requested operation.

**Example**: Trying to push to a protected branch, or running `rm` in default permission mode without user approval.

**Detection**: Errors containing "permission denied", "403", "protected branch", or user denying a tool prompt.

**Recovery Tier**: T3 - Escalate to human. Never attempt to bypass permissions.

```bash
# Hook: detect permission issues (post-tool-use.sh)
if echo "$TOOL_ERROR" | grep -qiE "(permission denied|403|protected branch|access denied)"; then
  echo "feedback: Permission denied. Escalate to human — do NOT retry." >&2
  exit 2
fi
```

### 6. Timeout

**What**: Operation exceeded its time limit (tool timeout, build timeout, test suite hang).

**Example**: `npm test` hangs for 120+ seconds because a test has an unresolved promise.

**Detection**: Tool returns timeout error. Bash command killed after timeout period.

**Recovery Tier**: T2 - Run with reduced scope (single test file instead of full suite), then T3 if still failing.

```bash
# Hook: detect timeouts and suggest scope reduction (post-tool-use.sh)
if echo "$TOOL_ERROR" | grep -qiE "(timeout|timed out|killed|SIGTERM)"; then
  echo "feedback: Operation timed out. Try reducing scope or running a subset." >&2
  exit 2
fi
```

### 7. Network Failure

**What**: DNS resolution failure, connection refused, or network unreachable.

**Example**: `npm install` fails with `ENOTFOUND registry.npmjs.org`.

**Detection**: Errors containing "ENOTFOUND", "ECONNREFUSED", "network unreachable", "connection reset".

**Recovery Tier**: T1 - Retry once after brief pause. T4 if persistent (environment problem, not agent problem).

```bash
# Hook: detect network issues (post-tool-use.sh)
if echo "$TOOL_ERROR" | grep -qiE "(ENOTFOUND|ECONNREFUSED|network|connection reset)"; then
  echo "feedback: Network error — retry once. If persistent, escalate as environment issue." >&2
  exit 2
fi
```

### 8. Rate Limit

**What**: API rate limit exceeded (GitHub, npm, AI model API).

**Example**: `gh api` returns "403 rate limit exceeded" after too many requests.

**Detection**: HTTP 429 status, or error messages containing "rate limit", "too many requests", "quota exceeded".

**Recovery Tier**: T1 - Wait and retry (respect `Retry-After` header). T3 if critical path is blocked.

```bash
# Hook: detect rate limiting (post-tool-use.sh)
if echo "$TOOL_OUTPUT" | grep -qiE "(429|rate limit|too many requests|quota exceeded)"; then
  echo "feedback: Rate limited. Wait before retrying. Check Retry-After header." >&2
  exit 2
fi
```

### 9. Malformed Output

**What**: Agent produces output that cannot be parsed or does not match expected format.

**Example**: Agent asked to produce JSON outputs invalid JSON with trailing commas. Or produces a code block but forgets the closing fence.

**Detection**: JSON parse errors, schema validation failures, format check in verification hook.

**Recovery Tier**: T1 - Retry with explicit format instructions. T2 - Use a structured output tool.

```bash
# Hook: validate JSON output (verify-task.sh)
if [ -f "$OUTPUT_FILE" ]; then
  if ! python3 -c "import json; json.load(open('$OUTPUT_FILE'))" 2>/dev/null; then
    echo "feedback: Output is not valid JSON. Re-generate with strict JSON format." >&2
    exit 2
  fi
fi
```

### 10. Context Exhaustion

**What**: Agent's context window is full — can no longer process new information or maintain coherence.

**Example**: Agent has read 50+ large files and responses become incoherent, repetitive, or start hallucinating file contents.

**Detection**: Responses reference non-existent code, repeat earlier statements verbatim, or lose track of task state. System returns context limit warnings.

**Recovery Tier**: T4 - Abort current agent, spawn fresh agent with compressed context (just the task + key findings so far).

```bash
# Hook: detect context exhaustion signals (post-tool-use.sh)
TOOL_CALL_COUNT=$(cat /tmp/agent_tool_count_${AGENT_ID} 2>/dev/null || echo 0)
TOOL_CALL_COUNT=$((TOOL_CALL_COUNT + 1))
echo "$TOOL_CALL_COUNT" > /tmp/agent_tool_count_${AGENT_ID}
if [ "$TOOL_CALL_COUNT" -gt 100 ]; then
  echo "WARN: Agent has made $TOOL_CALL_COUNT tool calls. Risk of context exhaustion." >&2
  echo "feedback: High tool call count — consider completing current subtask and summarizing." >&2
  exit 2
fi
```

### 11. Silent Failure

**What**: No error is thrown, but the result is wrong. The most dangerous category.

**Example**: Agent "fixes" a bug by deleting the test that catches it. Or edits the wrong file (correct filename, wrong directory).

**Detection**: Verification hooks that check correctness, not just absence of errors. Peer review via observer mesh. Test suite runs after each change.

**Recovery Tier**: T3 - Escalate for review. Prevention is far more effective than recovery.

```bash
# Hook: verify edits touched expected files only (verify-task.sh)
CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null)
for file in $CHANGED_FILES; do
  if ! echo "$EXPECTED_FILES" | grep -q "$file"; then
    echo "WARN: Unexpected file modified: $file" >&2
    echo "feedback: You modified $file which is outside your task scope. Revert and explain." >&2
    exit 2
  fi
done
```

### 12. Goal Drift

**What**: Agent gradually moves away from the original task — refactoring when asked to fix a bug, adding features when asked to write tests.

**Example**: Asked to "fix the login timeout bug", agent starts refactoring the entire auth module for "better maintainability".

**Detection**: Diff size disproportionate to task scope. Files modified outside the task's stated scope. Agent messages shift topic.

**Recovery Tier**: T3 - Escalate. Lead reviews diff against original task description.

```bash
# Hook: detect scope creep via diff size (verify-task.sh)
DIFF_LINES=$(git diff --stat HEAD~1 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
MAX_EXPECTED_LINES=${MAX_DIFF_LINES:-200}
if [ "${DIFF_LINES:-0}" -gt "$MAX_EXPECTED_LINES" ]; then
  echo "WARN: Diff is $DIFF_LINES lines — expected max $MAX_EXPECTED_LINES." >&2
  echo "feedback: Large diff detected. Verify changes are within task scope." >&2
  exit 2
fi
```

---

## Undo-and-Retry Git Workflow

When an agent needs to completely redo a failed attempt, use this safe git-based undo pattern:

```bash
# 1. Stash any uncommitted work-in-progress
git stash push -m "WIP: agent retry backup"

# 2. Soft reset the failed commit (keeps changes staged)
git reset --soft HEAD~1

# 3. Unstage everything
git reset HEAD .

# 4. Discard the failed changes
git checkout -- .

# 5. Agent retries the task from clean state
# ... (agent does work) ...

# 6. After successful retry, recover any stashed WIP if needed
git stash list
git stash pop  # only if stash contains useful partial work
```

**Key rules**:
- Always `--soft` reset first to avoid data loss
- Never `--hard` reset without lead approval
- Stash before reset so nothing is permanently lost
- Limit to 2 retry cycles (Stripe's "max 2 CI rounds" rule)

---

## Observer Mesh Pattern

Each agent monitors one peer for accuracy. This creates a lightweight review loop without requiring a dedicated reviewer agent.

```
┌──────────┐  observes  ┌──────────────┐  observes  ┌─────────────┐
│ Observer  │ ────────── │ Investigator │ ────────── │ Implementer │
└──────────┘            └──────────────┘            └─────────────┘
      ▲                                                     │
      └─────────────────── observes ────────────────────────┘
```

**How it works**:
1. After Agent A marks a task complete, Agent B (its observer) receives a notification
2. Agent B runs a quick verification: reads the output, checks against acceptance criteria
3. If valid: Agent B sends `[TYPE: status] Peer review passed` to lead
4. If invalid: Agent B sends `[TYPE: finding] Issue found: <description>` to Agent A

**Implementation via hooks**:
```bash
# In verify-task.sh — notify observer when task completes
OBSERVER_MAP='{"implementer":"investigator","investigator":"observer","observer":"implementer"}'
CURRENT_ROLE="$AGENT_ROLE"
OBSERVER=$(echo "$OBSERVER_MAP" | python3 -c "
import json,sys
m=json.load(sys.stdin)
print(m.get('$CURRENT_ROLE','lead'))
")
echo "notify:$OBSERVER: Task completed by $CURRENT_ROLE — please verify output."
```

**Rules**:
- Observers check output only — they do not modify files
- Observer review should take < 5 tool calls
- Disagreements escalate to the lead, not back-and-forth between peers

---

## Confidence-Based Escalation

Agents self-assess confidence before taking action. This reduces unnecessary human interruptions while catching risky moves.

| Confidence | Action | Example |
|-----------|--------|---------|
| > 90% | Auto-proceed | Simple rename, adding a test for existing function |
| 80-90% | Async review | Proceed but flag for lead review after completion |
| 70-80% | Require approval | Message lead with plan, wait for explicit approval |
| < 70% | Escalate to human | Stop work, summarize findings, request human guidance |

**Implementation in agent prompts**:
```markdown
Before each significant action, assess your confidence (0-100%):
- How certain are you this is the RIGHT action? (not just that it will succeed)
- Have you verified the current state of the files you will modify?
- Does this action stay within your task scope?

If confidence < 70%, STOP and message the lead:
[FROM: your-role] [TO: lead] [TYPE: blocker]
Subject: Low confidence on <action>
Confidence: <X>%
Reason: <why you are uncertain>
Options: <2-3 possible approaches>
```

**Confidence modifiers** (subtract from base confidence):
- First time working in this area of the codebase: -15%
- No tests covering the changed code: -10%
- Modifying shared/core utilities: -10%
- Multiple files need coordinated changes: -5%
- Contradictory information in codebase: -20%

---

## Quick Reference: Error → Recovery Decision Tree

```
Error occurs
  ├── Is it transient? (network, timeout, rate limit)
  │     ├── Yes → T1: Retry once
  │     └── Still failing → T3: Escalate
  ├── Is the tool/method wrong?
  │     └── Yes → T2: Try alternative approach
  ├── Is it a permission issue?
  │     └── Yes → T3: Escalate (never bypass)
  ├── Is the agent confused or drifting?
  │     └── Yes → T3: Escalate with context
  └── Is the environment broken?
        └── Yes → T4: Abort, preserve state
```
