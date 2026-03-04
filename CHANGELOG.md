# Changelog

All notable changes to this project will be documented in this file.

## [3.2] - 2026-03-04

### Added
- `scripts/lib/json-helpers.sh` — shared `escape_json_string()` and `build_json_array()` functions (DRY JSON construction)
- `scripts/security-file-check.sh` — PreToolUse hook blocking path traversal and sensitive file access (Read/Edit/Write)
- `reference/debugging.md` — guide for reading logs, diagnosing stuck teams, checking circuit breaker state
- "When NOT to use agent teams" section in main template Decision Framework
- Worked examples for Templates F (incident-response), G (migration), H (documentation)
- File ownership notes for Templates B (bug-hunt), C (code-review), D (research)
- `quick-start-generator.md` added to README template index

### Fixed
- **CRITICAL**: JSON injection in `observability-hook.sh` — unescaped strings in JSON log entries (now uses json-helpers.sh)
- **CRITICAL**: JSON injection in `precompact-save-state.sh` — unescaped filenames and notes in JSON snapshot
- **CRITICAL**: `eval "$VERIFY_CMD"` in `error-recovery-hook.sh` replaced with `bash -c` to prevent command injection
- **HIGH**: `circuit-breaker.sh` rewritten from fragile JSON to flat-file state format (fixes regex parsing, sed escaping, and unvalidated arithmetic)
- **HIGH**: Stash race condition in `error-recovery-hook.sh` — switched to named-stash lookup
- **HIGH**: `cd` failure silently swallowed in `verify-task.sh` — wrapped in subshells
- **HIGH**: `/dev/stdin` hash in `check-remaining-work.sh` fails on Windows — switched to pipe
- **MEDIUM**: `date +%s%3N` fallback in `observability-hook.sh` not validated for literal expansion
- **MEDIUM**: `find` in `check-remaining-work.sh` missing exclusions for node_modules, .git, dist, build
- **MEDIUM**: Unquoted variable in `session-start-setup.sh` `command -v`
- **MEDIUM**: Race condition in `evaluate-run.sh` — log file now snapshotted before parsing
- **MEDIUM**: `precompact-save-state.sh` schema: `modified_files` and `recent_commits` now proper JSON arrays

### Changed
- `circuit-breaker.sh` state file format: JSON → flat-file key=value (`.claude/circuit-breaker-state.txt`)
- Multiple scripts now source `scripts/lib/json-helpers.sh` for safe JSON construction
- `security-guardrails.md` Section 3 links to `security-file-check.sh` implementation
- `error-recovery.md` Goal Drift section references `check-remaining-work.sh`
- `settings-template.json` includes `security-file-check.sh` PreToolUse hook for Read/Edit/Write
- `token-optimization.md` Context Priority Hierarchy uses P1-P5 severity labels

## [3.1] - 2026-03-03

### Fixed
- Created missing `scripts/security-check.sh` — blocks all patterns from security-guardrails.md table (fork bomb, kill/shutdown/reboot, short-form `git push -f`)
- Fixed section numbering in main template (9.5 Security before 9.4 Post-Execution)
- Aligned recovery tier numbering across all 3 documents to consistent 5-tier system
- Added `set -euo pipefail` to `precompact-save-state.sh`
- Fixed `sed -i` portability in `circuit-breaker.sh` for macOS/BSD
- Added safety checks to `error-recovery-hook.sh` git operations
- Fixed final exit code in `error-recovery-hook.sh` (was 2, should be 1 for hard block)
- Fixed `evaluate-run.sh` task completion formula (was counting tool failures as task failures)
- Fixed path inconsistency in `security-guardrails.md`
- Fixed bug-hunt.md worked example presupposing the winning hypothesis

### Added
- `README.md` — proper repo README with quickstart, directory tree, template index
- `.gitignore` — prevents runtime state from being committed
- `LICENSE` — MIT license for community adoption
- `CHANGELOG.md` — this file
- All 4 missing scripts listed in main template Section 5.4
- Template I (Plan-First) added to quick-start-generator.md
- v3 additions (hooks, checklists, templates F-I) added to setup/post-run checklists

### Changed
- `stop-verification-hook.sh` documented as reference/documentation script in main template

## [3.0] - 2026-03

### Added
- 7 new files: precompact-save-state.sh, stop-verification-hook.sh, evaluate-run.sh, circuit-breaker.sh, failure-modes-checklist.md, security-guardrails.md, plan-first.md
- Windows compatibility (TMPDIR pattern, no md5sum/bc/$EPOCHREALTIME)
- Worktree isolation documentation
- Worked examples added to templates A-E
- 7 of 14 hook events covered

### Changed
- All scripts use cross-platform temp directory pattern
- Hub-and-spoke architecture (main doc + reference/ deep-dives)

## [2.0] - 2026-02

### Added
- Prompt templates A-E (feature-dev, bug-hunt, code-review, research, refactor)
- Hook scripts (verify-task, check-remaining-work, session-start-setup, error-recovery, observability)
- Checklists (setup, runtime, post-run, error-recovery-reference)
- Reference documents (error-recovery, token-optimization, delegate-mode, role-prompt-patterns)
- Settings template with hook configurations
- Example CLAUDE.md files

## [1.0] - 2026-01

### Added
- Initial template with core sections (decision framework, blueprint pattern, team architecture)
- Basic team coordination patterns
- Anti-patterns list
