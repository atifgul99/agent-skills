---
name: claude
description: >
  Use when Codex needs a second opinion, independent code review, adversarial
  plan challenge, deep multi-file context analysis, or wants to delegate
  planning/research/editing to Anthropic Claude Code CLI.
  Triggers on: "claude review", "second opinion", "ask claude", "verify with claude",
  "get claude to", "adversarial review from claude", "claude rescue", "use claude's
  1M context", or any request to cross-check an implementation, architecture decision,
  or plan with Claude.
---

# Claude — Second Opinion & Deep-Context Review Agent

Integrates Anthropic Claude Code CLI into your Codex workflow for independent
verification, adversarial review, large-context analysis, and background task
delegation. This is the mirror of Claude's `codex` skill — symmetrical peer review.

---

## When to Use This Skill

| Trigger | Mode |
|---|---|
| Independent review of uncommitted changes | `claude -p` with diff + acceptance criteria |
| Challenge a plan / design decision | adversarial review (`claude -p --effort high`) |
| Architecture / multi-file analysis (huge context) | `claude -p --model opus` (1M ctx) |
| Plan a non-trivial change before editing | `claude -p --permission-mode plan` |
| Delegate broad codebase exploration | `claude -p --agent Explore` |
| Delegate a write/edit task | `claude -p --permission-mode acceptEdits` |
| Continue a previous Claude session | `claude -p --continue` or `--resume <id>` |
| Quick fact-check or lookup | `claude -p --model haiku` |

Use Claude when independence matters: approval gates, code review, architecture
choices, security-sensitive changes, migration plans, destructive operations, or
any situation where Codex may be too close to its own plan. Claude's two distinct
advantages over Codex: (1) **1M-token context on Opus 4.7** for whole-repo /
many-file analysis without chunking, (2) **specialised subagents** (Explore, Plan,
general-purpose, code-reviewer, feature-dev) you can target directly.

---

## Prerequisites Check

Before invoking Claude, verify it is ready:

```bash
claude --version   # should print 2.1.x or later (Claude Code)
```

If missing: install per Anthropic docs (`https://docs.anthropic.com/claude/docs/claude-code`)
then `claude auth login`.
Run Claude from the repository root unless the prompt explicitly names a different
working directory. Claude auto-discovers `CLAUDE.md` and `AGENTS.md` from cwd —
do not hide the repo behind pasted snippets.

---

## Model Routing

Always specify `--model` and `--effort` explicitly — never rely on the user's
`~/.claude/settings.json` default, which can change at any time. Pick based on
task complexity:

| Model alias | Full ID | Effort levels | Use for |
|---|---|---|---|
| `opus` | `claude-opus-4-7` | low / medium / high / xhigh / max | **1M-token context.** Hard problems, whole-codebase analysis, novel architecture, security review, adversarial plan critique. |
| `sonnet` | `claude-sonnet-4-6` | low / medium / high / xhigh / max | Standard workhorse. Most reviews, verification, everyday analysis. |
| `haiku` | `claude-haiku-4-5-20251001` | low / medium / high | Fast and cheap. Quick lookups, routine tasks, trivial fact-checks. |

**Decision rules:**
- Default to `sonnet + medium` for most tasks — good balance of quality and speed.
- Escalate to `opus + high` for architecture decisions, security review, multi-file
  deep analysis, anything that needs the 1M context window.
- Use `opus + xhigh` (or `max`) only when maximum reasoning depth is genuinely needed.
- Drop to `haiku + low` for quick lookups and cheap/fast passes.
- Always pair `--print` (`-p`) with `--output-format text` (default) or `json` for
  structured parsing. Never invoke interactive mode from Codex.
- Add `--max-budget-usd <N>` on any `opus + xhigh` or `max` call to prevent runaway
  cost on a stuck reasoning loop. A reasonable default cap is `--max-budget-usd 2`.

---

## Search-First Checklist

Always run these before sending a query to Claude — paste findings as "Repository
evidence":

- [ ] `rg <token>` — find existing patterns in the repo
- [ ] Skim `AGENTS.md` / `CLAUDE.md` (root and package-level) for project norms
- [ ] `git log -p -- <file>` — check if history reveals prior decisions
- [ ] `git status --short` and the relevant `git diff -- <paths>` — define the
      exact review surface
