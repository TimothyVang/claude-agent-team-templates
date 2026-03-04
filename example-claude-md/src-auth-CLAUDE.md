# Auth Module Context

> This CLAUDE.md is scoped to the `src/auth/` directory.
> Only teammates working on auth-related files need this context.

## Module Purpose
Handles authentication, authorization, session management, and token lifecycle.

## Key Files
- `middleware.ts` - Auth middleware for route protection
- `login.ts` - Login flow (credentials -> token)
- `tokens.ts` - JWT creation, validation, refresh
- `permissions.ts` - Role-based access control

## Patterns
- All auth errors use `AuthError` class from `./errors.ts`
- Tokens are JWTs with 15min access / 7day refresh lifecycle
- Middleware attaches `req.user` with `{ id, email, roles }`
- Use `hasPermission(user, resource, action)` for RBAC checks

## Dependencies
- `jsonwebtoken` for JWT operations
- `bcrypt` for password hashing
- `src/models/user.ts` for User model

## Testing Notes
- Mock `jsonwebtoken` in tests, don't generate real tokens
- Use `createTestUser()` helper from `tests/helpers.ts`
