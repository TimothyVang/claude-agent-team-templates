# Changelog

All notable changes to this project will be documented in this file.

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
