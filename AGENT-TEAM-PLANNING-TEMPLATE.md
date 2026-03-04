# The Ultimate Agent Team Planning Template

> A reusable blueprint for building effective agent teams in Claude Code.
> Synthesizes lessons from **Stripe's Minions** (1,000+ PRs/week, zero human-written code),
> **Claude Code's Agent Teams** system, and community best practices.
>
> **Architecture**: This is the **hub** document — concise tables and summaries.
> Deep-dives live in `reference/` (the **spokes**). You don't need to read both.

---

## 1. Decision Framework: Which Pattern to Use

| Signal | Use Subagents | Use Agent Team | Use Parallel Sessions |
|--------|--------------|----------------|----------------------|
| Tasks are independent, result-only | Yes | - | - |
| Agents need to discuss/challenge findings | - | Yes | - |
| Same-file edits needed | Yes (sequential) | Avoid | - |
| Cross-layer coordination (FE/BE/tests) | - | Yes | - |
| Quick focused workers | Yes | - | - |
| Budget-conscious | Yes (lower tokens) | - | Yes |
| Competing hypotheses | - | Yes | - |
| Simple parallelism, no coordination | - | - | Yes (worktrees) |

**Quick decision**: If agents need to *talk to each other*, use a team. If they just need to *return results*, use subagents.

