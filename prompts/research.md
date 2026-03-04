# Template D: Research & Exploration

> Copy the prompt below, fill in the `[BRACKETS]`, and paste into Claude Code.
> Uses parallel researchers with different focus areas, optionally
> followed by a prototype builder to validate feasibility.

---

## Team Structure

```
Team: research
Teammates:
  1. codebase-explorer  (Explore agent, model: haiku)
  2. docs-researcher    (general-purpose, plan mode)
  3. prototype-builder  (general-purpose, acceptEdits, worktree)
```

## Task Flow

```
Explorer + researcher work in parallel -> share findings
-> prototype builder validates feasibility -> lead synthesizes
```

---

## Prompt (Copy & Paste)

```
Create an agent team for research and exploration.

The goal is: [DESCRIBE WHAT YOU NEED TO UNDERSTAND - e.g., "how to add
real-time notifications to our app", "whether we should migrate from
REST to GraphQL", "how the payment processing pipeline works"]

Spawn 3 teammates:

1. "codebase-explorer" - An Explore agent to deeply analyze the existing
   codebase. Focus on:
   - [e.g., "How the current notification system works"]
   - [e.g., "What patterns are used for real-time features"]
   - [e.g., "Which files and modules would need to change"]
   Model: haiku (fast, cheap for exploration). Permission: plan (read-only).

2. "docs-researcher" - A general-purpose agent to research external
   documentation and best practices. Focus on:
   - [e.g., "WebSocket vs SSE vs polling trade-offs"]
   - [e.g., "How Socket.io integrates with Express"]
   - [e.g., "Best practices for scaling real-time features"]
   Permission: plan (read-only). Can use WebSearch and WebFetch.

3. "prototype-builder" - A general-purpose agent to build quick
   proof-of-concepts based on the research findings. Focus on:
   - [e.g., "Create a minimal WebSocket server + client demo"]
   - [e.g., "Validate that our auth middleware works with WS connections"]
   Use a worktree for isolation. Permission: acceptEdits.
   Wait for explorer and researcher findings before starting.

The explorer and researcher should share findings with each other.
The prototype builder should start only after initial research is done.
I want a final summary of: feasibility, recommended approach, effort estimate.
```

---

## Variations

- **Pure research (no prototype)**: Drop the prototype-builder. Use just 2-3 researchers.
- **Technology evaluation**: Have each researcher investigate a different technology option.
- **Migration assessment**: Explorer maps current state, researcher maps target state, prototype validates migration path.
