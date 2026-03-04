# Error Recovery Quick Reference

> Quick-reference card for agent team error handling. Full details in `reference/error-recovery.md`.

## Error Categories

| # | Category | Example | Detection | Recovery Tier |
|---|----------|---------|-----------|---------------|
| 1 | Input validation | Bad task params | Agent reports confusion | Tier 1: Retry with clearer prompt |
| 2 | Tool not found | MCP server down | Tool call error | Tier 3: Model fallback |
| 3 | Parameter mismatch | Wrong args | Tool returns error | Tier 1: Retry |
| 4 | API failure | 500 error | HTTP status code | Tier 1: Retry with backoff |
| 5 | Auth/permission | 403 forbidden | HTTP status/hook | Tier 5: Human escalation |
| 6 | Timeout | Long operation | Hook timeout | Tier 1: Retry with longer timeout |
| 7 | Network failure | DNS/connection | Connection error | Tier 1: Retry with backoff |
| 8 | Rate limit | 429 Too Many Requests | HTTP status | Tier 1: Retry with backoff |
| 9 | Malformed output | Unparseable response | Validation check | Tier 2: Undo-and-retry |
| 10 | Context exhaustion | Window full | Auto-compact triggered | Tier 4: Checkpoint recovery |
| 11 | Silent failure | Wrong but no error | Code review/tests | Tier 2: Undo-and-retry |
| 12 | Goal drift | Wrong task | Observer/lead review | Tier 5: Human escalation |

## Escalation Thresholds

| Confidence Level | Action |
|-----------------|--------|
| >90% | Auto-proceed, async review |
| 80-90% | Async review required |
| 70-80% | Synchronous approval required |
| <70% | Escalate to human immediately |

## Recovery Tiers

| Tier | Strategy | When | Max Attempts |
|------|----------|------|-------------|
| 1 | Retry with backoff | Transient failures | 3 |
| 2 | Undo-and-retry | Partial broken work | 2 |
| 3 | Model fallback | Model-specific issue | 1 |
| 4 | Checkpoint recovery | Task-level failure | 1 |
| 5 | Human escalation | All else fails | - |