**Cost note**: Agent teams consume 3-10x more tokens than subagents. Always consider whether a cheaper pattern would work. See [Section 8](#8-token-optimization--cost-control).

---

## 2. The Blueprint Pattern

Stripe's most powerful insight: **don't make everything agentic.** Use a hybrid state machine
that mixes deterministic steps with agentic decision-making.

```
[Deterministic]     [Agentic]          [Deterministic]
 Setup env,    -->  Analyze &     -->   Run linter
 warm caches        implement           (cached, <5s)
                                            |
[Deterministic]     [Agentic]          [Deterministic]
 Push & open   <--  Fix failures  <--   Run CI
 PR                  (max 1 try)        (selective)
```

### Mapping to Claude Code

| Step | Type | Claude Code Implementation |
|------|------|---------------------------|
| Setup environment | Deterministic | `SessionStart` hook or bash script |
| Explore codebase | Agentic | Explore subagent / researcher teammate |
| Design approach | Agentic | Plan agent with plan approval |
| Run lint/typecheck | Deterministic | `PostToolUse` hook on Edit/Write |
| Implement feature | Agentic | Implementer teammate |
| Run tests locally | Deterministic | `TaskCompleted` hook |
| Fix failures | Agentic | Teammate (max 2 attempts) |
| Push & open PR | Deterministic | Bash script via lead |

### Context Management (Stripe's Toolshed Model)

Stripe curates ~500 MCP tools but gives each agent only a **small, relevant subset**.

**Per-teammate MCP tool strategy:**
- **Researcher**: docs tools, search tools, codebase tools
- **Implementer**: file tools, test runners, build tools
- **Reviewer**: read-only tools, linter output, git diff
- Don't give every teammate every tool

**Use scoped rule files** (CLAUDE.md per directory):
```
project/
  CLAUDE.md                    # Global (all teammates read)
  src/auth/CLAUDE.md           # Auth patterns (auth implementer only)
  src/api/CLAUDE.md            # API conventions (API implementer only)
  tests/CLAUDE.md              # Testing conventions (tester only)
```

See `example-claude-md/` for templates.

---

## 3. Team Architecture

### 3.1 Core Roles (Pick What You Need)

| Role | Agent Type | Model | Permission | Tools | Purpose |
|------|-----------|-------|------------|-------|---------|
| **Team Lead** | You (main session) | - | - | All | Creates team, assigns tasks, synthesizes |
| **Architect** | Plan agent | inherit | plan | Read-only | Analyzes codebase, designs approach |
| **Implementer** | general-purpose | inherit | acceptEdits | All | Writes code, one per module |
| **Researcher** | Explore agent | haiku | plan | Read-only | Finds patterns, traces code paths |
| **Reviewer** | custom subagent | sonnet | plan | Read, Grep, Glob | Reviews code quality |
| **Tester** | general-purpose | inherit | acceptEdits | All | Writes/runs tests |
| **Devil's Advocate** | general-purpose | inherit | plan | Read-only | Challenges assumptions |
| **Observer** | general-purpose | haiku | plan | Read-only | Monitors peers for accuracy |

### 3.2 Team Size Guidelines

| Task Complexity | Teammates | Tasks/Teammate |
|----------------|-----------|----------------|
| Small (1-2 modules) | 2-3 | 3-4 |
| Medium (3-5 modules) | 3-4 | 5-6 |
| Large (full-stack feature) | 4-5 | 5-6 |
| Research/Review | 3-5 | 2-3 |

**Rule**: 3-5 teammates is the sweet spot. More than 5 hits diminishing returns.

### 3.3 Advanced Agent Controls

| Control | What It Does | When to Use |
|---------|-------------|-------------|
| **Delegate Mode** (Shift+Tab) | Broader agent autonomy, fewer prompts | Long-running trusted tasks |
| **`plan_mode_required`** | Forces agent into plan mode first | Architects, before implementation |
| **Exit code 2** | Hook sends feedback AND keeps agent working | Error recovery, soft failures |
| **Permission modes** | Controls what agent can do without asking | Varies by role |

**Permission mode reference:**

| Mode | Can Edit | Can Bash | Asks Permission | Best For |
|------|----------|----------|-----------------|----------|
| `default` | Yes (asks) | Yes (asks) | Every action | New/untrusted |
| `acceptEdits` | Yes (auto) | Yes (asks) | Bash only | Implementers |
| `plan` | No | No | N/A (read-only) | Architects/reviewers |
| `bypassPermissions` | Yes (auto) | Yes (auto) | Never | Trusted automation |

> **Known bug (#24307)**: Delegate mode may not pass tool access properly to some subagent types. Workaround: explicitly specify tools in spawn prompt.

See `reference/delegate-mode.md` for full details.

### 3.4 Model Routing for Cost

| Task Type | Model | Cost | Why |
|-----------|-------|------|-----|
| Research/explore | haiku | Low | Read-only, high volume |
| Code review | sonnet | Med | Quality matters, no editing |
| Implementation | opus | High | Full capability needed |
| Bug investigation | haiku→sonnet | Low→Med | Start cheap, escalate if needed |
| Documentation | sonnet | Med | Quality writing, no complex logic |
| Observation/monitoring | haiku | Low | Pattern matching, no editing |

See `reference/token-optimization.md` for cost benchmarks.

---

## 4. Task Decomposition Strategy

### 4.1 Shift Left: Get Feedback Early

```
Phase 1: RESEARCH   (parallel, read-only)
Phase 2: PLAN       (sequential, requires Phase 1)
Phase 3: IMPLEMENT  (parallel, isolated worktrees)
Phase 4: VERIFY     (parallel reviews, then sequential integration)
Phase 5: INTEGRATE  (sequential, merge + final tests)
```

### 4.2 Task Sizing

| Size | Example | Verdict |
|------|---------|---------|
| Too small | "Add an import statement" | Coordination overhead > benefit |
| Too large | "Implement the entire auth system" | Too long without check-ins |
| Just right | "Implement JWT token validation middleware" | Clear deliverable, testable |

**Each task should:**
- Be completable in one focused session
- Produce a clear, testable deliverable
- Touch a distinct set of files (no overlaps)
- Have explicit acceptance criteria

---

## 5. Coordination Patterns

### 5.1 File Ownership (Critical)

**The #1 rule**: No two teammates should edit the same file.

```
Teammate A: src/auth/login.ts, src/auth/middleware.ts
Teammate B: src/api/routes.ts, src/api/handlers.ts
Teammate C: tests/auth.test.ts, tests/api.test.ts
```

If a file must be touched by multiple teammates, use task dependencies to make it sequential.

### 5.2 Task Dependency DAG

Use `blockedBy` to create a directed acyclic graph of task execution:

```
[Research A]  [Research B]     ← parallel, no dependencies
      \           /
       v         v
      [Plan]                   ← blocked by both research tasks
      /    \
     v      v
[Impl A]  [Impl B]            ← parallel, blocked by plan
     \      /
      v    v
    [Integration]              ← blocked by both impl tasks
        |
        v
     [Review]                  ← blocked by integration
```

Set up with TaskUpdate:
```
TaskUpdate(taskId: "plan", addBlockedBy: ["research-a", "research-b"])
TaskUpdate(taskId: "impl-a", addBlockedBy: ["plan"])
TaskUpdate(taskId: "impl-b", addBlockedBy: ["plan"])
```

### 5.3 Communication Protocol

| Situation | Action |
|-----------|--------|
| Findings affect another teammate's work | Direct message (`SendMessage`) |
| Challenging an approach | Direct message (devil's advocate) |
| Reporting blockers | Direct message to lead |
| Critical blocking issue | Broadcast (use sparingly!) |
| Major architectural decision for all | Broadcast |
| Task status change | Update task list (automatic notifications) |

### 5.4 Quality Gates via Hooks

See `scripts/` directory for hook implementations:
- `verify-task.sh` - Runs on `TaskCompleted` to validate deliverables (with exit code 2 retry)
- `check-remaining-work.sh` - Runs on `TeammateIdle` with loop detection
- `session-start-setup.sh` - Runs on `SessionStart` for environment setup
- `error-recovery-hook.sh` - Multi-tier failure recovery
- `observability-hook.sh` - Logs agent actions for monitoring

### 5.5 Worktree Isolation Strategy

Instead of (or in addition to) file ownership, you can use **git worktrees** to give each agent an isolated copy of the repository on its own branch.

| Strategy | When to Use | Pros | Cons |
|----------|------------|------|------|
| **File ownership** | Teammates work on different files/modules | Simple, no merge needed, lower overhead | Can't explore alternative approaches |
| **Worktree isolation** | Teammates may rewrite same files, or you want competing solutions | Each agent gets full repo copy, safe experimentation | Requires merge/selection step at the end |
| **Both** | High-stakes changes with clear module boundaries | Maximum safety: isolated branches + no file overlap | Highest setup overhead |

**Configuration**: Set `isolation: "worktree"` when spawning an agent:
```
Agent(name: "backend-dev", isolation: "worktree", ...)
```

The agent gets a new branch in `.claude/worktrees/` (e.g., `worktree-backend-dev-abc123`). All edits happen on this branch — the main branch is untouched until the lead merges.

**Merge workflow**:
```bash
# Review each worktree's changes
git diff main...worktree-backend-dev-abc123

# Merge the good ones
git merge worktree-backend-dev-abc123

# Clean up
git worktree prune
```

**Best pairings**:
- Worktree + `acceptEdits` → Agent freely edits its isolated copy (safest default for implementers)
- Worktree + `plan_mode_required` → Agent plans first, lead approves, then implements in same worktree
- Two agents in separate worktrees → Competing approaches; pick the better one

See `reference/delegate-mode.md` for detailed worktree + permission mode interaction.

---

## 6. Error Recovery & Failure Handling

### 6.1 Multi-Tier Recovery Ladder

| Tier | Strategy | When to Use | Max Attempts |
|------|----------|-------------|-------------|
| 1 | **Retry with backoff** | Transient failures (network, rate limit) | 3 |
| 2 | **Undo-and-retry** | Partial work is broken (bad edit, failed commit) | 2 |
| 3 | **Model fallback** | Model-specific failure (haiku→sonnet→opus) | 1 |
| 4 | **Checkpoint recovery** | Task-level failure (restart from last good state) | 1 |
| 5 | **Human escalation** | After tiers 1-4 fail | - |

### 6.2 Confidence-Based Escalation

| Agent Confidence | Action |
|-----------------|--------|
| >90% | Auto-proceed, async review later |
| 80-90% | Async review required before merge |
| 70-80% | Synchronous approval required |
| <70% | Escalate to human immediately |

### 6.3 Failure Detection Signals

| Signal | How to Detect | Response |
|--------|--------------|----------|
| **Goal drift** | Agent working on wrong task | Message with course correction |
| **Loop detection** | Same errors/actions repeating | Apply tier 2 (undo-and-retry) |
| **Progress stalling** | No task updates for extended period | Check if blocked, reassign |
| **Token overrun** | Excessive tool calls without progress | Swap to cheaper model or escalate |
| **Silent failure** | Task marked complete but output is wrong | Observer pattern catches this |

See `reference/error-recovery.md` for full 12-category error classification and `scripts/error-recovery-hook.sh` for implementation.

---

## 7. Token Optimization & Cost Control

### 7.1 Cost Estimation by Team Size

| Team Size | Estimated Tokens | Estimated Cost (approx) |
|-----------|-----------------|------------------------|
| 2 agents | 100K-300K | $1-5 |
| 4 agents | 300K-800K | $5-15 |
| 5 agents | 500K-1.2M | $10-25 |

*Costs vary significantly based on task complexity, model mix, and caching.*

### 7.2 Prompt Caching

- System prompts are cached for ~5 minutes (60-90% savings on repeated calls)
- **What invalidates cache**: Any change to the cached prefix
- **Maximize hits**: Put stable content first (CLAUDE.md, conventions), variable content last
- Scoped CLAUDE.md files help — teammates only load relevant context

### 7.3 Context Compaction

| Technique | Impact |
|-----------|--------|
| Keep CLAUDE.md < 500 lines | Saves ~2K tokens per agent |
| Directory-scoped CLAUDE.md | Each agent loads only relevant context |
| Minimize tool descriptions | Fewer tools = less system prompt |
| Use compressed history | Auto-compact preserves key decisions |

### 7.4 Context Priority Hierarchy

```
1. System prompt        ← highest priority, always loaded
2. CLAUDE.md files      ← project context
3. Task-relevant files  ← files agent is working on
4. Compressed history   ← prior conversation, auto-managed
5. Tool descriptions    ← lowest priority, minimize
```

See `reference/token-optimization.md` for detailed cost benchmarks and calculator.

---

## 8. Observability & Monitoring

### 8.1 Key Metrics

| Metric | Target | Red Flag |
|--------|--------|----------|
| Task completion rate | >80% | <50% |
| Tokens per task | <50K | >100K |
| Tool success rate | >90% | <70% |
| Escalation rate | <20% | >40% |
| CI pass rate (1st try) | >60% | <30% |

### 8.2 Failure Detection via Hooks

The `observability-hook.sh` script logs all agent actions to `.claude/agent-team-log.jsonl`:

```jsonl
{"timestamp":"2026-03-03T10:00:00Z","event":"TaskCompleted","agent":"implementer","status":"success","files":["src/auth.ts"]}
{"timestamp":"2026-03-03T10:05:00Z","event":"PostToolUse","agent":"tester","status":"failure","tool":"Bash","error":"test failed"}
```

### 8.3 Monitoring Checklist

1. Watch task list for stuck/idle agents
2. Check `agent-team-log.jsonl` for patterns (repeated failures, excessive retries)
3. Monitor token usage per agent (cheaper models for read-only work)
4. Review inter-agent messages for goal drift

See community tool: [disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability)

---

## 9. Guardrails & Safety Framework

### 9.1 Autonomy Levels by Change Size

| Change Size | Autonomy Level | Required Checks |
|-------------|---------------|-----------------|
| < 50 LOC | Auto-approve | Lint + typecheck only |
| 50-500 LOC | Tests required | Lint + typecheck + test suite |
| 500+ LOC | Human approval | Full review before merge |

### 9.2 Destructive Action Gates

These actions **always require explicit approval**, regardless of change size:

| Action | Gate |
|--------|------|
| File/directory deletion | Confirm scope with lead |
| Database migrations | Human approval required |
| Breaking API changes | Human approval required |
| Force push / history rewrite | Never in teams — use new commits |
| Security-sensitive changes | Manual review required |
| Dependency upgrades (major) | Compatibility check first |

### 9.3 Pre-Execution Guardrails

Before starting implementation:
- [ ] Validate file ownership — no teammate overlaps
- [ ] Check dependencies — blocked tasks won't start
- [ ] Verify spawn prompts are self-contained (teammates don't inherit lead context)
- [ ] Confirm models are appropriate for each role

### 9.5 Security Guardrails

Prevent agents from executing dangerous operations (whether from bugs, prompt injection, or misunderstanding):

| Category | Examples Blocked | Hook |
|----------|-----------------|------|
| **Dangerous commands** | `rm -rf /`, `DROP TABLE`, `git push --force` to main | PreToolUse (Bash) |
| **Sensitive files** | `.env`, `*.pem`, `credentials.*`, SSH keys | PreToolUse (Read/Edit/Write) |
| **Path traversal** | `../../../etc/passwd` | PreToolUse (file operations) |
| **Hardcoded secrets** | API keys, passwords, tokens in source code | PostToolUse (Edit/Write) |

**Configuration**: Add a `PreToolUse` hook matching `Bash` tool to your `settings.json`. See `reference/security-guardrails.md` for complete patterns, example hooks, and OWASP AI Agent Security Top 10 coverage.

### 9.4 Post-Execution Guardrails

After each edit/task (via hooks):
- [ ] Lint check (PostToolUse hook)
- [ ] Typecheck (PostToolUse hook)
- [ ] Test suite (TaskCompleted hook)
- [ ] File ownership validation (verify no cross-boundary edits)

---

## 10. Team Templates

Ready-to-use prompt templates in `prompts/` directory:

| Template | File | Use When |
|----------|------|----------|
| A: Full-Stack Feature | `prompts/feature-dev.md` | Building cross-layer features |
| B: Bug Investigation | `prompts/bug-hunt.md` | Competing hypotheses for root cause |
| C: Code Review/Audit | `prompts/code-review.md` | Security, performance, quality review |
| D: Research & Exploration | `prompts/research.md` | Understanding codebase or tech |
| E: Refactoring | `prompts/refactor.md` | Large-scale code migration |
| F: Incident Response | `prompts/incident-response.md` | Production debugging with observer |
| G: Migration | `prompts/migration.md` | Library/framework migration with canary |
| H: Documentation | `prompts/documentation.md` | Parallel documentation generation |
| I: Plan-First Development | `prompts/plan-first.md` | High-stakes changes requiring plan approval before any code |

---

## 11. Anti-Patterns to Avoid

| Anti-Pattern | Why It Fails | Do This Instead |
|-------------|-------------|-----------------|
| Two teammates editing same file | Overwrites, merge conflicts | Assign distinct file ownership |
| Team of 8+ for a simple feature | Coordination overhead explodes | Use 3-5 teammates max |
| No plan approval before coding | Wasted effort on wrong approach | Require plan approval |
| Broadcasting every update | Token cost scales linearly | Use direct messages |
| Lead implements instead of delegating | Defeats purpose of team | Lead waits for teammates |
| Tasks too granular ("add import") | Overhead > benefit | Size tasks as testable deliverables |
| No file ownership boundaries | Git conflicts, overwrites | Map files before starting |
| Skipping research phase | Agents reinvent existing code | Always explore first |
| Unlimited CI retries | Wastes time and tokens | Max 2 CI rounds |
| Running team unattended too long | Wasted effort compounds | Monitor and steer regularly |
| Making everything agentic | Wastes tokens on predictable steps | Blueprint pattern: deterministic where possible |
| Giving every agent all tools | Agents get distracted | Curate tool subsets per role |
| One massive CLAUDE.md | Wastes context | Directory-scoped CLAUDE.md files |
| **No error recovery strategy** | Failures cascade, waste tokens | Multi-tier recovery ladder (Section 6) |
| **Ignoring token costs** | Budget overrun, diminishing returns | Model routing + prompt caching (Section 7) |
| **No guardrails on destructive actions** | Accidental deletions, bad migrations | Autonomy level gates (Section 9) |
| **No monitoring/observability** | Problems go undetected | Failure detection signals in hooks (Section 8) |
| **Vague spawn prompts** | Teammates lack context, drift | Self-contained prompts with acceptance criteria |

> **Pre-launch check**: See `checklists/failure-modes-checklist.md` for a design checklist based on the 14 most common multi-agent failure modes (arXiv 2503.13657). Research found 41-86% of multi-agent systems fail, with 79% of failures tracing to specification and coordination issues — most of which are preventable with upfront design.

---

## 12. Verification Strategy (Stripe's Feedback Loop)

**Hard rule: Maximum 2 CI rounds.**

```
1. LOCAL CHECKS (deterministic, <5 sec)
   - Lint, typecheck, format check
   - Run via PostToolUse hook
   - Catches ~60% of issues before push

2. SELECTIVE CI (1st round)
   - Run only tests related to changed files
   - Pass -> done
   - Fail -> ONE fix attempt (exit code 2 feedback)

3. FIX ATTEMPT (agentic, 1 round)
   - Agent analyzes failure, applies fix
   - Auto-apply known fixes (formatting, imports)
   - Uses error recovery ladder if needed (Section 6)

4. SELECTIVE CI (2nd round, FINAL)
   - Pass -> done
   - Fail -> proceed anyway, flag for human review
   - NEVER retry a 3rd time
```

---

## 13. Known Limitations & Gotchas

| Limitation | Impact | Workaround |
|-----------|--------|------------|
| **No session resumption** | `/resume` doesn't restore teammates | Save team state in task list; respawn if needed |
| **One team per session** | Can't nest teams or run multiple | Use subagents for sub-coordination |
| **Teammates don't inherit lead's history** | Context must be in spawn prompt | Write self-contained spawn prompts with all context |
| **Delegate mode bug (#24307)** | Tool access may not pass through | Explicitly list tools in spawn prompt |
| **Split panes unsupported** | VS Code terminal, Windows Terminal, Ghostty | Use `in-process` display mode |
| **All teammates load same MCP servers** | Can't scope MCP per teammate | Use [cs50victor/claude-code-teams-mcp](https://github.com/cs50victor/claude-code-teams-mcp) |
| **No built-in cost tracking** | Token usage not surfaced per agent | Use observability hooks to estimate |
| **Context auto-compact is lossy** | Early conversation details may be lost | Put critical info in CLAUDE.md, not just conversation |

---

## 14. Checklists

See `checklists/` directory:
- `setup-checklist.md` - Before launching any agent team
- `runtime-checklist.md` - While the team is working
- `post-run-checklist.md` - After the team finishes
- `error-recovery-reference.md` - Quick-reference for error handling
- `failure-modes-checklist.md` - 14 multi-agent failure modes design checklist (arXiv-based)

---

## 15. Quick-Start & Community Resources

### Getting Started

1. Copy this template directory into your project
2. Edit `example-claude-md/CLAUDE.md` with your project context
3. Pick a team template from `prompts/`
4. Fill in the blanks and paste into Claude Code
5. Use the checklists to stay on track

See `prompts/quick-start-generator.md` for a fill-in-the-blanks prompt generator.

### Community Resources

| Resource | What It Provides |
|----------|-----------------|
| [panaversity/claude-code-agent-teams-exercises](https://github.com/panaversity/claude-code-agent-teams-exercises) | 8 exercises + 3 capstone projects for learning agent teams |
| [jkutasi/claude-get-started-prd-framework](https://github.com/jkutasi/claude-get-started-prd-framework) | PRD template optimized for Claude Code |
| [disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability) | Monitoring hooks for multi-agent workflows |
| [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) | 100+ curated subagent configurations |
| [cs50victor/claude-code-teams-mcp](https://github.com/cs50victor/claude-code-teams-mcp) | Per-teammate MCP server scoping |
| [wshobson/agents](https://github.com/wshobson/agents) | 112 agents, 16 orchestrators, 146 skills — extensive agent library |
| [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates) | CLI tool with web interface for browsing agent templates |
| [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) | All 14 hook events with practical patterns and examples |
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Curated list of skills, hooks, commands, and plugins |

### Research & Reports

- **Anthropic**: [Agentic Coding Trends Report (2026)](https://www.anthropic.com/research/agentic-coding-trends) — Data on how teams use Claude Code agents at scale
- **arXiv 2503.13657**: [Taxonomy of Failure Modes in Multi-Agent Systems](https://arxiv.org/abs/2503.13657) — 14 failure modes, 41-86% failure rates, mitigation strategies
- **Stripe Engineering**: Minions Part 2 (Feb 2026) — 1,000+ PRs/week, max 2 CI rounds, tool curation patterns

### Programmatic Agent Spawning

For advanced use cases, use the **Claude Agent SDK** to spawn agents programmatically:

- **TypeScript**: `@anthropic-ai/agent-sdk` — build custom agent orchestration
- **Python**: `claude-agent-sdk` — same capabilities, Python-native
- Use when you need: custom retry logic, external triggers, CI/CD integration, or production agent pipelines

### Reference Documents

Deep-dives in `reference/` (read as needed):
- `reference/error-recovery.md` - Full error classification and recovery patterns
- `reference/token-optimization.md` - Cost benchmarks and caching strategies
- `reference/delegate-mode.md` - Advanced agent control modes + worktree interaction
- `reference/role-prompt-patterns.md` - Supervisor/worker prompt templates
- `reference/security-guardrails.md` - OWASP-based security controls for agent teams
