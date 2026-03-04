# Token Optimization Reference

> Deep-dive companion to [AGENT-TEAM-PLANNING-TEMPLATE.md](../AGENT-TEAM-PLANNING-TEMPLATE.md) Section 7: Token Optimization & Cost Control.
> See also: [delegate-mode.md](./delegate-mode.md) for permission mode impacts on token usage.

---

## Prompt Caching Mechanics

Claude Code caches system prompts for approximately 5 minutes after first use. Subsequent requests that share the same cached prefix skip re-processing, saving both time and tokens.

**What gets cached**: The system prompt prefix — everything from the start of the system prompt up to the first point of divergence from the cached version.

**What invalidates the cache**: Any change to the cached prefix. Even a single character difference causes a full cache miss. Changes to content *after* the cached prefix do not invalidate it.

**How to structure prompts for maximum cache hits**:

```
┌─────────────────────────────────┐  ← STABLE (cached)
│ Project context (CLAUDE.md)     │     Put these first, change rarely
│ Role definition                 │
│ Tool descriptions               │
│ Shared rules & conventions      │
├─────────────────────────────────┤  ← VARIABLE (not cached)
│ Current task description        │     Put these last, change per-task
│ Dynamic context (file contents) │
│ Conversation history            │
└─────────────────────────────────┘
```

**Practical rules**:
- Keep CLAUDE.md content at the top of agent prompts and change it rarely
- Put task-specific instructions at the end
- If multiple agents share the same role definition, they share the cache
- Avoid regenerating system prompts unnecessarily between tool calls

---

## Context Budget Calculator

Use this formula to estimate total token consumption for an agent team session:

```
Total tokens ≈
    (system_prompt × num_agents)
  + (task_prompt × num_tasks)
  + (tool_calls × avg_response_tokens)
  + (inter_agent_messages × avg_message_tokens)
  + (file_reads × avg_file_tokens)
  + (conversation_turns × avg_turn_tokens)
```

**Typical values for estimation**:

| Component | Typical Size | Notes |
|-----------|-------------|-------|
| System prompt (CLAUDE.md + role) | 2,000-5,000 tokens | Paid once per agent at start, cached after |
| Task prompt | 200-800 tokens | Per task assignment |
| Tool call + response | 500-2,000 tokens | Varies widely by tool |
| Inter-agent message | 100-500 tokens | Keep messages concise |
| File read (medium source file) | 500-3,000 tokens | ~4 chars per token |
| Conversation turn (agent thinking) | 300-1,500 tokens | Output tokens cost more |

**Example calculation for a 4-agent team with 20 tasks**:

```
System prompts:   4,000 × 4 agents     =   16,000
Task prompts:       500 × 20 tasks      =   10,000
Tool calls:       1,200 × 80 calls      =   96,000
Agent messages:     300 × 30 messages    =    9,000
File reads:       2,000 × 40 reads      =   80,000
Agent turns:        800 × 100 turns      =   80,000
                                         ─────────
Estimated total:                          ~291,000 tokens
```

---

## Model Routing Decision Tree

Choose the right model for each agent role to balance cost and capability:

```
Is this agent making code edits?
├── Yes
│   ├── Are the edits complex (multi-file, architectural)?
│   │   ├── Yes → Opus (highest capability, worth the cost)
│   │   └── No → Sonnet (good edits, lower cost)
│   └── Is this a simple find-and-replace or rename?
│       └── Yes → Haiku (sufficient for mechanical changes)
├── No — Is this agent doing research/reading only?
│   ├── Does it need deep reasoning about what it reads?
│   │   ├── Yes → Sonnet
│   │   └── No → Haiku (fast, cheap for summarization)
│   └── Is it a plan-mode architect reviewing designs?
│       └── Yes → Opus (complex judgment calls)
└── No — Is this agent running tests/verification?
    ├── Just running commands and checking output?
    │   └── Haiku (sufficient for pass/fail interpretation)
    └── Needs to diagnose failures and suggest fixes?
        └── Sonnet
```

