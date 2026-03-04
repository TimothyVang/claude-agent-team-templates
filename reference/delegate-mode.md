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

---

## Worktree + Delegate Mode

When using `isolation: "worktree"` with agent teams, each agent gets its own git worktree — an isolated copy of the repository on a separate branch in `.claude/worktrees/`.

### How It Works

1. Agent is spawned with `isolation: "worktree"` in its Agent tool config
2. A new branch is created from HEAD (e.g., `worktree-backend-dev-abc123`)
3. The agent's working directory is set to the worktree path
4. All edits happen on the isolated branch — main branch is untouched
5. On session exit: worktree is kept if changes were made, cleaned up if empty

### Delegate Mode in Worktrees

| Permission Mode | In Worktree | Effect |
|----------------|-------------|--------|
| `default` | Edit/bash still prompt | Same safety, isolated branch |
| `acceptEdits` | Edits auto-approved | Agent freely edits isolated copy |
| `bypassPermissions` | Full autonomy | Agent works completely independently |
| `plan` | Read-only | Agent explores but can't change anything |

The key insight: **worktree isolation makes `acceptEdits` and `bypassPermissions` safer** because all changes are on a disposable branch. The lead reviews and merges (or discards) the branch after the agent finishes.

### When to Combine

- **Worktree + acceptEdits**: Best default for implementers. They work freely without affecting main.
- **Worktree + plan_mode_required**: Maximum safety. Agent plans in isolation, lead approves, then agent implements in the same worktree.
- **Worktree + competing approaches**: Spawn 2 agents in separate worktrees to try different solutions. Pick the better one.

### Merge Strategy

After agents finish:
```bash
# Review each worktree's changes
git diff main...worktree-backend-dev-abc123

# Merge the good ones
git merge worktree-backend-dev-abc123

# Clean up
git worktree prune
```

### Important Notes

- Worktrees share the same `.git` directory — all branches are visible
- Large repos: worktree creation takes seconds (it's not a full clone)
- Agents in worktrees can still read the task list and send messages (shared `.claude/` directory)
- If two agents modify the same file in different worktrees, you'll need to resolve conflicts at merge time
