# Template C: Code Review / Audit

> Copy the prompt below, fill in the `[BRACKETS]`, and paste into Claude Code.
> Uses parallel reviewers each focused on a different quality dimension.

---

## Team Structure

```
Team: code-review
Teammates:
  1. security-reviewer   (read-only, model: sonnet)
  2. performance-reviewer (read-only, model: sonnet)
  3. quality-reviewer     (read-only, model: sonnet)
```

## Task Flow

```
All review in parallel -> lead synthesizes into unified report
organized by priority: critical > warnings > suggestions
```

---

## Prompt (Copy & Paste)

```
Create an agent team to review code.

The scope is: [DESCRIBE WHAT TO REVIEW - e.g., "PR #42", "the src/auth/ module",
"all changes in the last 3 commits"]

Spawn 3 reviewer teammates:

1. "security-reviewer" - Focus on security implications:
   - Input validation and sanitization
   - Authentication/authorization gaps
   - SQL injection, XSS, CSRF vulnerabilities
   - Secrets or credentials in code
   - Dependency vulnerabilities
   Model: sonnet. Permission: plan (read-only).

2. "performance-reviewer" - Focus on performance impact:
   - N+1 queries and unnecessary database calls
   - Memory leaks and unbounded growth
   - Algorithmic complexity (O(n^2) or worse)
   - Missing caching opportunities
   - Bundle size impact (frontend)
   Model: sonnet. Permission: plan (read-only).

3. "quality-reviewer" - Focus on code quality:
   - Test coverage for new/changed code
   - Error handling completeness
   - Code clarity and maintainability
   - Adherence to project conventions
   - Dead code or unused imports
   Model: sonnet. Permission: plan (read-only).

Each reviewer should:
- Read the relevant files and changes
- Report findings with file:line references
- Rate each finding: CRITICAL / WARNING / SUGGESTION
- Explain WHY it's an issue, not just WHAT

I will synthesize their findings into a unified report.
```

---

## Customization Options

- **Add accessibility reviewer**: For frontend changes, add a 4th reviewer focused on a11y.
- **Add API reviewer**: For API changes, check backward compatibility, versioning, documentation.
- **Focused review**: If you only care about security, use just the security reviewer as a subagent instead of a full team.

> **File ownership note**: All reviewers work in read-only mode (`plan` permission), so file ownership conflicts are not a concern. Reviewers cannot edit files — they only read and report findings. If you add a fix-implementer to act on findings, assign file ownership to that agent.

---

## Worked Example

> **Scope**: PR #47 adds a payment processing module — new Stripe integration,
> checkout endpoint, and webhook handler.

### Filled-In Prompt

```
Create an agent team to review code.

The scope is: PR #47 — adds src/services/payment.ts (Stripe integration),
src/api/handlers/checkout.ts (POST /api/checkout), and
src/api/handlers/webhook.ts (POST /api/webhook/stripe).
Also includes Prisma migration 0012_add_payment_tables.sql.

Spawn 3 reviewer teammates:

1. "security-reviewer" - Focus on security implications:
   - PCI compliance: confirm card data is never logged or stored (only Stripe tokens)
   - SQL injection risk in raw queries inside the migration file
   - Webhook signature verification: confirm src/api/handlers/webhook.ts
     validates the Stripe-Signature header using stripe.webhooks.constructEvent()
   - CSRF protection on the checkout endpoint
   - Secrets exposure: ensure STRIPE_SECRET_KEY is read from env, never hardcoded
   Model: sonnet. Permission: plan (read-only).

2. "performance-reviewer" - Focus on performance impact:
   - N+1 queries: check if checkout handler fetches cart items one-by-one
     vs. a single Prisma query with include
   - Webhook handler idempotency: verify duplicate webhook events (Stripe
     retries) don't create duplicate orders — check for idempotency key usage
   - Synchronous Stripe API calls in the request path: should these be async
     with a queue for resilience?
   - Response times: flag any calls that could block > 200ms without a timeout
   Model: sonnet. Permission: plan (read-only).

3. "quality-reviewer" - Focus on code quality:
   - Test coverage: are there tests for the Stripe webhook handler?
     Are failure cases (card declined, network timeout) tested?
   - Error handling: what happens if Stripe returns an error mid-charge?
     Is the order rolled back atomically?
   - Code clarity: are Stripe error codes mapped to user-friendly messages?
   - Adherence to project conventions: does checkout.ts follow the
     auth → validate → handler → response chain from routes.ts?
   Model: sonnet. Permission: plan (read-only).

Each reviewer should:
- Read src/services/payment.ts, src/api/handlers/checkout.ts,
  src/api/handlers/webhook.ts, and the Prisma migration
- Report findings with file:line references
- Rate each finding: CRITICAL / WARNING / SUGGESTION
- Explain WHY it's an issue, not just WHAT

I will synthesize their findings into a unified report.
```