- [ ] Test/lint/typecheck output if already run — include failures and skipped
      checks explicitly
- [ ] Note relevant file paths and line numbers

Do not ask Claude to review vague prose when the repository is available. Give it
paths, diff scope, commands run, acceptance criteria, and the decision you need.
Because Claude auto-loads `CLAUDE.md` and `AGENTS.md` from cwd, you do not need to
paste them — just reference them by path.

---

## Command Patterns

### Standard Research / Second Opinion

```bash
claude -p \
  --model sonnet \
  --effort medium \
  --permission-mode plan \
  --output-format text \
  "Context: [project / tech stack]. See ./CLAUDE.md and ./AGENTS.md.
   Task: [question].
   Return: disposition, citations (file:line), findings/blockers,
   missing verification, risks, next steps, and open questions." 2>/dev/null
```

`--permission-mode plan` keeps the session read-only — Claude can read files and
run analysis but cannot edit, write, or run shell mutations.

### Adversarial Review (challenges design decisions)

```bash
claude -p \
  --model opus \
  --effort high \
  --permission-mode plan \
  --max-budget-usd 2 \
  "Context: [project]. Act as adversarial reviewer. Challenge the design of: [plan/code].
   Focus on: hidden assumptions, failure modes, better alternatives, rollback safety,
   missing tests, regression risk. Do NOT just agree. Find what could go wrong.
   Use the 1M context window — read ALL files referenced in the diff plus their
   transitive call sites before deciding." 2>/dev/null
```

### Approval / Sign-off Gate

Use this when Codex wants Claude to approve a plan, diff, or release decision.
Claude must be allowed to block.

```bash
claude -p \
  --model opus \
  --effort high \
  --permission-mode plan \
  --max-budget-usd 3 \
  "Context: [project]. Read ./CLAUDE.md and ./AGENTS.md before deciding.
   Review surface: [paths / diff / branch].
   Acceptance criteria: [criteria].
   Commands already run: [commands and results].
   Decision needed: approve, approve-with-nits, block, or needs-more-evidence.
   Be brutal and evidence-first. Findings must cite file:line or exact missing evidence.
   Do not approve if tests are missing, the diff is too broad, behavior is ambiguous,
   or the implementation relies on unverified assumptions." 2>/dev/null
```

### Deep Multi-File Analysis (use Claude's 1M context advantage)

Claude's signature differentiator over Codex is the 1M-token context window on
`opus`. Use it when the question genuinely spans many files and you do not want
to summarise/chunk:

```bash
claude -p \
  --model opus \
  --effort xhigh \
  --permission-mode plan \
  --max-budget-usd 4 \
  "Context: [project / tech stack]. See ./CLAUDE.md.
   Question: [architecture / cross-cutting question].
   Read every file under [path or list] and trace [behaviour].
   Return: disposition, decisive recommendation, evidence citations,
   findings/blockers, missing verification, risks, next steps, and open questions." 2>/dev/null
```

### Plan-Before-Edit (use Claude's plan mode)

When you want Claude to plan a non-trivial change without touching the repo:

```bash
claude -p \
  --model sonnet \
  --effort high \
  --permission-mode plan \
  "Plan the change: [goal]. Constraints: [constraints].
   Return: step-by-step plan, files to create/modify, risks, rollback plan,
   test additions, and explicit acceptance criteria." 2>/dev/null
```

### Delegate Broad Codebase Exploration (Explore subagent)

Claude has a fast read-only `Explore` subagent that is purpose-built for
"where is X defined / which files reference Y / what's the shape of feature Z":

```bash
claude -p \
  --model sonnet \
  --effort medium \
  --agent Explore \
  --permission-mode plan \
  "Find: [what you're looking for]. Search breadth: medium.
   Return: file paths, line numbers, and a 1-sentence note per hit." 2>/dev/null
```

Other useful agents: `Plan` (implementation strategy), `general-purpose`
(multi-step research), `feature-dev:code-reviewer`, `feature-dev:code-explorer`.

### Write / Edit Task (acceptEdits permission)

```bash
claude -p \
  --model sonnet \
  --effort medium \
  --permission-mode acceptEdits \
  "Context: [project]. Task: [specific edit]. Constraints: [constraints].
   Only edit files under [path]. Do not run shell commands beyond build/test." 2>/dev/null
```

