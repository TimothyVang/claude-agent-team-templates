# Template G: Library / Framework Migration

> Copy the prompt below, fill in the `[BRACKETS]`, and paste into Claude Code.
> Uses the "canary migration" pattern: analyze first, migrate one module as a
> canary, validate, then migrate the rest in parallel.

---

## Team Structure

```
Team: migration
Teammates:
  1. analyzer              (Explore agent, haiku model, plan mode)
  2. compatibility-checker (general-purpose, sonnet model, plan mode)
  3. migrator-1            (general-purpose, inherit model, acceptEdits)
  4. migrator-2            (general-purpose, inherit model, acceptEdits)
  5. validator             (general-purpose, inherit model, acceptEdits)
```

## Task Flow

```
Phase 1: ANALYZE (parallel)
  analyzer maps all usages of old library
  compatibility-checker identifies breaking changes in new version

Phase 2: PLAN
  Lead creates migration plan, assigns file batches

Phase 3: CANARY MIGRATION
  migrator-1 migrates one module as canary
  validator runs tests on canary module

Phase 4: FULL MIGRATION (parallel)
  migrator-1 + migrator-2 split remaining files

Phase 5: VALIDATE
  validator runs full test suite + type checks
```

---

## Prompt (Copy & Paste)

```
Create an agent team for a library/framework migration.

The migration is: [DESCRIBE - e.g., "Upgrade React Router from v5 to v6",
"Migrate from Mocha+Chai to Vitest", "Replace Moment.js with date-fns",
"Upgrade Next.js from 13 to 15"]

Current version: [e.g., react-router@5.3.4]
Target version: [e.g., react-router@6.20.0]

Known breaking changes: [LIST ANY YOU ALREADY KNOW, or "unknown - needs analysis"]

Spawn 5 teammates:

1. "analyzer" - An Explore agent to map all usages of the old library.
   Model: haiku. Permission: plan (read-only).
   Should produce:
   - Complete list of files importing/using the old library
   - Usage patterns categorized by type (e.g., "uses withRouter HOC", "uses useHistory hook")
   - Dependency graph showing which modules depend on the library
   - Recommended migration order (leaf modules first)

2. "compatibility-checker" - A general-purpose agent to check the new version's API.
   Model: sonnet. Permission: plan (read-only).
   Should produce:
   - Breaking changes between old and new versions
   - Mapping of old API -> new API for each usage pattern found by analyzer
   - List of features with no direct equivalent (need workarounds)
   - Any new dependencies or peer dependencies required

3. "migrator-1" - A general-purpose agent for canary migration, then batch 1.
   Model: inherit. Permission: acceptEdits.
   Phase 3 (canary): Migrate [CANARY MODULE - e.g., src/components/auth/**]
   Phase 4 (batch): Migrate [BATCH 1 FILES - e.g., src/components/dashboard/**, src/pages/**]

4. "migrator-2" - A general-purpose agent for batch 2 migration.
   Model: inherit. Permission: acceptEdits.
   Phase 4 (batch): Migrate [BATCH 2 FILES - e.g., src/components/settings/**, src/hooks/**]
   Waits for canary validation before starting.

5. "validator" - A general-purpose agent to run tests and verify correctness.
   Model: inherit. Permission: acceptEdits.
   Should:
   - Run tests after canary migration (Phase 3)
   - Report failures back to migrator-1 for canary fixes
   - Run full test suite + type checks after full migration (Phase 5)
   - Verify no remaining imports of the old library
   - Max 2 CI rounds per phase (Stripe's rule)

File ownership (NO overlaps):
- analyzer: read-only (scans entire codebase)
- compatibility-checker: read-only (reads docs and code)
- migrator-1: [CANARY MODULE] + [BATCH 1 FILES]
- migrator-2: [BATCH 2 FILES]
- validator: tests/**, package.json, lock files

Phase 1: analyzer and compatibility-checker work in parallel.
Phase 2: I will synthesize their findings and assign file batches.
Phase 3: migrator-1 does canary migration, validator tests it.
Phase 4: After canary passes, migrator-1 and migrator-2 split remaining files.
Phase 5: validator runs the full test suite and confirms zero old imports remain.
```

---

## Customization Options

