# Template I: Plan-First Development

> Maximum safety for high-stakes changes. All agents plan before implementing.
> Uses `plan_mode_required` to ensure the lead reviews every approach before
> any code is written.
>
> **Cost justification**: Plan mode costs ~10K tokens per agent. An agent going
> in the wrong direction costs 500K+ tokens to redo. Plan-first prevents the
> most expensive class of failures.

---

## When to Use

- Database schema changes or migrations
- Security-sensitive code (auth, payments, encryption)
- Architectural refactors affecting 10+ files
- Any change where "undo" is expensive or risky

---

## Team Structure

```
Team: plan-first
Teammates:
  1. architect       (Plan agent, plan_mode_required, model: sonnet)
  2. implementer-1   (general-purpose, plan_mode_required → acceptEdits after approval)
  3. implementer-2   (general-purpose, plan_mode_required → acceptEdits after approval)
  4. verifier        (general-purpose, acceptEdits)
```

## Task Flow

```
Phase 1: All agents explore codebase (read-only)
       -> Each agent writes their plan
Phase 2: Lead reviews and approves/rejects each plan
       -> Rejected plans are revised and resubmitted
Phase 3: Approved agents implement (file ownership enforced)
Phase 4: Verifier runs tests and checks for regressions
```

---

## Workflow Phases

### Phase 1: Explore & Plan (all agents, read-only)

All teammates explore the codebase and write their implementation plans.
No code changes allowed in this phase. Each agent outputs a plan document
for lead review. Plans must include: list of files to change, description
of each change, risk assessment, and rollback strategy.

### Phase 2: Plan Review (lead only)

Lead reviews each plan using `plan_approval_response`:
- **Approve**: agent exits plan mode and proceeds to Phase 3
- **Reject with feedback**: agent revises plan and resubmits

Common rejection reasons: overlapping file ownership, missing rollback
strategy, changes that are too large to be independently testable.

### Phase 3: Implement (approved agents only)

Approved agents implement their plans. File ownership is strictly enforced —
no agent touches files outside their designated scope. Agents whose plans
haven't been approved yet continue refining their plan.

### Phase 4: Verify

Verifier runs full test suite, checks for regressions across all changed
modules, and confirms each acceptance criterion is met.

---

## Prompt Template

```
Create a team called `plan-first`.

The goal is: [HIGH-STAKES CHANGE DESCRIPTION]

CRITICAL: All agents must plan before implementing. No code changes until
plans are reviewed and approved. This is a plan_mode_required team.

Spawn 4 teammates:

1. "architect" (Plan agent, plan_mode_required, model: sonnet) — Analyze
   the codebase and design the overall approach. Output a detailed plan at
   docs/[CHANGE]-design.md including: list of all files that will change,
   description of each change, dependency order, risk assessment (data loss,
   downtime, breaking changes), and rollback strategy.
   Scope: [DESCRIBE WHAT ARCHITECT SHOULD ANALYZE]

2. "implementer-1" (general-purpose, plan_mode_required) — Plan the
   implementation for [MODULE 1]. After plan approval, implement changes.
   Plan must include: exact files to change, before/after pseudocode for
   key logic, and how you will verify your changes work in isolation.
   File ownership: [MODULE 1 FILE PATTERNS]

3. "implementer-2" (general-purpose, plan_mode_required) — Plan the
   implementation for [MODULE 2]. After plan approval, implement changes.
   Plan must include: exact files to change, before/after pseudocode for
   key logic, and how you will verify your changes work in isolation.
   File ownership: [MODULE 2 FILE PATTERNS]

4. "verifier" (general-purpose, acceptEdits) — After all implementations
   complete, run the full test suite, check for regressions, and verify
   each acceptance criterion. If tests fail, report which implementer owns
   the failing code and wait for them to fix it. Max 2 CI rounds.
   Test scope: [DESCRIBE TEST COVERAGE REQUIRED]

File ownership (NO overlaps):
- architect: read-only (plans only in docs/)
- implementer-1: [MODULE 1 FILES]
- implementer-2: [MODULE 2 FILES]
- verifier: tests/ (can read all src/ files)

Plan approval criteria:
- [ ] No overlapping file ownership between implementers
- [ ] Rollback strategy defined for each change
- [ ] Risk assessment covers data loss, downtime, and breaking changes
- [ ] Changes are incremental and independently testable

Acceptance criteria:
- [SPECIFIC CRITERIA — e.g., "All existing tests pass"]
- [SPECIFIC CRITERIA — e.g., "No data loss on rollback"]
- [SPECIFIC CRITERIA — e.g., "Zero downtime deployment possible"]
```

