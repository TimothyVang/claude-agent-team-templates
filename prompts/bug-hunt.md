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

---

## Worked Example

> **Bug**: Users report intermittent 500 errors on checkout. Happens ~5% of
> the time under load. Error: "Cannot read properties of undefined (reading 'price')".

### Filled-In Prompt

```
Create an agent team to investigate a bug.

The bug is: Intermittent 500 errors on POST /api/checkout. Affects ~5% of
requests under load. Error in logs: "Cannot read properties of undefined
(reading 'price')" in src/services/order.ts line 84. Expected: order created
and confirmation email sent. Actual: 500 with no order created.

Reproduction steps:
1. Add 2+ items to cart
2. Submit checkout form rapidly (or simulate with 20 concurrent requests)
3. ~1 in 20 requests returns 500

Spawn 3 investigator teammates, each with a different hypothesis:

1. "investigator-1" - Hypothesis: Database connection pool exhaustion is
   causing inventory queries to return undefined when the pool is saturated.
   Investigate by: checking src/db/pool.ts pool size config, looking for
   unresolved promises that hold connections, reviewing connection leak patterns
   in src/services/inventory.ts.

2. "investigator-2" - Hypothesis: Race condition in the inventory check —
   two concurrent requests both see stock > 0, both decrement, one gets
   undefined on the second read after the row is already updated.
   Investigate by: checking src/services/inventory.ts for missing transactions,
   looking for SELECT then UPDATE patterns without row locking, reviewing
   any optimistic concurrency controls.

3. "investigator-3" - Hypothesis: Payment gateway timeout causing the order
   object to be in a partial state when the price field is read after an
   async timeout boundary.
   Investigate by: checking src/services/payment.ts timeout handling,
   looking for missing await or unhandled Promise rejections, checking if
   order.price is populated before or after the payment call.

All investigators should:
- Work in read-only mode (plan permission)
- Share findings with each other via direct messages
- Challenge each other's theories with evidence from the code
- Converge on the most likely root cause

After consensus, the investigator with the winning hypothesis implements the fix.
Use model: haiku for investigators to save tokens on the research phase.
```
