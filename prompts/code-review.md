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
