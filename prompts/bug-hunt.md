# Template B: Bug Investigation (Competing Hypotheses)

> Copy the prompt below, fill in the `[BRACKETS]`, and paste into Claude Code.
> This uses the "competing hypotheses" pattern where agents independently
> investigate different theories and challenge each other.

---

## Team Structure

```
Team: bug-hunt
Teammates:
  3-5 investigators (general-purpose, plan mode)
  Each starts with a different hypothesis
```

## Task Flow

```
All investigate in parallel -> share findings -> challenge each other
-> converge on root cause -> one implementer fixes
```

---

## Prompt (Copy & Paste)

```
Create an agent team to investigate a bug.

The bug is: [DESCRIBE THE BUG - what happens, when, expected vs actual behavior]

Reproduction steps:
1. [STEP 1]
2. [STEP 2]
3. [STEP 3]

Spawn 3 investigator teammates, each with a different hypothesis:

1. "investigator-1" - Hypothesis: [THEORY A - e.g., "The bug is in the auth
   middleware not refreshing expired tokens correctly"]
   Investigate by: [e.g., tracing the token refresh flow, checking expiry logic]

2. "investigator-2" - Hypothesis: [THEORY B - e.g., "The bug is a race condition
   in the state management when multiple API calls resolve simultaneously"]
   Investigate by: [e.g., checking async flows, looking for missing awaits]

3. "investigator-3" - Hypothesis: [THEORY C - e.g., "The bug is in the database
   query returning stale data due to caching"]
   Investigate by: [e.g., checking cache invalidation, query parameters]

All investigators should:
- Work in read-only mode (plan permission)
- Share their findings with each other via direct messages
- Challenge each other's theories with evidence
- Converge on the most likely root cause

After consensus, one investigator should be promoted to fix the bug.
Use model: haiku for investigators to save tokens on the research phase.
```

---

## Tips

- **More hypotheses = better coverage**: If you have 5 theories, spawn 5 investigators.
- **Devil's advocate**: Add one investigator whose job is specifically to disprove the others.
- **Timebox**: Set a mental limit. If no consensus after 10 minutes, intervene and steer.
- **Escalation**: If all hypotheses are disproven, that's valuable info. Create new ones.