---

## Customization Options

- **Solo high-stakes change**: Use just architect + 1 implementer + verifier for smaller changes.
- **Add a security reviewer**: For auth/payment changes, add a 5th teammate in plan mode to review for vulnerabilities.
- **Staged rollout**: Have implementer-1 complete and verify before implementer-2 starts (sequential instead of parallel).
- **Checkpoint files**: Have each implementer write a `docs/[module]-checkpoint.md` after each logical step so work can resume if interrupted.

---

## Worked Example

> **Goal**: Redesign the database schema for multi-tenancy — add `tenant_id`
> to all tables and enforce row-level isolation.

### Filled-In Prompt

```
Create a team called `plan-first`.

The goal is: Add multi-tenancy support by adding a tenant_id column to
all user-owned tables (users, posts, comments, orders) and enforcing
row-level isolation so tenants never see each other's data.

CRITICAL: All agents must plan before implementing. No code changes until
plans are approved. Schema migrations are irreversible without data loss.

Spawn 4 teammates:

1. "architect" (Plan agent, plan_mode_required, model: sonnet) — Analyze
   the full schema in prisma/schema.prisma and all Prisma queries across
   src/. Design the migration strategy: which tables need tenant_id, whether
   to use Postgres Row Level Security (RLS) or application-level filtering,
   how to handle the initial data migration for existing records, and the
   rollback strategy if the migration fails mid-flight.
   Output: docs/multi-tenancy-design.md

2. "implementer-1" (general-purpose, plan_mode_required) — Plan and
   implement the schema and data access layer changes.
   Plan must cover: Prisma schema changes, the migration SQL file, and
   updates to all Prisma queries in src/services/ to include tenant_id
   in every where clause.
   File ownership: prisma/, src/services/

3. "implementer-2" (general-purpose, plan_mode_required) — Plan and
   implement the API and middleware layer changes.
   Plan must cover: a new tenant resolution middleware that reads the
   subdomain or JWT claim and attaches req.tenantId, updates to all
   API handlers in src/api/handlers/ to pass tenantId to service calls.
   File ownership: src/api/, src/middleware/

4. "verifier" (general-purpose, acceptEdits) — After both implementers
   complete, run npm test, verify tenant isolation by checking that
   Tenant A queries cannot return Tenant B data, confirm the migration
   runs cleanly on a fresh database and on the existing seed data.
   Max 2 CI rounds.

File ownership (NO overlaps):
- architect: read-only (docs/ only)
- implementer-1: prisma/, src/services/
- implementer-2: src/api/, src/middleware/
- verifier: tests/ (can read all src/ files)

Plan approval criteria:
- [ ] Rollback strategy handles partial migration (some tenants migrated, some not)
- [ ] No overlapping file ownership between implementers
- [ ] Data migration for existing rows is idempotent (safe to re-run)
- [ ] Risk assessment covers: data exposure between tenants, migration downtime

Acceptance criteria:
- [ ] All existing tests pass with tenant_id added
- [ ] New test: Tenant A session cannot retrieve Tenant B records (returns 404)
- [ ] Prisma migration runs cleanly: npx prisma migrate deploy
- [ ] Zero raw SQL queries bypass the tenant filter
- [ ] Rollback script reverts schema without data loss
```
