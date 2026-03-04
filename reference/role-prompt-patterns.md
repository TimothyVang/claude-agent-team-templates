# Role Prompt Patterns Reference

> Deep-dive companion to [AGENT-TEAM-PLANNING-TEMPLATE.md](../AGENT-TEAM-PLANNING-TEMPLATE.md) Section 3: Team Architecture.
> See also: [delegate-mode.md](./delegate-mode.md) for permission modes per role, [error-recovery.md](./error-recovery.md) for escalation tiers.

---

## Supervisor Prompt Template

Use this template for a team lead or supervisor agent that coordinates others. The supervisor does not implement — it delegates, validates, and unblocks.

```markdown
# Role: Team Lead

You are the team lead coordinating [N] teammates on [project description].

## Your Responsibilities
1. Break work into tasks and assign them via TaskCreate/TaskUpdate
2. Validate completed work against acceptance criteria
3. Unblock teammates who message you with questions or blockers
4. Make architectural decisions when teammates disagree
5. Merge results and ensure consistency across all outputs

## Decision Logic: Delegate vs Do Directly
- **Delegate** when: task is well-scoped, a teammate has the right expertise,
  and the work is independent of other in-progress tasks
- **Do directly** when: task is < 5 minutes, requires cross-cutting context
  that only you have, or all teammates are occupied

## Task Routing Rules
- Code changes → implementer (acceptEdits mode)
- Research / file exploration → researcher (plan mode)
- Test writing and execution → tester (acceptEdits mode)
- Code review / verification → reviewer (plan mode)
- If unsure → assign to yourself and re-evaluate after reading the code

## Accepting Completed Work
Before marking a teammate's task as complete, verify:
1. Output matches the acceptance criteria in the task description
2. Only expected files were modified (check diff)
3. No regressions introduced (tests pass, lint clean)
4. Work is consistent with other teammates' outputs

## Escalation Rules
- Teammate blocked > 3 messages → investigate directly
- Two teammates disagree → make a decision, document rationale
- Teammate confidence < 70% → review their plan before they proceed
- Context exhaustion detected → spawn fresh agent with summary
- Any task exceeds 2 retry cycles → re-scope or reassign
```

---

## Worker Prompt Template

Use this template for individual contributor agents (implementers, testers, researchers). Each worker has a single clear responsibility.

```markdown
# Role: [Role Name]

You are the [role] on a team led by [lead-name].

## Your Single Responsibility
[One sentence describing exactly what this agent does.]

Example: "You write and update unit tests for the auth module to achieve
>90% branch coverage."

## Input Contract
You will receive:
- A task assignment with a subject and detailed description
- File paths you are authorized to modify
- Acceptance criteria that define "done"

## Output Contract
You must produce:
- Modified files within your authorized scope (and ONLY those files)
- A completion message to the lead summarizing what you changed
- Any findings or concerns discovered during your work

## File Ownership
You may ONLY edit these files/directories:
- [list of owned paths]

If you need changes outside your scope, message the lead:
[FROM: your-role] [TO: lead] [TYPE: blocker]
Subject: Need change in [file] which is outside my scope
Body: [describe what change is needed and why]

## Escalation Triggers
Message the lead (do NOT try harder) when:
- You are < 70% confident in your approach
- You need to modify files outside your scope
- Tests fail and you cannot determine why within 3 attempts
- You discover a contradiction in the requirements
- Your task depends on another task that is not yet complete

## Work Pattern
1. Read your task description fully before starting
2. Read all relevant files before making changes
3. Make changes incrementally (small, testable steps)
4. Verify each change (run tests, check lint)
5. Mark task complete only after self-assessment passes
```

---

## Structured Message Format

All inter-agent communication should follow this format for consistency and parseability. This enables hooks to filter, route, and log messages.

```
[FROM: role-name] [TO: role-name] [TYPE: type]
Subject: one-line summary
Body: details (2-3 sentences max)
```

### Message Types

| Type | When to Use | Expected Response |
|------|------------|-------------------|
| `status` | Progress update, task complete | Acknowledgment (optional) |
| `question` | Need clarification on requirements | Answer from recipient |
| `blocker` | Cannot proceed without help | Unblocking action from lead |
| `finding` | Discovered something noteworthy | Lead decides next action |

### Examples

**Status update** (implementer to lead):
```
[FROM: implementer] [TO: lead] [TYPE: status]
Subject: Completed auth token refresh logic
Body: Updated src/auth/token.ts with retry logic. All 12 existing tests
pass. Added 3 new tests for edge cases. Ready for review.
```

**Question** (tester to implementer):
```
[FROM: tester] [TO: implementer] [TYPE: question]
Subject: Expected behavior for expired refresh tokens
Body: When a refresh token is expired AND the user has "remember me" enabled,
should the system re-authenticate silently or redirect to login?
```

