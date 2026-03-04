# Template E: Refactoring

> Copy the prompt below, fill in the `[BRACKETS]`, and paste into Claude Code.
> Uses an analyzer to plan the refactor, parallel migrators to execute,
> and a validator to ensure nothing breaks.

---

## Team Structure

```
Team: refactor
Teammates:
  1. analyzer    (Plan agent, plan mode, require plan approval)
  2. migrator-1  (general-purpose, acceptEdits, worktree)
  3. migrator-2  (general-purpose, acceptEdits, worktree)
  4. validator   (general-purpose, acceptEdits)
```

## Task Flow

```
analyzer designs migration plan -> [plan approval]
-> migrators work in parallel on distinct modules
-> validator runs full test suite -> iterate if failures (max 2 rounds)
```

---

## Prompt (Copy & Paste)

```
Create an agent team for a refactoring task.

The goal is: [DESCRIBE THE REFACTORING - e.g., "migrate from class components
to functional components with hooks", "extract shared logic into a services layer",
"convert callback-based code to async/await"]

Current state: [DESCRIBE WHAT EXISTS NOW]
Target state: [DESCRIBE WHAT IT SHOULD LOOK LIKE AFTER]

Spawn 4 teammates:

1. "analyzer" - A Plan agent to analyze the codebase and design a migration plan.
   Should identify:
   - All files that need to change
   - The correct order of changes (dependency graph)
   - File ownership boundaries for parallel work
   - Potential breaking changes and how to handle them
   Require plan approval before any migration begins.

2. "migrator-1" - A general-purpose agent to refactor [MODULE A]:
   Files: [e.g., src/components/auth/**, src/components/user/**]
   Use a worktree for isolation. Permission: acceptEdits.

3. "migrator-2" - A general-purpose agent to refactor [MODULE B]:
   Files: [e.g., src/components/dashboard/**, src/components/settings/**]
   Use a worktree for isolation. Permission: acceptEdits.

4. "validator" - A general-purpose agent to run the full test suite after
   migration and verify no regressions. Should:
   - Run all tests after each migrator completes
   - Report any failures back to the relevant migrator
   - Verify that the refactored code follows the target patterns
   Permission: acceptEdits. Max 2 CI rounds (Stripe's rule).

File ownership (NO overlaps):
- analyzer: read-only
- migrator-1: [FILE PATTERNS]
- migrator-2: [FILE PATTERNS]
- validator: tests/** (and can read all src/ files)

The analyzer must complete and get approval first.
Migrators work in parallel after approval.
Validator runs after each migrator marks their work complete.
```

---

## Customization Options

- **More migrators**: For large refactors, add migrator-3, migrator-4 with distinct file ownership.
- **No worktrees**: If changes are small and well-isolated, skip worktrees for simpler workflow.
- **Incremental**: Break the refactor into phases. Run this template once per phase.
- **Add reviewer**: Add a code-review teammate to check refactored code before validation.

---

## Worked Example

> **Goal**: Migrate from Express middleware functions to NestJS Guards for
> authentication and authorization across 3 modules.

### Filled-In Prompt

```
Create an agent team for a refactoring task.

The goal is: Migrate authentication and authorization from Express-style
middleware functions to NestJS Guards. All route protection currently
uses app.use(authMiddleware) or router.use(requireRole('admin')).

Current state: Express middleware in src/middleware/auth.middleware.ts and
src/middleware/roles.middleware.ts applied globally or per-router.
Target state: NestJS JwtAuthGuard and RolesGuard applied via @UseGuards()
decorator on controllers. Guards should use the existing JWT logic from
src/auth/tokens.ts without rewriting it.

Spawn 4 teammates:

1. "analyzer" (Plan agent, plan mode, require plan approval) — Map all
   files using authMiddleware or requireRole(), identify the correct NestJS
   Guard pattern for this codebase, define file ownership for migrators,
   flag any global middleware that needs special handling in main.ts.
   Output: migration plan at docs/guard-migration-plan.md listing every
   file that changes.

2. "migrator-1" (general-purpose, acceptEdits, worktree) — Migrate the
   Users module: src/users/users.controller.ts, src/users/users.module.ts.
   Replace all middleware-based protection with @UseGuards(JwtAuthGuard)
   and @Roles() decorator. Create src/auth/guards/jwt-auth.guard.ts and
   src/auth/guards/roles.guard.ts (shared, write once).

3. "migrator-2" (general-purpose, acceptEdits, worktree) — Migrate the
   Posts and Comments modules: src/posts/posts.controller.ts,
   src/comments/comments.controller.ts, their respective module files.
   Import guards from src/auth/guards/ (written by migrator-1, read-only
   for migrator-2).

4. "validator" (general-purpose, acceptEdits) — After both migrators
   complete, run the full test suite (npm test), verify all auth-protected
   routes still return 401 for unauthenticated requests and 403 for
   insufficient roles, check that public routes are not accidentally
   protected. Max 2 CI rounds.

File ownership (NO overlaps):
- analyzer: read-only
- migrator-1: src/users/, src/auth/guards/ (creates the guards)
- migrator-2: src/posts/, src/comments/ (reads guards, does not edit them)
- validator: tests/ (and can read all src/ files)

Analyzer must complete and get approval first.
Migrators work in parallel after approval (migrator-2 waits for guards to exist).
Validator runs after both migrators mark work complete.

Acceptance criteria:
- [ ] Zero calls to authMiddleware or requireRole() remain in src/
- [ ] All protected routes return 401 without valid JWT
- [ ] All admin routes return 403 for non-admin JWT
- [ ] All existing tests pass with no modifications to test files
```
