# Post-Run Checklist

> Complete after the agent team finishes all work.

## Verification

- [ ] **Review task list**: All tasks should be marked `completed`.
  ```
  TaskList  # Check for any remaining pending/in_progress tasks
  ```

- [ ] **Run full test suite**: Verify no regressions.
  ```bash
  npm test           # or pytest, go test, etc.
  ```

- [ ] **Check for file conflicts**: Working directory should be clean.
  ```bash
  git status
  git diff           # Review all changes
  ```

- [ ] **Verify file ownership was respected**: No unexpected file modifications.
  ```bash
  git log --name-only --oneline  # Check which files each commit touched
  ```

## Quality Review

- [ ] **Review the synthesized output**: The lead should have a coherent summary
  of what was built/found/fixed.

- [ ] **Spot-check critical changes**: Don't blindly accept all agent output.
  Focus on:
  - Security-sensitive code (auth, payments, user data)
  - Database migrations or schema changes
  - Public API surface changes
  - Configuration changes

- [ ] **Check for common agent issues**:
  - Unnecessary abstractions or over-engineering
  - Missing error handling at system boundaries
  - Hardcoded values that should be configurable
  - Inconsistency with existing project patterns

## Cost & Observability Review

- [ ] **Review observability log**: Check `.claude/agent-team-log.jsonl` for patterns — excessive retries, high failure rates, goal drift events.

- [ ] **Generate run report**: Run `./agent-team-templates/scripts/evaluate-run.sh` to produce a markdown summary of task completion rate, failure counts, and flagged patterns.

- [ ] **Calculate total cost**: Count approximate tokens used. Compare against budget estimate from setup checklist.

- [ ] **Identify cost optimizations**: Could any agents have used a cheaper model? Were there unnecessary tool calls?

## Cleanup

- [ ] **Shut down teammates gracefully**: Send shutdown requests to all teammates.
  ```
  SendMessage type: "shutdown_request" to each teammate
  ```

- [ ] **Clean up team resources**: Delete the team after all teammates shut down.
  ```
  TeamDelete
  ```

- [ ] **Clean up worktrees**: If worktrees were used, verify they're cleaned up.
  ```bash
  git worktree list   # Should show only the main worktree
  git worktree prune  # Clean up stale worktree references
  ```

## Documentation

- [ ] **Commit changes**: Stage and commit with a descriptive message.

- [ ] **Update CLAUDE.md**: If the team work revealed new patterns or conventions,
  update the project CLAUDE.md so future sessions benefit.

- [ ] **Note lessons learned**: What worked well? What would you change next time?
  Consider updating the team template for future use.

- [ ] **Update memory files**: If using `.claude/memory/`, update episodic memory with lessons from this session. See `example-claude-md/memory-CLAUDE.md`.

## Stripe's Principle

> "Agents eliminate the bottleneck of code authorship, not code review."
> Always do a human review of agent-produced code before merging.
