# Delegate Mode Reference

> Deep-dive companion to [AGENT-TEAM-PLANNING-TEMPLATE.md](../AGENT-TEAM-PLANNING-TEMPLATE.md) Section 3.3: Advanced Agent Controls.
> See also: [role-prompt-patterns.md](./role-prompt-patterns.md) for how roles map to permission modes.

---

## What is Delegate Mode

Delegate mode gives an agent broader autonomy by reducing permission prompts. When enabled, the agent can execute tools (file edits, bash commands) without requiring user approval for each action.

**Toggle**: Press `Shift+Tab` in the Claude Code terminal to cycle through permission modes.

**Effect**: The agent operates more independently, completing multi-step tasks without pausing for confirmation at each step. This dramatically improves throughput for trusted, well-scoped tasks.

---

## When to Enable Delegate Mode

Enable delegate mode when **all** of the following are true:

- **Task is well-scoped**: Clear acceptance criteria, defined file boundaries
- **Environment is safe**: Development/staging, not production
- **Codebase is mature**: Good test coverage catches mistakes automatically
- **Agent role is trusted**: Implementer working on assigned files, not exploring unknown code
- **Rollback is easy**: Changes are committed incrementally, `git reset` can undo any step

**Good candidates**:
- Writing tests for existing functions
- Implementing a feature from a detailed spec
- Running a migration script across multiple files
- Formatting, linting, or mechanical refactors

---

## When to Avoid Delegate Mode

Keep default (permission-prompting) mode when **any** of the following are true:

- **New or unfamiliar codebase**: Agent may make wrong assumptions
- **Destructive operations possible**: Database migrations, file deletions, force-pushes
- **Production environment**: Any change could affect live users
- **Ambiguous task**: Requirements are vague or agent might need to make judgment calls
- **Shared files**: Multiple agents or humans might edit the same files
- **Security-sensitive code**: Auth, payments, encryption, secrets management

---

## Exit Code 2 Pattern

Hooks use exit codes to control agent behavior. Exit code 2 is the key mechanism for giving feedback to an agent without blocking its execution.

| Exit Code | Effect |
|-----------|--------|
| 0 | Success — agent continues normally |
| 1 | Block — tool call is denied, agent must stop or try something else |
| 2 | Feedback — message is sent to agent AND agent keeps working |

**Full hook example showing both paths**:

```bash
#!/bin/bash
# post-edit-hook.sh — runs after every Edit tool call

EDITED_FILE="$1"
AGENT_ROLE="${AGENT_ROLE:-unknown}"

# Block path: prevent editing files outside scope
if [[ "$EDITED_FILE" == *"node_modules"* ]] || [[ "$EDITED_FILE" == *".env"* ]]; then
  echo "BLOCKED: Cannot edit $EDITED_FILE — this file is off-limits." >&2
  exit 1  # Block the edit entirely
fi

# Feedback path: warn about large edits but allow them
DIFF_SIZE=$(git diff --stat "$EDITED_FILE" 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1)
if [ "${DIFF_SIZE:-0}" -gt 100 ]; then
  echo "feedback: Large edit detected ($DIFF_SIZE lines changed in $EDITED_FILE)." >&2
  echo "feedback: Verify this is within your task scope before continuing." >&2
  exit 2  # Send feedback, agent keeps working
fi

# Success: edit looks fine
exit 0
```

**When to use exit 2 vs exit 1**:
- Use **exit 2** for warnings, reminders, and soft guardrails (agent corrects itself)
- Use **exit 1** for hard guardrails that should never be crossed (agent is stopped)

---

## plan_mode_required Configuration

Force specific teammates to operate in plan mode, requiring lead approval before they can implement. Useful for architect or reviewer roles.

**In `.claude/settings.json`**:

```json
{
  "agents": {
    "architect": {
      "mode": "plan",
      "plan_mode_required": true
    },
    "implementer": {
      "mode": "acceptEdits"
    },
    "reviewer": {
      "mode": "plan",
      "plan_mode_required": true
    }
  }
}
```

**Workflow when `plan_mode_required` is true**:
1. Agent creates a plan (reads files, reasons about approach)
2. Agent calls `ExitPlanMode` which sends a `plan_approval_request` to the lead
3. Lead reviews the plan and responds with `plan_approval_response` (approve/reject)
4. If approved: agent exits plan mode and implements
5. If rejected: agent receives feedback and revises the plan

---

## Permission Mode Comparison

| Mode | Can Edit Files | Can Run Bash | Asks Permission | Best For |
|------|---------------|-------------|-----------------|----------|
| `default` | Yes (asks each time) | Yes (asks each time) | Every action | New/untrusted codebases, exploration |
| `acceptEdits` | Yes (auto-approved) | Yes (asks each time) | Bash only | Implementers with clear file scope |
| `plan` | No | No | N/A (read-only) | Architects, reviewers, researchers |
| `bypassPermissions` | Yes (auto-approved) | Yes (auto-approved) | Never | Fully trusted CI/CD automation |

**Choosing the right mode per agent role**:

```
Team Lead       → default or acceptEdits (needs both read and write)
Architect       → plan (designs, doesn't implement)
Implementer     → acceptEdits (primary code writer)
Tester          → acceptEdits (writes tests, runs suites)
Reviewer        → plan (reads and evaluates, doesn't change)
Researcher      → plan (explores, doesn't modify)
```

**Escalation between modes**: An agent in `plan` mode that discovers it needs to make a change should message the lead requesting either:
- A mode upgrade (lead changes config)
- The change be delegated to an implementer agent

---

## Known Bug #24307

**Issue**: Delegate mode may not properly pass tool access to some subagent types. When an agent in delegate mode spawns a subagent (via the Agent tool), the subagent may not inherit the parent's permission level and may revert to default (prompting) mode.

**Symptoms**:
- Subagent asks for permission on actions the parent agent would auto-approve
- Subagent errors with "tool not available" for tools the parent can access
- Slower-than-expected subagent execution due to permission pauses

**Workaround**: Explicitly specify available tools and permissions in the subagent spawn prompt:

```markdown
You have access to the following tools: Read, Edit, Write, Bash, Glob, Grep.
You are operating in acceptEdits mode — file edits are auto-approved.
Do not ask for permission to edit files within the scope: src/auth/*.ts
```

**Status**: Known issue, not yet resolved. Track at the Claude Code GitHub issues page.
