# Claude Agent Team Templates

> Battle-tested blueprint for building effective agent teams in Claude Code. 10 prompt templates, 10 hook scripts, security guardrails, and observability.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/TimothyVang/claude-agent-team-templates/pulls)

---

## Quickstart

1. **Copy** this directory into your project (or clone the repo)
2. **Pick a template** from `prompts/` (e.g., `feature-dev.md` for a full-stack feature)
3. **Fill in the blanks** and paste the prompt into Claude Code

See `prompts/quick-start-generator.md` for a universal fill-in-the-blanks generator.

---

## Directory Structure

```
agent-team-templates/
├── AGENT-TEAM-PLANNING-TEMPLATE.md   # Main template (hub document)
├── README.md
├── CHANGELOG.md
├── LICENSE
├── settings-template.json            # Hook configurations for settings.json
│
├── prompts/                          # Ready-to-use team prompt templates
│   ├── quick-start-generator.md      # Universal fill-in-the-blanks
│   ├── feature-dev.md                # Template A: Full-stack feature
│   ├── bug-hunt.md                   # Template B: Bug investigation
│   ├── code-review.md                # Template C: Code review/audit
│   ├── research.md                   # Template D: Research & exploration
│   ├── refactor.md                   # Template E: Refactoring
│   ├── incident-response.md          # Template F: Incident response
│   ├── migration.md                  # Template G: Library migration
│   ├── documentation.md              # Template H: Documentation
│   └── plan-first.md                 # Template I: Plan-first development
│
├── scripts/                          # Hook scripts (bash)
│   ├── verify-task.sh                # TaskCompleted verification
│   ├── check-remaining-work.sh       # TeammateIdle loop detection
│   ├── session-start-setup.sh        # SessionStart environment setup
│   ├── error-recovery-hook.sh        # Multi-tier failure recovery
│   ├── observability-hook.sh         # Action logging to JSONL
│   ├── precompact-save-state.sh      # PreCompact state snapshot
│   ├── stop-verification-hook.sh     # Stop hook pattern reference
│   ├── evaluate-run.sh              # Post-run report generator
│   ├── circuit-breaker.sh            # Consecutive failure state machine
│   ├── security-check.sh             # PreToolUse dangerous command blocker
│   └── post-edit-lint.sh             # PostToolUse lint on edit
│
├── checklists/                       # Pre/during/post-run checklists
│   ├── setup-checklist.md
│   ├── runtime-checklist.md
│   ├── post-run-checklist.md
│   ├── error-recovery-reference.md
│   └── failure-modes-checklist.md
│
├── reference/                        # Deep-dive companion docs
│   ├── error-recovery.md             # 12-category error classification
│   ├── token-optimization.md         # Cost benchmarks & caching
│   ├── delegate-mode.md              # Advanced agent controls + worktrees
│   ├── role-prompt-patterns.md       # Supervisor/worker prompt templates
│   └── security-guardrails.md        # OWASP-based security controls
│
└── example-claude-md/                # Example CLAUDE.md files
```

---

## Template Index

| # | Template | File | Best For | Team Size |
|---|----------|------|----------|-----------|
| - | Quick-Start Generator | `prompts/quick-start-generator.md` | Universal fill-in-the-blanks | Any |
| A | Full-Stack Feature | `prompts/feature-dev.md` | Cross-layer features with architect | 4 |
| B | Bug Investigation | `prompts/bug-hunt.md` | Competing hypotheses for root cause | 3-5 |
| C | Code Review/Audit | `prompts/code-review.md` | Security, performance, quality review | 3-4 |
| D | Research & Exploration | `prompts/research.md` | Understanding codebase or tech | 2-3 |
| E | Refactoring | `prompts/refactor.md` | Large-scale code migration | 4 |
| F | Incident Response | `prompts/incident-response.md` | Production debugging with observer | 4 |
| G | Migration | `prompts/migration.md` | Library/framework migration with canary | 5 |
| H | Documentation | `prompts/documentation.md` | Parallel documentation generation | 4 |
| I | Plan-First Development | `prompts/plan-first.md` | High-stakes changes requiring plan approval | 3-4 |

---

## Key Concepts

- **Blueprint Pattern** — Mix deterministic steps (hooks/scripts) with agentic tasks. Don't make everything agentic.
- **File Ownership** — No two teammates edit the same file. Use task dependencies for shared files.
- **Multi-Tier Recovery** — Retry → Undo-and-retry → Model fallback → Checkpoint → Human escalation.
- **Max 2 CI Rounds** — Never retry CI more than twice. Flag for human review instead.

---

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with agent teams enabled
- Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your environment or settings
- Bash (for hook scripts)

---

## License

[MIT](LICENSE)
