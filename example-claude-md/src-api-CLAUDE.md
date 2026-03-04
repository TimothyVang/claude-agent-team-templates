# API Module Context

> This CLAUDE.md is scoped to the `src/api/` directory.
> Only teammates working on API routes need this context.

## Module Purpose
Defines REST API endpoints, request validation, and response formatting.

## Key Files
- `routes.ts` - Route definitions and middleware chain
- `handlers/` - Request handlers organized by resource
- `validators/` - Zod schemas for request validation
- `responses.ts` - Standard response helpers

## Patterns
- All endpoints follow: `auth middleware -> validate -> handler -> response`
- Response shape: `{ data: T, error: null }` or `{ data: null, error: { code, message } }`
- Use Zod schemas in `validators/` for all request body/query validation
- Handler functions are always `async (req, res) => { ... }`

## Conventions
- Route files export a router: `export const userRouter = Router()`
- Group routes by resource: `/api/users`, `/api/posts`, etc.
- Use HTTP status codes correctly (201 for creation, 204 for deletion)

## Error Handling
- Validation errors return 400 with Zod error details
- Auth errors return 401/403
- Not found returns 404
- All others return 500 with generic message (log details server-side)
