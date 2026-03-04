#!/bin/bash
# =============================================================================
# Stop Verification Hook — REFERENCE DOCUMENTATION
# =============================================================================
# This file documents the prompt-based Stop hook pattern.
#
# Unlike other hooks that use type: "command", the Stop hook uses type: "prompt"
# which sends a prompt to the LLM to evaluate whether the agent should stop.
#
# CONFIGURATION (in settings.json or settings-template.json):
#
#   "Stop": [{
#     "hooks": [{
#       "type": "prompt",
#       "prompt": "Review the agent's work. Did they complete ALL acceptance
#                  criteria from their task? Check: tests pass, no TODO/FIXME
#                  left in modified files, code compiles. Reply COMPLETE if
#                  done, or INCOMPLETE with specific unfinished items."
#     }]
#   }]
#
# HOW IT WORKS:
# 1. Agent signals it wants to stop (task done, or no more work)
# 2. The prompt is sent to the LLM for evaluation
# 3. If LLM replies INCOMPLETE, the agent is forced to continue working
# 4. If LLM replies COMPLETE, the agent is allowed to stop
#
# WHY THIS MATTERS:
# Premature task completion is the #1 agent failure mode (arXiv 2503.13657).
# This hook catches agents that think they're done but haven't actually
# finished all acceptance criteria. It's the single highest-impact automation
# pattern from multi-agent research.
#
# CUSTOMIZATION:
# - Adjust the prompt to match your project's definition of "done"
# - Add project-specific checks (e.g., "documentation updated", "changelog entry added")
# - For stricter enforcement, add: "Check git diff for any commented-out code"
#
# COST NOTE:
# Each Stop evaluation costs ~500-1000 tokens. This is negligible compared
# to the cost of an agent completing a task incorrectly (potentially 100K+ tokens
# to redo). Net savings are typically 10-50x the evaluation cost.
# =============================================================================

echo "This is a reference file. The Stop hook uses type: 'prompt' in settings.json."
echo "See the comments above for configuration instructions."
exit 0
