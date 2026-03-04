# Template A: Full-Stack Feature Development

> Copy the prompt below, fill in the `[BRACKETS]`, and paste into Claude Code.

---

## Team Structure

```
Team: feature-dev
Teammates:
  1. architect   (Plan agent, plan mode, require plan approval)
  2. backend-dev (general-purpose, acceptEdits, worktree)
  3. frontend-dev (general-purpose, acceptEdits, worktree)
  4. tester      (general-purpose, acceptEdits)
```

## Task Flow

```
architect designs -> [plan approval] -> backend + frontend in parallel
-> tester writes tests -> lead synthesizes results
```

---

## Prompt (Copy & Paste)

```
Create an agent team for implementing a new feature.

The goal is: [DESCRIBE THE FEATURE IN 1-2 SENTENCES]

Spawn 4 teammates:

1. "architect" - a Plan agent to analyze the codebase and design the
   implementation approach. Require plan approval before any coding begins.
   Focus on: identifying existing patterns, defining file ownership
   boundaries, and creating an implementation blueprint.

2. "backend-dev" - a general-purpose agent to implement the backend:
   [LIST BACKEND SCOPE - e.g., API endpoints, database schema, business logic].
   Use a worktree for isolation. Permission: acceptEdits.

3. "frontend-dev" - a general-purpose agent to implement the frontend:
   [LIST FRONTEND SCOPE - e.g., UI components, state management, API integration].
   Use a worktree for isolation. Permission: acceptEdits.

4. "tester" - a general-purpose agent to write comprehensive tests:
   [LIST TEST SCOPE - e.g., unit tests for API, integration tests, component tests].
   Permission: acceptEdits.

File ownership (NO overlaps):
- architect: read-only (no file edits)
- backend-dev: [e.g., src/api/**, src/services/**, src/models/**]
- frontend-dev: [e.g., src/components/**, src/hooks/**, src/pages/**]
- tester: [e.g., tests/**]

The architect must complete their plan and get approval first.
Backend and frontend should work in parallel after approval.
The tester should start after at least one implementer has committed initial work.
```

---

## Customization Options

- **Smaller team**: Drop the architect if you already know the approach. Drop the tester if tests aren't needed yet.
- **Add a reviewer**: Add a 5th teammate with `model: sonnet, permission: plan` to review code as it's written.
- **Monorepo**: Adjust file ownership to `packages/backend/**` and `packages/frontend/**`.

---

## Worked Example

> **Goal**: Add Google OAuth2 login to an existing Next.js 14 app with Prisma + PostgreSQL.

### Filled-In Prompt

```
Create a team called `feature-dev`.

The goal is: Add Google OAuth2 login so users can sign in with their Google
account. Store OAuth tokens in the existing Prisma User model. Add a
"Sign in with Google" button to the login page.

Spawn 4 teammates:

1. "architect" (Plan agent, plan mode, require plan approval) — Design the
   OAuth flow, callback handling, and session management approach. Identify
   how NextAuth integrates with the existing Prisma adapter. Output:
   architecture doc at docs/oauth-design.md.

2. "backend-dev" (general-purpose, acceptEdits) — Implement OAuth callback
   route at src/app/api/auth/[...nextauth]/route.ts, update Prisma schema
   with Account and Session models, configure NextAuth with GoogleProvider,
   add NEXTAUTH_SECRET and GOOGLE_CLIENT_ID/SECRET to env.

3. "frontend-dev" (general-purpose, acceptEdits) — Add Google sign-in button
   to src/app/login/page.tsx, update src/components/AuthProvider.tsx to wrap
   the app with SessionProvider, add loading and error states to the login UI.

4. "tester" (general-purpose, acceptEdits) — Write integration tests for the
   OAuth flow in tests/auth/oauth.test.ts, mock Google OAuth responses with
   jest.mock('next-auth'), test session persistence across page navigations.

File ownership (NO overlaps):
- architect: read-only (docs/ only)
- backend-dev: src/app/api/, prisma/, src/lib/auth.ts
- frontend-dev: src/app/login/, src/components/Auth*
- tester: tests/

The architect must complete and get approval first.
Backend and frontend work in parallel after architect approval.
Tester starts after backend-dev commits the NextAuth route.

Acceptance criteria:
- [ ] Google OAuth flow works end-to-end (login → callback → session)
- [ ] User record created/updated in PostgreSQL on first and repeat login
- [ ] Session persists across page refreshes (checked via useSession hook)
- [ ] Sign-in button shows loading state during OAuth redirect
- [ ] All tests pass, including mock OAuth callback test
```