**Confirm with user before running write tasks.** `acceptEdits` lets Claude
write files without prompting; pair with a tight `--add-dir` scope and explicit
file-path constraints in the prompt.

### Fast / Budget Lookup

```bash
claude -p \
  --model haiku \
  --effort low \
  --permission-mode plan \
  "[Your quick question]" 2>/dev/null
```

### Structured JSON Output (for parsing in scripts)

```bash
claude -p \
  --model sonnet \
  --effort medium \
  --permission-mode plan \
  --output-format json \
  --json-schema '{"type":"object","properties":{"disposition":{"type":"string","enum":["approve","approve-with-nits","block","needs-more-evidence"]},"findings":{"type":"array","items":{"type":"string"}},"citations":{"type":"array","items":{"type":"string"}}},"required":["disposition","findings","citations"]}' \
  "[Your structured review prompt]" 2>/dev/null
```

### Resume Previous Session

```bash
claude -p --continue "Follow-up prompt here" 2>/dev/null
# or by explicit session id:
claude -p --resume <session-id> "Follow-up prompt here" 2>/dev/null
```

Never add `--model` or `--effort` flags to resume — the session inherits them
from the original run.

---

## Context Sharing Template

Always give Claude project context so it doesn't work blind:

```
Context: This is the [Project Name] repo — [1-sentence description] using [tech stack].

Key docs (auto-loaded from cwd): ./CLAUDE.md, ./AGENTS.md
[List other CLAUDE.md / AGENTS.md locations if relevant, e.g. ./lib/CLAUDE.md]

Repository evidence:
- [file:line — what you found with rg/git log]
- [file:line — relevant pattern]

Review surface:
- Changed files: [paths]
- Diff base: [HEAD / main / commit]
- Commands run: [typecheck/lint/test/build and outcome]
- Known constraints: [sandbox, network, DB, product/compliance/design rules]

Task: [your specific question or review request]

Return:
1. Disposition: approve / approve-with-nits / block / needs-more-evidence
2. Supporting citations (file:line)
3. Findings and blockers ordered by severity
4. Missing verification or tests
5. Recommended next steps or fixes
6. Open questions / uncertainties
```

---

## Structured Output Discipline

Always ask Claude to return these sections:

1. **Disposition** — `approve`, `approve-with-nits`, `block`, or `needs-more-evidence`
2. **Citations** — `file:line` references, not pasted code blocks
3. **Findings / blockers** — what is wrong, what is missing, what is likely to break
4. **Missing verification** — tests, checks, runtime validation, docs, migrations,
   or rollback evidence still needed
5. **Risks / edge cases** — what could go wrong if the issue ships as-is
6. **Next steps** — concrete recommended actions
7. **Open questions** — what Claude is uncertain about

Summaries + references are preferable to large pasted snippets.
Never include secrets, API keys, or env values in prompts.
Tell Claude to say "needs-more-evidence" when it cannot verify the claim from
the provided repository state.

---

## Critical Evaluation of Claude's Output

Treat Claude as a **hard-nosed peer reviewer, not an authority**. It can be wrong
and it should be challenged when the evidence does not hold.

- Trust your own knowledge when confident. Push back if Claude contradicts
  something you know.
- Verify disagreements with web search or docs before accepting Claude's claims.
- Remember Claude has a training cutoff (Jan 2026 for Opus 4.7). It may not know
  about very recent API changes or library versions — confirm against current docs.
- Evaluate suggestions critically for model names, recent library versions,
  evolving best practices, missing tests, regression risk, and unsafe assumptions.
- Claude tends to be more verbose and more cautious than Codex. Compress its
  output before relaying — keep the disposition, citations, blockers; drop the
  hedging.
- If the work is not ready, say so directly. Do not soften a blocker into a
  suggestion.
- Do not approve, sign off, or endorse a change unless the evidence actually
  supports it.
- Treat `approve-with-nits` as approval only for non-blocking cleanup. If any
  correctness, security, migration, data-loss, product/compliance, or
  user-visible regression risk remains, the disposition is `block` or
  `needs-more-evidence`.
- If Claude says "looks fine" without citations, treat that as a failed review
  and rerun with a narrower prompt or better repository evidence.

