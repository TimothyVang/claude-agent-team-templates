# Template H: Documentation Generation

> Copy the prompt below, fill in the `[BRACKETS]`, and paste into Claude Code.
> Uses a scanner to map the codebase, parallel writers for throughput, and
> a reviewer to ensure accuracy and consistency.

---

## Team Structure

```
Team: documentation
Teammates:
  1. codebase-scanner (Explore agent, haiku model, plan mode)
  2. doc-writer-1     (general-purpose, inherit model, acceptEdits)
  3. doc-writer-2     (general-purpose, inherit model, acceptEdits)
  4. reviewer         (general-purpose, sonnet model, plan mode)
```

## Task Flow

```
Phase 1: SCAN
  codebase-scanner maps all modules and existing docs

Phase 2: PLAN
  Lead assigns documentation areas to writers

Phase 3: WRITE (parallel)
  doc-writer-1 + doc-writer-2 write in parallel
  File ownership by documentation area (not codebase area)

Phase 4: REVIEW
  reviewer checks all docs against code for accuracy
```

---

## Prompt (Copy & Paste)

```
Create an agent team for documentation generation.

The goal is: [DESCRIBE - e.g., "Generate API reference docs for all endpoints",
"Write architecture docs for onboarding new developers",
"Create user guides and code examples for the SDK",
"Document all public modules with JSDoc/docstrings"]

Documentation format: [e.g., Markdown files in docs/**, JSDoc comments, OpenAPI spec]
Target audience: [e.g., new developers, API consumers, end users]

Spawn 4 teammates:

1. "codebase-scanner" - An Explore agent to map the codebase and identify
   documentation gaps. Model: haiku. Permission: plan (read-only).
   Should produce:
   - Map of all modules/packages with brief descriptions
   - List of existing documentation and its coverage
   - Undocumented or under-documented areas
   - Suggested documentation structure and priority order
   Focus areas: [e.g., src/**, lib/**, packages/**]

2. "doc-writer-1" - A general-purpose agent to write documentation.
   Model: inherit. Permission: acceptEdits.
   Documentation area: [AREA 1 - e.g., "API reference docs", "architecture overview",
   "module-level docs for src/core/** and src/services/**"]
   Output to: [e.g., docs/api/**, docs/architecture/**]

3. "doc-writer-2" - A general-purpose agent to write documentation.
   Model: inherit. Permission: acceptEdits.
   Documentation area: [AREA 2 - e.g., "getting started guide", "code examples",
   "module-level docs for src/components/** and src/hooks/**"]
   Output to: [e.g., docs/guides/**, docs/examples/**]

4. "reviewer" - A general-purpose agent to review all generated documentation.
   Model: sonnet. Permission: plan (read-only).
   Should verify:
   - Technical accuracy (do code examples actually work?)
   - Completeness (are all public APIs documented?)
   - Consistency (same terminology, style, formatting throughout)
   - Correctness of cross-references and links
   Reports issues back to the relevant doc-writer for fixes.

File ownership (NO overlaps):
- codebase-scanner: read-only (scans entire codebase)
- doc-writer-1: [DOC OUTPUT PATHS - e.g., docs/api/**, docs/architecture/**]
- doc-writer-2: [DOC OUTPUT PATHS - e.g., docs/guides/**, docs/examples/**]
- reviewer: read-only (reviews all docs and source code)

Phase 1: codebase-scanner maps the codebase and identifies documentation gaps.
Phase 2: I will assign specific documentation tasks to each writer based on scan results.
Phase 3: doc-writer-1 and doc-writer-2 write in parallel with strict file ownership.
Phase 4: reviewer checks all docs against the source code and flags issues.
Writers fix any issues the reviewer finds. Max 2 review rounds.
```

---

## Customization Options

- **Single writer**: Drop doc-writer-2 for smaller projects. One writer can handle everything.
- **More writers**: Add doc-writer-3, doc-writer-4 for large codebases. Split by documentation area, not codebase area, to avoid writers needing to read the same code.
- **API-only**: Drop codebase-scanner if you only need API docs. Have doc-writer-1 generate OpenAPI specs directly from route handlers.
- **Inline docs**: Have writers add JSDoc/docstrings directly in source files instead of separate doc files. Adjust file ownership to source directories.
- **Style guide**: Add a style guide document to the prompt (or reference one) for the reviewer to enforce.
- **Skip review**: Drop the reviewer for quick-and-dirty documentation where accuracy review is not critical.
