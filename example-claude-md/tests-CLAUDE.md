# Tests Module Context

> This CLAUDE.md is scoped to the `tests/` directory.
> Only teammates writing or running tests need this context.

## Structure
Tests mirror the `src/` directory structure:
```
tests/
  auth/          # Tests for src/auth/
  api/           # Tests for src/api/
  services/      # Tests for src/services/
  helpers.ts     # Shared test utilities
  setup.ts       # Global test setup/teardown
```

## Testing Framework
- **Runner**: Jest (or Vitest)
- **Assertions**: Built-in expect
- **Mocking**: jest.mock() for module mocks, jest.fn() for function mocks

## Conventions
- Test files: `[module].test.ts` (e.g., `login.test.ts`)
- Use `describe` blocks grouped by function/method
- Use `it` with descriptive names: `it('returns 401 when token is expired')`
- One assertion per test when possible

## Helpers
- `createTestUser(overrides?)` - Creates a user object for testing
- `createTestToken(userId)` - Creates a valid JWT for testing
- `mockRequest(overrides?)` - Creates a mock Express request
- `mockResponse()` - Creates a mock Express response with spy methods

## Running Tests
```bash
npm test                    # Run all tests
npm test -- --watch         # Watch mode
npm test -- path/to/file    # Run specific file
npm test -- --coverage      # With coverage report
```

## Integration Tests
- Use `supertest` for HTTP endpoint testing
- Database tests use a separate test database
- Clean up test data in `afterEach` hooks

## Test Database
- Uses a separate `test` database — connection string in `TEST_DATABASE_URL` env var
- Migrations are auto-applied in `tests/setup.ts` at suite start (`prisma migrate deploy`)
- Each test file gets a fresh transaction: opened in `beforeEach`, rolled back in `afterEach` — no manual cleanup needed
- Never run integration tests against the development or production database

## Fixture Patterns
Use factory functions from `tests/factories/` — do not construct objects inline:
- `createUser(overrides?)` — creates a User record with realistic defaults
- `createPost(userId, overrides?)` — creates a Post owned by given user
- `createOrder(userId, overrides?)` — creates an Order with line items

```ts
// Good
const user = await createUser({ role: 'admin' })
// Bad — brittle, misses required fields
const user = { id: '1', email: 'test@test.com' }
```

Factories handle FK constraints automatically (e.g., `createPost` calls `createUser` if no `userId` given).

## Snapshot Testing
- API response snapshots live in `tests/__snapshots__/`
- Update snapshots intentionally with `--updateSnapshot` flag — never auto-update in CI
- Snapshots are reviewed in code review like any other change

## Coverage Requirements
- **Minimum 80% line coverage** enforced in CI — PRs failing coverage are blocked
- **Auth module requires 95%** (`src/auth/` is security-critical)
- Check coverage locally: `npm test -- --coverage`
- Coverage report written to `coverage/lcov-report/index.html`

## CI Gotchas
- **Port 3001** is used for the test server — check for conflicts if tests fail with `EADDRINUSE`
- **Jest timeout**: default 5s is too short for DB integration tests — use `jest.setTimeout(10000)` in `tests/setup.ts` (already set) or per-file for especially slow suites
- **Parallel test files**: Jest runs files in parallel by default — if tests share state (e.g., a global counter), use `--runInBand` to serialize
- **Environment variables**: `tests/setup.ts` loads `.env.test` — make sure it exists before running tests locally
