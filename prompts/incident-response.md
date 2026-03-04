# Template F: Incident Response / Production Debugging

> Copy the prompt below, fill in the `[BRACKETS]`, and paste into Claude Code.
> Uses parallel investigation with an observer for accuracy, then converges
> on root cause before implementing a fix and writing a postmortem.

---

## Team Structure

```
Team: incident-response
Teammates:
  1. log-analyzer       (Explore agent, haiku model, plan mode)
  2. code-investigator  (general-purpose, sonnet model, plan mode)
  3. observer           (general-purpose, haiku model, plan mode)
  4. fix-implementer    (general-purpose, inherit model, acceptEdits)
```

## Task Flow

```
Phase 1: INVESTIGATE (parallel)
  log-analyzer + code-investigator work simultaneously
  observer monitors both for accuracy

Phase 2: CONVERGE
  Lead synthesizes findings, identifies root cause
  observer validates the conclusion

Phase 3: FIX
  fix-implementer applies the fix

Phase 4: VALIDATE
  Run tests, verify fix addresses root cause

Phase 5: POSTMORTEM
  Lead documents: timeline, root cause, fix, prevention
```

---

## Prompt (Copy & Paste)

```
Create an agent team for incident response / production debugging.

The incident is: [DESCRIBE THE INCIDENT - e.g., "500 errors spiking on /api/checkout
since 14:30 UTC", "users reporting intermittent login failures", "memory leak causing
OOM restarts every 2 hours"]

Known symptoms:
1. [SYMPTOM 1 - e.g., "HTTP 500 on POST /api/checkout"]
2. [SYMPTOM 2 - e.g., "Error logs show 'connection refused' to payment service"]
3. [SYMPTOM 3 - e.g., "Started after deploy v2.4.1 at 14:25 UTC"]

Relevant logs/traces: [PASTE LOG SNIPPETS OR FILE PATHS]

Spawn 4 teammates:

1. "log-analyzer" - An Explore agent to search logs, traces, and error outputs.
   Model: haiku. Permission: plan (read-only).
   Focus on:
   - [LOG LOCATIONS - e.g., logs/**, .output/**, error-reports/**]
   - Building a timeline of when the issue started
   - Identifying error patterns and frequencies
   - Correlating errors across services

2. "code-investigator" - A general-purpose agent to trace code paths.
   Model: sonnet. Permission: plan (read-only).
   Focus on:
   - [CODE AREAS - e.g., src/api/checkout/**, src/services/payment/**]
   - Reading the code paths that could produce the observed errors
   - Identifying recent changes that could have introduced the issue
   - Tracing execution flow from entry point to error

3. "observer" - A general-purpose agent to monitor accuracy of investigation.
   Model: haiku. Permission: plan (read-only).
   This is a devil's advocate role. Should:
   - Monitor log-analyzer's findings for misread logs or incorrect timelines
   - Monitor code-investigator's conclusions for missed code paths
   - Challenge assumptions and flag logical leaps
   - Report concerns directly to the lead

4. "fix-implementer" - A general-purpose agent to implement the fix.
   Model: inherit. Permission: acceptEdits.
   Waits until root cause is identified, then:
   - [FIX SCOPE - e.g., src/services/payment/**, src/api/checkout/**]
   - Implements the minimal fix for the root cause
   - Adds a regression test
   - Runs the test suite to verify no side effects

File ownership (NO overlaps):
- log-analyzer: read-only (logs/**, traces/**)
- code-investigator: read-only (src/**)
- observer: read-only (monitors other agents' messages)
- fix-implementer: [FILE PATTERNS FOR FIX - e.g., src/services/payment/**, tests/**]

Phase 1: log-analyzer and code-investigator investigate in parallel.
Observer monitors both and flags any inaccuracies.

Phase 2: After investigation, I will synthesize findings and identify root cause.
Observer validates the conclusion before we proceed.

Phase 3: fix-implementer applies the minimal fix.

Phase 4: fix-implementer runs tests. Max 2 CI rounds.

Phase 5: I will write a postmortem summary with:
- Timeline of the incident
- Root cause analysis
- Fix description
- Prevention recommendations
```

---

