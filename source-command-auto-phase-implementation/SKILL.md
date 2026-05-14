---
name: "source-command-auto-phase-implementation"
description: "Autonomously execute pre-planned phases end-to-end using GSD subagents until context runs out."
---

# source-command-auto-phase-implementation

Use this skill when the user asks to run the migrated source command `auto-phase-implementation`.

## Command Template

The milestone roadmap and phase breakdown already exist in `.planning/`. Read the roadmap and phase files to identify the next incomplete phase(s), then execute them. Continue advancing through phases until context runs out. Do not ask the user anything. Make all decisions autonomously.

## Phase Execution Lifecycle

For each phase, follow this sequence using GSD subagents:

1. **Research** — Use `gsd-phase-researcher` to investigate the phase requirements, codebase context, and implementation approach. When the phase involves platform APIs or external services, research current documentation online.
2. **Plan** — Use `gsd-planner` to create an executable plan with task breakdown and dependencies. Append an audit task at the end of the plan: "Deep audit all changes for this phase — check for gaps, bugs, missing items, misalignment with project rules, and verify against current online documentation for any external APIs or services used. Fix all issues found, then re-audit once to confirm."
3. **Validate Plan** — Use `gsd-plan-checker` to verify the plan (including the audit task) achieves the phase goal before execution.
4. **Execute** — Use `gsd-executor` to implement the plan with atomic commits and checkpoint protocols.
5. **Verify** — Use `gsd-verifier` to confirm the phase goal is achieved through goal-backward analysis.
6. **Test Coverage** — Use `gsd-nyquist-auditor` to validate test coverage for phase requirements.
7. **Integration Check** — Use `gsd-integration-checker` to verify cross-phase integration and E2E flows.
## Rules

- Read `.planning/` to determine which phases exist, their status, and their dependencies.
- Parallelize entire phases when they have no dependencies on each other — run independent phases concurrently.
- Parallelize subagent calls within a phase where there are no dependencies between them.
- If a step fails, fix the issue and retry that step — do not skip it.
- Advance to the next phase only after all 7 steps pass.
