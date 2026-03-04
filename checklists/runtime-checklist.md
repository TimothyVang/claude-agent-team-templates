# Runtime Checklist

> Use while the agent team is actively working.

## Monitoring

- [ ] **Monitor progress**: Use Shift+Down (in-process mode) or check split panes (tmux).

- [ ] **Check task list regularly**: Ensure teammates are:
  - Marking tasks `in_progress` when starting
  - Marking tasks `completed` when done
  - Creating new tasks when they discover additional work

- [ ] **Watch for stuck teammates**: If a teammate has been idle for too long:
  - Check if they're blocked by a dependency
  - Send them a direct message to check status
  - Update task dependencies if needed

## Failure Detection

- [ ] **Watch for goal drift**: Agent working on something other than assigned task.

- [ ] **Check for loops**: Same actions/errors repeating. The `check-remaining-work.sh` hook will warn if same TODOs persist across 3+ checks.

- [ ] **Monitor token usage**: Watch for agents with excessive tool calls. Consider swapping to cheaper model for read-only tasks.

- [ ] **Follow error recovery ladder**: Tier 1 retry → Tier 2 undo-and-retry → Tier 3 model fallback → Tier 4 checkpoint → Tier 5 human escalation. See `reference/error-recovery.md`.

## Intervention Points

- [ ] **Redirect failing approaches early**: If a teammate is going down the wrong path,
  message them directly with course correction. Don't wait until they finish.

- [ ] **Unblock stuck teammates**: Update task dependencies or reassign tasks as needed.

- [ ] **Prevent lead from implementing**: If the lead starts writing code instead of
  delegating, remind it to wait for teammates.

- [ ] **Enforce max 2 CI rounds**: If a fix attempt fails twice, flag for human review
  instead of retrying indefinitely.

## Communication

- [ ] **Synthesize findings as they come in**: Don't wait until the end. Build a running
  summary of what each teammate has found/built.

- [ ] **Avoid unnecessary broadcasts**: Use direct messages for teammate-specific info.
  Only broadcast for critical, team-wide issues.

- [ ] **Check peer collaboration**: When teammates message each other, review the
  summaries in idle notifications to stay informed.

## Quality

- [ ] **Verify file ownership is respected**: No two teammates should have edited
  the same file. Check with `git log --name-only` if needed.

- [ ] **Watch for anti-patterns**:
  - Tasks too granular (overhead > benefit)
  - Teammates blocked waiting for each other (circular dependencies)
  - Too many retries on failing tests
  - Teammates duplicating each other's work
