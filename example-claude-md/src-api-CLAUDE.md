# API Module Context

> This CLAUDE.md is scoped to the `src/api/` directory.
> Only teammates working on API routes need this context.

## Module Purpose
Defines REST API endpoints, request validation, and response formatting.

## Key Files
- `routes.ts` - Route definitions and full middleware chain
- `handlers/` - Request handlers organized by resource (users.ts, posts.ts, orders.ts)
- `validators/` - Zod schemas for request body/query/param validation
- `responses.ts` - Standard response helpers (`ok()`, `created()`, `notFound()`, `serverError()`)

## Request Lifecycle
Every request passes through this pipeline in order:
```
logging middleware → auth → rate-limit → validate → handler → serialize → respond
```
- **logging**: structured log entry on request start (`{ method, path, userId, requestId }`)
- **auth**: verifies JWT, attaches `req.user` (from `src/auth/middleware.ts`)
- **rate-limit**: global 200 req/min per IP; authenticated users get 1000 req/min per `userId`
- **validate**: Zod schema check — returns 400 immediately on failure
- **handler**: business logic, calls `src/services/` — never touches DB directly
- **serialize**: strips internal fields, applies field-level permissions
- **respond**: calls `responses.ts` helpers for consistent shape

## Patterns

### Response Shape
All responses use one of two shapes:
```json
{ "data": <T>, "error": null }
{ "data": null, "error": { "code": "NOT_FOUND", "message": "User not found" } }
```
Never return a bare object or array — always wrap in `{ data }`.

### Pagination
Use **cursor-based pagination**, not offset-based:
```json
{ "data": [...], "nextCursor": "abc123", "hasMore": true }
```
- Cursor is an opaque base64-encoded `{ id, createdAt }` value
- Never add `offset`/`page` params — they cause consistency issues under load
- Default page size: 20. Max: 100.

### Validation
Use Zod schemas from `validators/` for all incoming data:
```ts
const schema = z.object({ userId: z.string().uuid(), limit: z.coerce.number().max(100) })
const parsed = schema.safeParse(req.query)
if (!parsed.success) return res.status(400).json({ data: null, error: parsed.error })
```

## Conventions
- Route files export a router: `export const userRouter = Router()`
- Group routes by resource: `/api/users`, `/api/posts`, `/api/orders`
- HTTP status codes: 200 (read), 201 (create), 204 (delete), 400 (bad input), 401 (unauth), 403 (forbidden), 404 (not found), 500 (server error)
- Handler functions: always `async (req: AuthedRequest, res: Response) => { ... }`

## Error Handling
- Validation errors → 400 with Zod error details (field-level messages)
- Auth errors → 401 (missing/expired token) or 403 (insufficient role)
- Not found → 404 with `{ code: 'NOT_FOUND', message: '[Resource] not found' }`
- All others → 500 with generic message; full error logged server-side with `requestId` for tracing

## Transaction Rules
- **All mutations must use `prisma.$transaction()`** — never issue multiple writes outside a transaction
- Never mix read-after-write without a transaction (reads after a write must be inside the same `$transaction()` call to avoid stale reads)
- Transactions that fail mid-way must not leave partial state — verify rollback behavior in tests

## Gotchas
- **N+1 queries in `handlers/users.ts`**: always use `prisma.user.findMany({ include: { posts: true } })` — never fetch posts in a loop
- **Response size limit**: 1MB max — use streaming (`res.write()`) for large datasets like exports
- **CORS**: only allow origins listed in the `ALLOWED_ORIGINS` environment variable — do not use `origin: '*'` in production
- **Request IDs**: `req.id` is set by the logging middleware — always include it in error logs for traceability