**When Claude is wrong:**
1. State the disagreement clearly to the user.
2. Provide evidence (your knowledge, web search, documentation).
3. Optionally resume the session to discuss peer-to-peer:

```bash
claude -p --continue "This is Codex following up. I disagree with [X] because [evidence].
What's your reasoning?" 2>/dev/null
```

---

## Permission Mode Reference

| Mode | Flag | Use when |
|---|---|---|
| Plan / read-only | `--permission-mode plan` | Analysis, review, research — **default for all calls** |
| Auto-approve edits | `--permission-mode acceptEdits` | Refactoring, writing new files — confirm with user first |
| Bypass all checks | `--permission-mode bypassPermissions` | **Never use from Codex without explicit user approval.** Reserved for fully sandboxed environments. |
| Default | `--permission-mode default` | Interactive prompts on each action — not useful from `-p` (will hang) |

When in doubt, use `plan`. It is the strictest read-only mode and prevents Claude
from making any change to the workspace.

---

## Subagent Reference

Claude exposes specialised subagents via `--agent <name>`. From Codex, the most
useful are:

| Agent | Best for |
|---|---|
| `Explore` | Fast read-only code search ("where is X defined, which files reference Y") |
| `Plan` | Implementation plans, architecture trade-offs, critical files identification |
| `general-purpose` | Multi-step research, broad questions, parallelisable lookups |
| `feature-dev:code-reviewer` | Targeted review of recent code changes |
| `feature-dev:code-explorer` | Deep analysis of an existing feature (execution paths, dependencies) |
| `feature-dev:code-architect` | Designing feature architectures with implementation blueprints |

Match the agent to the task — do not default to `general-purpose` when a
narrower agent fits.

---

## Verification Checklist (after receiving Claude's output)

Before accepting Claude's suggestions:

- [ ] Compatible with current library versions (not deprecated patterns)
- [ ] Follows this project's directory structure and conventions
- [ ] Matches auth / database / deployment patterns already in use
- [ ] Aligns with project-specific constraints from `CLAUDE.md` / `AGENTS.md`
- [ ] Considers performance and security implications
- [ ] Has a clear disposition, with citations for every blocking claim
- [ ] Names missing tests or explicitly states why existing verification is enough
- [ ] Does not ask Codex to run destructive or write-capable commands without
      user approval

---

## Error Handling

- If `claude --version` fails → install per Anthropic docs and run `claude auth login`
- If `claude -p` exits non-zero → report the error, do NOT retry silently; ask
  user for direction
- If output contains partial results or warnings → summarize and ask how to proceed
- If a call appears to hang → confirm `--print` (`-p`) is set and the permission
  mode is not `default` (which prompts interactively and will block on a pipe)
- Claude responses typically take 30s–3 min for complex tasks on Opus + high+;
  start queries early and continue local work while waiting
- If `--max-budget-usd` aborts the call, retry with a tighter prompt or smaller
  scope before raising the cap

---

## Performance Notes

- **Thinking tokens suppressed by default** (`2>/dev/null`) — keeps Codex's
  context window clean
- Show stderr only if user explicitly asks to see Claude's reasoning process
- For long-running tasks, start Claude early and parallelise local analysis
- Opus 4.7 with the 1M context window is the slowest and most expensive option —
  reserve it for tasks that actually need either property
- `--exclude-dynamic-system-prompt-sections` improves prompt-cache reuse across
  repeated calls in the same repo — worth adding when batching multiple reviews

---

## After Every Claude Run

1. Summarize the key findings to the user
2. Flag any disagreements or concerns
3. State the disposition exactly: approve, approve-with-nits, block, or
   needs-more-evidence
4. If blocked, list the minimum changes or evidence needed to unblock
5. Remind user they can resume: "You can continue this Claude session anytime —
   just ask me to resume it"
6. Confirm whether to apply, investigate further, or discard the findings

---

## Symmetry Note

This skill is the mirror of the `codex` skill that Claude uses to call Codex.
The two are designed to interoperate — when Codex and Claude review each other's
work, both follow the same disposition vocabulary (`approve`,
`approve-with-nits`, `block`, `needs-more-evidence`) and the same structured
output sections. That symmetry is the point: each model gets to act as a
hard-nosed peer reviewer of the other, with neither acting as the final
authority on its own work.
