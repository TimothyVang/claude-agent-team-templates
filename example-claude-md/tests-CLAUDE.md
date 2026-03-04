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