**Quick reference**:

| Role | Recommended Model | Rationale |
|------|------------------|-----------|
| Team Lead / Architect | Opus | Complex coordination, judgment calls |
| Implementer (complex) | Opus or Sonnet | Multi-file edits need high capability |
| Implementer (simple) | Sonnet | Single-file, well-scoped changes |
| Researcher / Explorer | Sonnet or Haiku | Reading comprehension, summarization |
| Test Runner / Verifier | Haiku | Command execution, pass/fail checks |
| Observer / Reviewer | Sonnet | Needs judgment but not editing |

---

## Cost Benchmarks

Real-world token usage ranges for agent teams of varying sizes:

| Team Size | Tasks | Typical Token Range | Approximate Cost (Opus) | Approximate Cost (Sonnet) |
|-----------|-------|--------------------|-----------------------|--------------------------|
| 1 agent (solo) | 3-5 | 50K-150K | $1.50-$4.50 | $0.45-$1.35 |
| 2 agents | 6-10 | 100K-300K | $3.00-$9.00 | $0.90-$2.70 |
| 3 agents | 10-15 | 200K-500K | $6.00-$15.00 | $1.80-$4.50 |
| 4 agents | 15-20 | 300K-800K | $9.00-$24.00 | $2.70-$7.20 |
| 5 agents | 20-30 | 500K-1.2M | $15.00-$36.00 | $4.50-$10.80 |

**Cost reduction strategies** (cumulative savings):
1. Route non-editing agents to Haiku: **-30-50%**
2. Maximize prompt caching (stable prefixes): **-10-20%**
3. Keep CLAUDE.md under 500 lines: **-5-10%**
4. Use directory-scoped CLAUDE.md instead of one large file: **-5-15%**
5. Minimize file re-reads (read once, reference by line number): **-10-15%**

---

## Context Compaction Techniques

Prevent context exhaustion and reduce per-turn costs:

**1. Keep CLAUDE.md concise (< 500 lines)**
- Move detailed reference material to separate files (like this one)
- Only include information agents need on *every* turn in CLAUDE.md
- Use links to reference docs for deep dives

**2. Use directory-scoped CLAUDE.md files**
- Place a `CLAUDE.md` in each major directory (`src/auth/CLAUDE.md`, `tests/CLAUDE.md`)
- Agent only loads the scoped file when working in that directory
- Prevents loading irrelevant context for the entire project

**3. Minimize tool output in prompts**
- Use `head_limit` on Grep results to avoid flooding context
- Read specific line ranges instead of entire files when possible
- Prefer `files_with_matches` output mode for initial searches, then read specific files

**4. Compress conversation history**
- Claude Code automatically compresses old messages as context grows
- Structure work so each task is self-contained (agent can lose early history safely)
- Put critical information in CLAUDE.md or task descriptions, not in conversation

**5. Limit inter-agent message length**
- Use the structured message format (see [role-prompt-patterns.md](./role-prompt-patterns.md))
- Keep messages to subject + 2-3 sentences of body
- Include file paths and line numbers, not file contents

---

## Context Priority Hierarchy

When approaching context limits, prioritize retaining information in this order:

```
Priority 1 (never drop): System prompt + CLAUDE.md
    └── Agent identity, rules, project structure

Priority 2 (compress last): Current task description + acceptance criteria
    └── What the agent is supposed to be doing right now

Priority 3 (compress early): Files being actively edited
    └── Can be re-read from disk if needed

Priority 4 (compress first): Conversation history + old tool results
    └── Historical context, already acted upon

Priority 5 (drop if needed): Tool descriptions for unused tools
    └── Can be re-loaded when the tool is actually needed
```

**Rule of thumb**: If an agent is past 75% of its context window, it should finish its current subtask, summarize findings, and either complete or hand off remaining work to a fresh agent.
