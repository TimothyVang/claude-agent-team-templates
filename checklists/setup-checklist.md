# Setup Checklist

> Complete before launching any agent team.

## Environment

- [ ] **Enable agent teams**: Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
  - In settings.json: `{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }`
  - Or export: `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

- [ ] **Choose display mode**:
  - `in-process` - Works in any terminal (default)
  - `tmux` - Split panes for visual monitoring (requires tmux installed)

- [ ] **Pre-approve permissions**: Add common operations to settings.json `allow` list
  to reduce permission prompts during team work.

- [ ] **Consider delegate mode**: For long-running, trusted tasks, consider enabling delegate mode (Shift+Tab) for reduced permission prompts. See `reference/delegate-mode.md`.

## Planning

- [ ] **Define file ownership**: Map which files each teammate will touch.
  No two teammates should edit the same file.
  ```
  Teammate A: src/auth/**
  Teammate B: src/api/**
  Teammate C: tests/**
  ```

- [ ] **Size tasks**: 5-6 tasks per teammate, each producing a testable deliverable.
  Not too small ("add import") or too large ("implement entire auth").

- [ ] **Identify shared files**: Files that multiple teammates need to read/write
  must be accessed sequentially using task dependencies (`blockedBy`).

- [ ] **Set token budget**: Estimate cost based on team size. 2 agents ~100K-300K tokens, 4 agents ~300K-800K, 5 agents ~500K-1.2M tokens. See `reference/token-optimization.md`.

- [ ] **Define guardrails**: Set autonomy levels — auto-approve <50 LOC changes, require tests for 50-500 LOC, require human approval for >500 LOC.

- [ ] **Write self-contained spawn prompts**: Each teammate's spawn prompt must include ALL context they need. Teammates do NOT inherit the lead's conversation history.

## Configuration

- [ ] **Write CLAUDE.md**: Project context that all teammates read automatically.
  See `example-claude-md/CLAUDE.md` for template.

- [ ] **Scope CLAUDE.md files**: Create directory-level CLAUDE.md for module-specific
  context. See `example-claude-md/` for examples.

- [ ] **Configure hooks**: Set up quality gates.
  See `settings-template.json` for hook configurations.
  - `SessionStart` - Environment setup
  - `PostToolUse` - Lint on edit
  - `TaskCompleted` - Verify deliverable
  - `TeammateIdle` - Check remaining work

- [ ] **Configure error recovery**: Set up multi-tier recovery hooks. See `scripts/error-recovery-hook.sh` and `reference/error-recovery.md`.

## Team Design

- [ ] **Choose team template**: Pick from `prompts/` directory.
  - `feature-dev.md` - Full-stack features
  - `bug-hunt.md` - Bug investigation
  - `code-review.md` - Code audit
  - `research.md` - Exploration
  - `refactor.md` - Code migration

- [ ] **Require plan approval**: For architects/designers before implementation begins.

- [ ] **Choose models per role**:
  - `haiku` for research (fast, cheap)
  - `sonnet` for review (good quality, moderate cost)
  - `inherit` for implementation (full capability)

- [ ] **Apply Blueprint pattern**: Identify which steps are deterministic
  (hooks/scripts) vs agentic (teammate tasks).