- **Small migration**: Drop migrator-2 and have migrator-1 handle all files. Drop analyzer if you already know all usages.
- **Large migration**: Add migrator-3, migrator-4 for more parallelism. Split file ownership evenly.
- **Config-only migration**: If the migration is just config changes (e.g., ESLint flat config), drop migrators and have the validator apply + test changes directly.
- **Phased rollout**: Run this template once per phase (e.g., Phase 1: core modules, Phase 2: feature modules, Phase 3: test utilities).
- **Add reviewer**: Add a code-review teammate to check migration patterns before validator runs tests.

---

## Worked Example

> **Migration**: Upgrade React Router from v5.3.4 to v6.20.0.
> Known breaking changes: Switch→Routes, useHistory→useNavigate, component prop→element prop.

### Filled-In Prompt

```
Create an agent team for a library/framework migration.

The migration is: Upgrade React Router from v5 to v6. This affects route
definitions, navigation hooks, and route-based code splitting across the
entire frontend application.

Current version: react-router-dom@5.3.4
Target version: react-router-dom@6.20.0

Known breaking changes:
- <Switch> replaced by <Routes>
- useHistory() replaced by useNavigate()
- <Route component={X}> replaced by <Route element={<X />}>
- <Redirect> replaced by <Navigate>
- Nested routes now use relative paths and <Outlet>
- withRouter HOC removed (use hooks instead)

Spawn 5 teammates:

1. "analyzer" - An Explore agent to map all usages of react-router v5.
   Model: haiku. Permission: plan (read-only).
   Should produce:
   - Complete list of files importing from react-router-dom
   - Usage patterns categorized: Switch/Routes (14 files), useHistory (23 files),
     withRouter HOC (6 files), <Redirect> (8 files), <Route component={}> (31 files)
   - Dependency graph showing which route modules import from each other
   - Recommended migration order: leaf components first, then route config, then App.tsx
   Focus areas: src/components/**, src/pages/**, src/routes/**, src/hooks/**

2. "compatibility-checker" - A general-purpose agent to check v6 API changes.
   Model: sonnet. Permission: plan (read-only).
   Should produce:
   - Full mapping of old API to new API for each usage pattern:
     useHistory().push(path) → useNavigate()(path)
     useHistory().replace(path) → useNavigate()(path, { replace: true })
     <Switch><Route component={X} /></Switch> → <Routes><Route element={<X />} /></Routes>
     withRouter(Component) → use useNavigate/useLocation/useParams directly
     <Redirect to={path} /> → <Navigate to={path} replace />
   - Features with no direct equivalent: useHistory().listen() (need useEffect + useLocation)
   - New peer dependencies: react@>=16.8 (already satisfied)
   - Any v6-only features worth adopting (useSearchParams, loader/action)

3. "migrator-1" - A general-purpose agent for canary migration, then batch 1.
   Model: inherit. Permission: acceptEdits.
   Phase 3 (canary): Migrate src/components/auth/** — includes Login, Register,
   ForgotPassword pages with useHistory, Switch, and Redirect usage.
   Phase 4 (batch): Migrate src/components/dashboard/**, src/pages/**

4. "migrator-2" - A general-purpose agent for batch 2 migration.
   Model: inherit. Permission: acceptEdits.
   Phase 4 (batch): Migrate src/components/settings/**, src/hooks/useAuth.ts,
   src/hooks/useNavigation.ts, src/routes/index.tsx
   Waits for canary validation before starting.

5. "validator" - A general-purpose agent to run tests and verify correctness.
   Model: inherit. Permission: acceptEdits.
   Should:
   - Run tests after canary migration (Phase 3): npm test -- --testPathPattern=auth
   - Report failures back to migrator-1 for canary fixes
   - Run full test suite + TypeScript check after full migration (Phase 5)
   - Verify no remaining imports of react-router-dom v5 patterns:
     grep -r "useHistory\|withRouter\|<Switch\|<Redirect" src/
   - Max 2 CI rounds per phase

File ownership (NO overlaps):
- analyzer: read-only (scans entire codebase)
- compatibility-checker: read-only (reads docs and code)
- migrator-1: src/components/auth/**, src/components/dashboard/**, src/pages/**
- migrator-2: src/components/settings/**, src/hooks/**, src/routes/**
- validator: tests/**, package.json, package-lock.json

Phase 1: analyzer and compatibility-checker work in parallel.
Phase 2: I will synthesize their findings and assign file batches.
Phase 3: migrator-1 does canary migration of auth module, validator tests it.
Phase 4: After canary passes, migrator-1 and migrator-2 split remaining files.
Phase 5: validator runs the full test suite and confirms zero old imports remain.
```
