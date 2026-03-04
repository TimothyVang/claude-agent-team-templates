# Project: [PROJECT NAME]

## Overview
[1-2 sentence description of what this project does]

## Tech Stack
- **Language**: [TypeScript/Python/Go/etc.]
- **Framework**: [Next.js/FastAPI/Express/etc.]
- **Database**: [PostgreSQL/MongoDB/etc.]
- **Testing**: [Jest/Pytest/Go test/etc.]

## Architecture
[Brief description of project structure]

```
src/
  auth/       # Authentication and authorization
  api/        # API routes and handlers
  models/     # Data models and schemas
  services/   # Business logic
  utils/      # Shared utilities
tests/        # Test files mirror src/ structure
```

## Key Conventions
- [Convention 1: e.g., "Use kebab-case for file names"]
- [Convention 2: e.g., "All API endpoints return { data, error } shape"]
- [Convention 3: e.g., "Use Zod for runtime validation"]

## Commands
```bash
npm run dev      # Start dev server
npm run build    # Production build
npm run test     # Run all tests
npm run lint     # Lint check
npm run typecheck # TypeScript check
```

## Important Patterns
- [Pattern 1: e.g., "Repository pattern for data access"]
- [Pattern 2: e.g., "Middleware chain for auth -> validation -> handler"]

## Error Handling Conventions
- All API calls must have error handling at system boundaries
- Use typed errors (not generic catch-all)
- Log errors with structured format: `{ error_code, message, context, timestamp }`
- Retry transient failures (network, rate limit) with exponential backoff
- Never silently swallow errors

## Guardrails
- Changes >500 LOC require human review before merge
- Database migrations require explicit approval
- No force-pushing to main/master branches
- All public API changes must update documentation
- Security-sensitive code (auth, crypto, user data) requires manual review

## Agent Team Notes
- **File ownership boundaries**: Define per-team in the prompt
- **Shared files** (require sequential access): [e.g., "src/types/index.ts", "src/config.ts"]
- **Test convention**: Tests live in `tests/` mirroring `src/` structure
