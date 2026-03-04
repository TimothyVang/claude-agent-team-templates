# Auth Module Context

> This CLAUDE.md is scoped to the `src/auth/` directory.
> Only teammates working on auth-related files need this context.

## Module Purpose
Handles authentication, authorization, session management, and token lifecycle.

## Key Files
- `middleware.ts` - Auth middleware for route protection (authenticate → authorize → rate-limit → handler)
- `login.ts` - Login flow (credentials → token pair issuance)
- `tokens.ts` - JWT creation, validation, refresh (includes mutex for race-safe refresh)
- `permissions.ts` - Role-based access control (RBAC)
- `oauth.ts` - Google and GitHub OAuth provider config and callback handling
- `session.ts` - Redis-backed session store (connect-redis + express-session)
- `csrf.ts` - CSRF token generation and double-submit cookie validation
- `errors.ts` - Typed `AuthError` class hierarchy

## Patterns

### Session Middleware Chain
Every protected route passes through this chain in order:
```
authenticate → authorize → rate-limit → handler
```
- `authenticate`: validates JWT or session cookie, attaches `req.user`
- `authorize`: checks `hasPermission(req.user, resource, action)` from `permissions.ts`
- `rate-limit`: per-user rate limiter (100 req/min, keyed on `req.user.id`)
- `handler`: business logic — runs only if all prior middleware pass

### Token Lifecycle
- Access token: JWT, 15min expiry, signed with `ACCESS_TOKEN_SECRET`
- Refresh token: JWT, 7day expiry, stored in httpOnly cookie, signed with `REFRESH_TOKEN_SECRET`
- Refresh uses a mutex lock in `tokens.ts` to prevent race condition when two
  concurrent requests both trigger refresh (only one issues new tokens, the other
  waits and reuses the new pair)

### OAuth Provider Abstraction
- `oauth.ts` exports `getOAuthProvider(name: 'google' | 'github')` — returns a configured passport strategy
- Callback handlers normalize provider profiles to `{ id, email, displayName }` before user lookup
- On first login: creates User record. On repeat: updates `lastLoginAt` only.

### CSRF Validation
- `csrf.ts` generates a token per session stored in `req.session.csrfToken`
- All state-changing requests (POST/PUT/PATCH/DELETE) must include `X-CSRF-Token` header
- Use `verifyCsrf(req)` helper — throws `AuthError('CSRF_INVALID')` on mismatch

### RBAC
- Use `hasPermission(user, resource, action)` for all authorization checks
- Resources: `'post' | 'comment' | 'user' | 'admin'`
- Actions: `'read' | 'write' | 'delete' | 'manage'`
- Role hierarchy: `admin > moderator > user > guest`

## Dependencies
- `jsonwebtoken` for JWT operations
- `bcrypt` for password hashing (work factor: 12)
- `passport` + `passport-google-oauth20` + `passport-github2` for OAuth
- `connect-redis` + `ioredis` for Redis session store
- `src/models/user.ts` for User model

## Import Rules
- Auth module must NOT import from `src/api/` — dependency direction is `api → auth`, never reverse
- `tokens.ts` may import from `src/models/` but not from `src/services/`
- Do not add circular deps: `oauth.ts` → `login.ts` → `tokens.ts` (one direction only)

## Testing Notes
- Mock `jsonwebtoken` in tests — do not generate real tokens
- Mock Redis client in session tests: `jest.mock('ioredis')`
- Use `createTestUser()` helper from `tests/helpers.ts`
- Use `createTestToken(userId, overrides?)` to generate tokens with specific expiry/roles for edge cases

## Critical Security Notes
- **Never log full JWTs** — log only the `sub` claim (user ID) for traceability
- **Always set `httpOnly: true` and `secure: true`** on auth cookies — no exceptions
- **Never store plaintext passwords** — always bcrypt before persisting; never log password fields
- **Token refresh race condition** — always use the mutex lock in `tokens.ts`; do not add direct `sign()` calls outside that module
- **OAuth state parameter** — always validate the `state` param in OAuth callbacks to prevent CSRF on the OAuth flow itself
- **Rotate secrets on breach** — `ACCESS_TOKEN_SECRET` and `REFRESH_TOKEN_SECRET` are in `.env`; invalidate all active tokens by rotating secrets