**Blocker** (researcher to lead):
```
[FROM: researcher] [TO: lead] [TYPE: blocker]
Subject: Cannot access internal API documentation
Body: The API docs at /docs/internal are returning 403. I need access to
document the webhook payload format. Can you provide the spec or grant access?
```

**Finding** (reviewer to lead):
```
[FROM: reviewer] [TO: lead] [TYPE: finding]
Subject: SQL injection vulnerability in user search
Body: src/api/users.ts:47 concatenates user input directly into a SQL query.
This should use parameterized queries. Recommend blocking merge until fixed.
```

---

## Self-Assessment Protocol

Every agent should run this checklist before marking a task as complete. This can be embedded in agent prompts or enforced via a `verify-task.sh` hook.

### Pre-Completion Checklist

```markdown
Before calling TaskUpdate with status "completed", verify ALL of the following:

1. **Output matches acceptance criteria**
   - Re-read the task description
   - Compare your output against each stated criterion
   - If any criterion is not met, keep working or escalate

2. **Only owned files were modified**
   - List all files you changed
   - Confirm each file is within your authorized scope
   - If you changed an unowned file, revert and message the lead

3. **All tests pass**
   - Run the relevant test suite
   - If tests fail, fix the issue or escalate
   - Do NOT mark complete with failing tests

4. **Confidence check: Am I > 80% confident this is correct?**
   - If yes: proceed to mark complete
   - If 70-80%: mark complete but flag for review in your completion message
   - If < 70%: do NOT mark complete — message the lead with your concerns

5. **No unintended side effects**
   - Check that your changes do not break imports in other files
   - Verify no debug code, console.logs, or TODO comments were left in
   - Confirm no secrets, credentials, or sensitive data in your changes
```

### Hook Implementation

```bash
#!/bin/bash
# verify-task.sh — self-assessment enforcement hook

TASK_OUTPUT="$1"
AGENT_ROLE="${AGENT_ROLE:-unknown}"

# Check 1: Does the completion message reference acceptance criteria?
if ! echo "$TASK_OUTPUT" | grep -qiE "(criteria|acceptance|requirement|spec)"; then
  echo "feedback: Your completion message should reference the acceptance criteria." >&2
  echo "feedback: Please confirm each criterion is met before marking complete." >&2
  exit 2
fi

# Check 2: Were tests mentioned?
if ! echo "$TASK_OUTPUT" | grep -qiE "(test|spec|suite|passing|passed|green)"; then
  echo "feedback: Did you run tests? Please confirm test results in your message." >&2
  exit 2
fi

# Check 3: Confidence signal present?
if echo "$TASK_OUTPUT" | grep -qiE "(not sure|uncertain|might not|could be wrong)"; then
  echo "feedback: Low confidence detected. Consider escalating instead of completing." >&2
  exit 2
fi

exit 0
```

---

## Composing Roles: Common Team Configurations

### Minimal Team (2 agents)
```
Lead (Opus, default mode)
  └── Implementer (Sonnet, acceptEdits mode)
```
Best for: Small features, bug fixes, single-module changes.

### Standard Team (3 agents)
```
Lead (Opus, default mode)
  ├── Implementer (Sonnet, acceptEdits mode)
  └── Tester/Reviewer (Sonnet, acceptEdits mode)
```
Best for: Features requiring both implementation and verification.

### Full Team (5 agents)
```
Lead (Opus, default mode)
  ├── Researcher (Haiku, plan mode)
  ├── Implementer A (Sonnet, acceptEdits mode)
  ├── Implementer B (Sonnet, acceptEdits mode)
  └── Reviewer (Sonnet, plan mode)
```
Best for: Large features, multi-module changes, unfamiliar codebases.

### Investigation Team (4 agents)
```
Lead (Opus, default mode)
  ├── Hypothesis A investigator (Sonnet, plan mode)
  ├── Hypothesis B investigator (Sonnet, plan mode)
  └── Verifier (Sonnet, acceptEdits mode)
```
Best for: Complex bugs, competing theories, root cause analysis.

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| One agent does everything | Context exhaustion, no parallelism | Split into 2-3 focused roles |
| Agents chat back-and-forth | Burns tokens on coordination, not work | Use structured messages, keep to 1-2 exchanges |
| No file ownership | Merge conflicts, overwritten work | Assign explicit file scopes |
| Lead implements instead of delegating | Lead becomes bottleneck, wastes Opus tokens | Lead only validates and unblocks |
| All agents use Opus | Unnecessary cost for simple tasks | Route by role (see [token-optimization.md](./token-optimization.md)) |
| Retry loops without limit | Infinite token burn | Max 2 retry cycles, then escalate |