## Customization Options

- **No fix needed**: Drop fix-implementer if you only need root cause analysis (e.g., for a postmortem review of a past incident).
- **Multiple services**: Add more code-investigators, each focused on a different service boundary.
- **Live incident**: Add urgency instructions: "Prioritize finding a mitigation (rollback, feature flag) before root cause."
- **Without observer**: Drop the observer for simpler incidents where accuracy cross-checking is not needed.
- **Add rollback agent**: Add a 5th teammate to prepare a rollback plan in parallel while investigation happens.

---

## Worked Example

> **Incident**: HTTP 500 errors spiking on POST /api/checkout since 14:30 UTC.
> Correlates with deploy v2.4.1 at 14:25 UTC. Payment service returning
> connection refused intermittently.

### Filled-In Prompt

```
Create an agent team for incident response / production debugging.

The incident is: HTTP 500 errors spiking on POST /api/checkout since 14:30 UTC.
Error rate went from 0.1% to 12% after deploy v2.4.1 at 14:25 UTC. Users see
"Something went wrong" on the checkout page. Backend logs show "ECONNREFUSED"
when connecting to the payment service.

Known symptoms:
1. HTTP 500 on POST /api/checkout — 12% of requests failing
2. Error logs show "ECONNREFUSED 10.0.3.42:8443" from payment service client
3. Started after deploy v2.4.1 at 14:25 UTC — previous deploy v2.4.0 was stable

Relevant logs/traces:
- Application logs: logs/app-2026-03-04.log
- Payment service logs: logs/payment-svc-2026-03-04.log
- Deploy diff: `git diff v2.4.0...v2.4.1`

Spawn 4 teammates:

1. "log-analyzer" - An Explore agent to search logs, traces, and error outputs.
   Model: haiku. Permission: plan (read-only).
   Focus on:
   - logs/app-*.log, logs/payment-svc-*.log, .output/traces/**
   - Building a timeline of when errors started and their frequency pattern
   - Identifying whether all checkout requests fail or only specific cart configurations
   - Correlating payment service ECONNREFUSED with deploy timing vs load patterns

2. "code-investigator" - A general-purpose agent to trace code paths.
   Model: sonnet. Permission: plan (read-only).
   Focus on:
   - src/api/handlers/checkout.ts, src/services/payment.ts, src/config/services.ts
   - Reading the deploy diff (v2.4.0...v2.4.1) for changes to payment service configuration
   - Tracing the checkout handler → payment client → HTTP call chain
   - Checking if connection pool settings, timeouts, or service URLs changed in v2.4.1

3. "observer" - A general-purpose agent to monitor accuracy of investigation.
   Model: haiku. Permission: plan (read-only).
   This is a devil's advocate role. Should:
   - Monitor log-analyzer's timeline for gaps or misread timestamps
   - Monitor code-investigator's conclusions — ensure they checked config changes, not just code
   - Challenge the assumption that the deploy caused it (could be coincidental infra issue)
   - Report concerns directly to the lead

4. "fix-implementer" - A general-purpose agent to implement the fix.
   Model: inherit. Permission: acceptEdits.
   Waits until root cause is identified, then:
   - src/services/payment.ts, src/config/services.ts, tests/services/payment.test.ts
   - Implements the minimal fix for the root cause
   - Adds a regression test that simulates the failure condition
   - Runs the test suite to verify no side effects

File ownership (NO overlaps):
- log-analyzer: read-only (logs/**, .output/traces/**)
- code-investigator: read-only (src/**, config/**)
- observer: read-only (monitors other agents' messages)
- fix-implementer: src/services/payment.ts, src/config/services.ts, tests/services/payment.test.ts

Phase 1: log-analyzer and code-investigator investigate in parallel.
Observer monitors both and flags any inaccuracies.

Phase 2: After investigation, I will synthesize findings and identify root cause.
Observer validates the conclusion before we proceed.

Phase 3: fix-implementer applies the minimal fix.

Phase 4: fix-implementer runs tests. Max 2 CI rounds.

Phase 5: I will write a postmortem summary with:
- Timeline of the incident
- Root cause analysis
- Fix description
- Prevention recommendations
```
