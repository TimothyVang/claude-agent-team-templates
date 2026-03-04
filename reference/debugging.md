# Debugging Agent Teams

> Practical guide for diagnosing stuck agents, failed tasks, and coordination issues.
> Companion to [AGENT-TEAM-PLANNING-TEMPLATE.md](../AGENT-TEAM-PLANNING-TEMPLATE.md) Section 8: Observability & Monitoring.

---

## Reading agent-team-log.jsonl

The observability hook writes one JSON object per line to `.claude/agent-team-log.jsonl`.

**Location**: `<project-root>/.claude/agent-team-log.jsonl`

**Format**: One JSON object per line (JSONL). Each entry contains:
```jsonl
{"timestamp":"2026-03-03T10:00:00Z","event":"TaskCompleted","agent":"implementer","status":"success","files":["src/auth.ts"]}
{"timestamp":"2026-03-03T10:05:00Z","event":"PostToolUse","agent":"tester","status":"failure","tool":"Bash","error":"test failed"}
```

**Common queries**:

```bash
# Find all failures
grep '"status":"failure"' .claude/agent-team-log.jsonl

# Filter by agent role
grep '"agent":"implementer"' .claude/agent-team-log.jsonl

# Find task completions
grep '"event":"TaskCompleted"' .claude/agent-team-log.jsonl

# Count events by type
grep -oP '"event":"[^"]+"' .claude/agent-team-log.jsonl | sort | uniq -c | sort -rn

# Get failures in the last 10 minutes (requires jq)
jq -r 'select(.status == "failure")' .claude/agent-team-log.jsonl | tail -20

# Find errors for a specific tool
grep '"tool":"Bash"' .claude/agent-team-log.jsonl | grep '"status":"failure"'
```

---

## Checking Task State

Task state lives in the `.claude/tasks/` directory.

```bash
# List all tasks
ls .claude/tasks/

# View a specific task
cat .claude/tasks/<task-id>.json

# Find incomplete tasks
grep -l '"status":"in_progress"' .claude/tasks/*.json

# Find blocked tasks
grep -l '"blockedBy"' .claude/tasks/*.json
```

---

## Diagnosing Stuck Teams

### Idle Agent (> 5 minutes without action)

**Indicators**:
- No new entries in `agent-team-log.jsonl` for > 5 minutes
- Task status remains `in_progress` without file changes
- Agent's last message was a question with no reply

**Diagnosis steps**:
1. Check the agent's last log entry: `grep '"agent":"<name>"' .claude/agent-team-log.jsonl | tail -5`
2. Check if the agent is blocked: `grep '"blockedBy"' .claude/tasks/*.json`
3. Check for permission prompts — the agent may be waiting for user approval

**Recovery**: Send a direct message to the agent with course correction, or reassign the task.

### Recurring Errors (Same failure 3+ times)

**Indicators**:
- `agent-team-log.jsonl` shows the same error repeating
- Circuit breaker state shows OPEN (see below)
- Task retry count is at maximum

**Diagnosis steps**:
1. Extract the repeating error: `grep '"status":"failure"' .claude/agent-team-log.jsonl | tail -10`
2. Check if it's the same root cause or cascading failures
3. Verify the environment (dependencies installed, services running)

**Recovery**: Apply error recovery tier 2 (undo-and-retry) or tier 5 (human escalation). See `reference/error-recovery.md`.

### Context Exhaustion

**Indicators**:
- Agent responses become incoherent or repetitive
- Agent re-reads files it already read
- Tool call count exceeds 100 (logged by hooks)
- Agent loses track of task state or acceptance criteria

**Diagnosis steps**:
1. Count tool calls: `grep -c '"agent":"<name>"' .claude/agent-team-log.jsonl`
2. Check for repeated file reads: `grep '"agent":"<name>"' .claude/agent-team-log.jsonl | grep '"tool":"Read"' | grep -oP '"files":\[[^\]]+\]' | sort | uniq -c | sort -rn`
3. Review compaction snapshots (see below)

**Recovery**: Checkpoint recovery (tier 4) — spawn a fresh agent with a compressed summary of work done so far.

---

## Circuit Breaker State

The circuit breaker tracks consecutive tool failures per tool type. State is stored in `.claude/circuit-breaker-state.txt`.

**Format**: Flat file with `tool.field=value` lines:
```
Bash.state=CLOSED
Bash.failures=0
Bash.lastFailure=
Edit.state=OPEN
Edit.failures=5
Edit.lastFailure=2026-03-03T10:05:00Z
```

**States**:
| State | Meaning | Action |
|-------|---------|--------|
| CLOSED | Normal operation, failures below threshold | Continue normally |
| OPEN | Too many consecutive failures, tool is blocked | Wait for cooldown or human intervention |
| HALF-OPEN | Cooldown expired, allowing one test call | If test succeeds → CLOSED; if fails → OPEN |

**Reading the state**:
```bash
# View current state
cat .claude/circuit-breaker-state.txt

# Check if any tool is in OPEN state
grep 'state=OPEN' .claude/circuit-breaker-state.txt

# Reset circuit breaker (manual recovery)
rm .claude/circuit-breaker-state.txt
```

---

## Compaction Snapshots

Before auto-compaction, the `precompact-save-state.sh` hook saves a snapshot to `.claude/compaction-snapshots/`.

**Location**: `.claude/compaction-snapshots/*.json`

Each snapshot captures:
- Git diff at the time of compaction
- List of modified files
- Current task context
- Timestamp

```bash
# List snapshots
ls -la .claude/compaction-snapshots/

# View the most recent snapshot
cat .claude/compaction-snapshots/$(ls -t .claude/compaction-snapshots/ | head -1)

# Find snapshots for a specific agent (if agent ID is in filename)
ls .claude/compaction-snapshots/ | grep "<agent-name>"
```

---

## Common Recovery Actions

### Clear retry state files
```bash
# Remove retry counters (resets backoff timers)
rm -f /tmp/agent_tool_count_* /tmp/agent_retry_*
```

### Reset circuit breaker
```bash
# Reset all circuit breakers to CLOSED
rm -f .claude/circuit-breaker-state.txt
```

### Restart a stuck agent
1. Note the agent's current task and progress from the log
2. Mark the task as `pending` (unassign the agent)
3. Spawn a new agent with a compressed summary of what was already done
4. Include in the spawn prompt: files already modified, decisions already made, and what remains

### Force-complete a blocking task
If a blocker task is stuck and downstream tasks are waiting:
1. Review what's done vs. what's missing
2. If acceptable, mark the task as `completed` manually
3. Downstream tasks will unblock automatically
4. Create a follow-up task for the remaining work

### Recover from compaction data loss
If an agent loses context after auto-compaction:
1. Check the latest compaction snapshot: `ls -t .claude/compaction-snapshots/ | head -1`
2. Extract key state from the snapshot (modified files, task context)
3. Send the agent a message with the recovered context
