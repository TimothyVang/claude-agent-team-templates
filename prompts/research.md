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

> **File ownership note**: The codebase-explorer and docs-researcher work in read-only mode (`plan` permission) and do not need file ownership. Only the prototype-builder (which uses `acceptEdits` in a worktree) needs file ownership, and since it works in an isolated worktree, conflicts with the main branch are avoided.

---

## Worked Example

> **Goal**: Evaluate WebSocket vs SSE for real-time notifications in an
> Express + React app currently using polling every 5 seconds.

### Filled-In Prompt

```
Create an agent team for research and exploration.

The goal is: Determine whether to replace our 5-second polling mechanism
with WebSockets or Server-Sent Events (SSE) for real-time notifications.
We need to understand current architecture impact, protocol trade-offs,
and validate with a working prototype.

Spawn 3 teammates:

1. "codebase-explorer" - An Explore agent to analyze the existing codebase.
   Focus on:
   - How the current polling works: find src/hooks/useNotifications.ts and
     the GET /api/notifications endpoint in src/api/handlers/notifications.ts
   - What the existing WebSocket infrastructure looks like (if any) in src/
   - Which files would need to change for each approach (count the blast radius)
   - Whether the auth middleware in src/auth/middleware.ts is compatible with
     WebSocket upgrade requests
   Model: haiku (fast, cheap for exploration). Permission: plan (read-only).

2. "docs-researcher" - A general-purpose agent to research external
   documentation and best practices. Focus on:
   - WebSocket vs SSE protocol trade-offs: latency, connection overhead,
     reconnection handling, browser support
   - How Socket.io or ws library integrates with Express — does it require
     a separate HTTP server or can it share the existing one?
   - SSE limitations: HTTP/2 multiplexing, proxy/load-balancer compatibility,
     max open connections per browser (6 for HTTP/1.1)
   - Best practices for scaling: Redis pub/sub adapter for WebSockets across
     multiple Node.js instances
   Permission: plan (read-only). Use WebSearch and WebFetch.

3. "prototype-builder" - A general-purpose agent to build quick
   proof-of-concepts based on research findings. Focus on:
   - Build a minimal SSE endpoint at src/api/handlers/notifications-sse.ts
     that streams notification events using res.write('data: ...\n\n')
   - Build a minimal WebSocket handler in src/ws/notifications.ts using the
     ws library, sharing the existing Express HTTP server
   - Verify both work with the auth middleware (attach userId from JWT)
   Use a worktree for isolation. Permission: acceptEdits.
   Wait for explorer and researcher findings before starting.

The explorer and researcher should share findings with each other and with me.
The prototype builder starts only after initial research is done.
Final summary should cover: feasibility of each approach, recommended choice,
files that need to change, and effort estimate (S/M/L).
```
