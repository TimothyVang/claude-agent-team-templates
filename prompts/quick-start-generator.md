# Quick-Start Prompt Generator

> Fill in the blanks below and paste directly into Claude Code.
> This is the universal template — for specific patterns, use the dedicated templates.

---

## Universal Template

```
Create an agent team for [TASK TYPE: feature/bug/review/refactor/research/incident/migration/docs].

The goal is: [DESCRIBE THE GOAL IN 1-2 SENTENCES]

Spawn [N] teammates:
1. [ROLE] to [RESPONSIBILITY]. [MODEL/PERMISSION PREFERENCES].
2. [ROLE] to [RESPONSIBILITY]. [MODEL/PERMISSION PREFERENCES].
3. [ROLE] to [RESPONSIBILITY]. [MODEL/PERMISSION PREFERENCES].

File ownership:
- [ROLE 1]: [FILE PATTERNS]
- [ROLE 2]: [FILE PATTERNS]
- [ROLE 3]: [FILE PATTERNS]
```

---

## Template Reference

| Template | File | Best For | Team Size |
|----------|------|----------|-----------|
| A: Feature Dev | `feature-dev.md` | Full-stack features with architect | 4 |
| B: Bug Hunt | `bug-hunt.md` | Competing hypotheses investigation | 3-5 |
| C: Code Review | `code-review.md` | Parallel code audit | 3-4 |
| D: Research | `research.md` | Research and exploration | 2-3 |
| E: Refactor | `refactor.md` | Code migration with validation | 4 |
| F: Incident Response | `incident-response.md` | Production debugging with observer | 4 |
| G: Migration | `migration.md` | Library/framework upgrades (canary pattern) | 5 |
| H: Documentation | `documentation.md` | Parallel doc generation with review | 4 |

---

## Optional Add-ons (append to prompt as needed)

**Plan approval:**
```
Require plan approval before implementation begins.
```

**Competing hypotheses (for bugs/design):**
```
Have teammates challenge each other's findings.
```

**Isolation:**
```
Use worktrees for isolation on implementer teammates.
```

**Cost optimization:**
```
Use Haiku for [ROLE] to save tokens.
Use Sonnet for [ROLE] for good quality at moderate cost.
```

**Quality gates:**
```
Run lint/typecheck after every edit.
Maximum 2 CI rounds before flagging for human review.
```

**Devil's advocate:**
```
Add one teammate whose job is to argue against the proposed approach
and find edge cases the others might miss.
```

**Error recovery:**
```
Enable multi-tier error recovery with exit code 2 feedback.
```

**Observability:**
```
Log all agent actions to .claude/agent-team-log.jsonl.
```

**Guardrails:**
```
Require human approval for changes >500 LOC.
```

**Observer pattern:**
```
Add an observer teammate to monitor accuracy of other agents' work.
The observer should flag misread logs, incorrect conclusions, or logical leaps.
Model: haiku. Permission: plan (read-only).
```

---

## Role Reference

| Role | Agent Type | Model | Permission | Best For |
|------|-----------|-------|------------|----------|
| Architect | Plan agent | inherit | plan | Design before coding |
| Implementer | general-purpose | inherit | acceptEdits | Writing code |
| Researcher | Explore agent | haiku | plan | Finding patterns |
| Reviewer | custom | sonnet | plan | Code quality |
| Tester | general-purpose | inherit | acceptEdits | Writing tests |
| Devil's Advocate | general-purpose | inherit | plan | Challenging assumptions |
| Observer | general-purpose | haiku | plan | Monitoring accuracy of other agents |
| Log Analyzer | Explore agent | haiku | plan | Searching logs and traces |

---

## Examples

**Simple feature (2 teammates):**
```
Create an agent team for a feature.
The goal is: Add a dark mode toggle to the settings page.
Spawn 2 teammates:
1. "implementer" to build the theme system and toggle component. Permission: acceptEdits.
2. "tester" to write unit and integration tests. Permission: acceptEdits.
File ownership:
- implementer: src/components/**, src/styles/**
- tester: tests/**
```

**Complex feature (4 teammates):**
```
Create an agent team for a feature.
The goal is: Add real-time notifications using WebSockets.
Spawn 4 teammates:
1. "architect" to design the WebSocket integration. Permission: plan. Require plan approval.
2. "backend-dev" to implement the WS server and event system. Permission: acceptEdits. Worktree.
3. "frontend-dev" to implement the notification UI and WS client. Permission: acceptEdits. Worktree.
4. "tester" to write tests for both layers. Permission: acceptEdits.
File ownership:
- backend-dev: src/ws/**, src/events/**
- frontend-dev: src/components/notifications/**, src/hooks/useWebSocket.*
- tester: tests/**
```
