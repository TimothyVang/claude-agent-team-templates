# Multi-Agent Failure Modes Checklist
> Pre-launch design checklist based on the 14 most common multi-agent system failure modes.
> Source: "Taxonomy of Failure Modes in Multi-Agent Systems" (arXiv 2503.13657, Mar 2025).
> Research found 41-86% of multi-agent systems fail; 79% of failures trace to specification
> and coordination issues. Use this checklist before launching any agent team.

---

## System Design (prevents 5 failure modes)

- [ ] **Clear task specifications**: Each task has a concrete, measurable description — not vague goals like "improve performance". Tasks specify inputs, expected outputs, and success criteria.
  > *Failure mode: Agents interpret ambiguous tasks differently, producing inconsistent work.*

- [ ] **Explicit role boundaries**: Each agent has a defined scope (file ownership, module responsibility). No two agents share the same files unless using worktree isolation.
  > *Failure mode: Agents overwrite each other's work or produce conflicting changes.*

- [ ] **Progress tracking on loops**: Steps that repeat (retries, iterations) have a maximum count and a progress check. The `error-recovery-hook.sh` enforces max 3 retries.
  > *Failure mode: Agent enters infinite retry loop, consuming tokens without progress.*

- [ ] **Context persistence**: Critical state survives compaction. PreCompact hook saves snapshots. CLAUDE.md files provide persistent context.
  > *Failure mode: Agent loses track of what it was doing after auto-compaction.*

- [ ] **Defined stopping criteria**: Each agent has explicit acceptance criteria. The Stop hook verifies completion before allowing an agent to finish.
  > *Failure mode: Agent stops prematurely, marking incomplete work as "done".*

## Inter-Agent Coordination (prevents 6 failure modes)

- [ ] **Compaction-safe communication**: Important findings are written to files or task descriptions, not just kept in conversation context.
  > *Failure mode: Agent forgets critical information shared by another agent after compaction.*

- [ ] **Clarification over assumption**: Agents are instructed to ask for clarification (via SendMessage to lead) rather than guessing when requirements are unclear.
  > *Failure mode: Agent makes incorrect assumptions and builds on them, compounding errors.*

- [ ] **Scope enforcement**: File ownership prevents agents from drifting into other agents' territories. The `check-remaining-work.sh` hook detects goal drift.
  > *Failure mode: Agent starts "helping" with tasks outside its scope, creating merge conflicts.*

- [ ] **Finding sharing**: Agents discovering information relevant to others send targeted DMs (not broadcasts) with key findings.
  > *Failure mode: Agent A discovers a critical constraint but agent B proceeds without knowing it.*

- [ ] **Observer pattern active**: At least one agent reviews others' work (observer mesh or dedicated reviewer role).
  > *Failure mode: No one catches an agent's incorrect reasoning or buggy implementation.*

- [ ] **Plan-action alignment**: For high-stakes changes, `plan_mode_required` ensures agents plan before acting. Plans are reviewed before implementation begins.
  > *Failure mode: Agent's stated plan diverges from its actual actions, producing unexpected changes.*

## Task Verification (prevents 3 failure modes)

- [ ] **Automated verification gate**: The TaskCompleted hook runs `verify-task.sh` — agents cannot mark tasks complete without passing lint, typecheck, and tests.
  > *Failure mode: Agent declares "done" despite failing tests or broken code.*

- [ ] **Comprehensive checks**: Verification goes beyond "does it compile" — includes lint, type checking, test suite, and (for UI) visual regression.
  > *Failure mode: Code compiles but has runtime errors, type mismatches, or logic bugs.*

- [ ] **Correct verification logic**: Tests actually verify the intended behavior, not just that "no errors were thrown". Review test assertions for correctness.
  > *Failure mode: Tests pass but don't actually test the right thing (false confidence).*

---

## Quick Reference

| Category | # Modes | Primary Mitigation |
|----------|---------|-------------------|
| System Design | 5 | Clear specs, file ownership, PreCompact hook |
| Coordination | 6 | DMs, observer pattern, plan approval |
| Verification | 3 | TaskCompleted hook, comprehensive tests |

> **Recommendation**: Run through this checklist during the setup phase (see `checklists/setup-checklist.md`).
> Address any unchecked items before spawning teammates.
