---
name: codex
description: >
  Claude Code-only skill. Use when Claude needs a second opinion, independent
  code review, adversarial plan challenge, or wants to delegate analysis/editing
  to OpenAI Codex CLI.
  Triggers on: "codex review", "second opinion", "ask codex", "verify with codex",
  "get codex to", "adversarial review", "codex rescue", or any request to cross-check
  an implementation, architecture decision, or plan with Codex.
---

# Codex — Second Opinion & Code Review Agent

Integrates OpenAI Codex CLI into your Claude Code workflow for independent verification,
adversarial review, and background task delegation.

**Discovery scope:** This skill is for Claude Code only. Symlink it into
`~/.claude/skills/codex`. Do not symlink it into `~/.codex/skills`; Codex does
not need a skill that teaches Claude how to call Codex.

---

## When to Use This Skill

| Trigger                                | Mode                                          |
| -------------------------------------- | --------------------------------------------- |
| Signoff / review of a commit           | `codex review --commit <sha>` ← **preferred** |
| Signoff / review of a branch vs main   | `codex review --base main`                    |
| Pure plan review (no code written yet) | `codex exec` with structured prompt           |
| Challenge a plan / design decision     | adversarial review (`codex exec`)             |
| Verify an architecture approach        | research query (`codex exec`)                 |
| Delegate a write/edit task             | `codex exec` with workspace-write sandbox     |
| Continue a previous Codex session      | `codex exec resume --last`                    |
| Quick fact-check or lookup             | `codex exec` with `gpt-5.4-mini`              |

**The golden rule: commit the work first, then use `codex review --commit <sha>`.
Committing first gives Codex a fixed, bounded surface — it sees exactly the same diff on
every run, can be re-reviewed after fixes, and captures no unrelated in-progress noise.
Use `--base main` for a full branch review. Never use `codex review --uncommitted`
(unbounded surface, slow, picks up unrelated in-progress changes).**

Use Codex when independence matters: approval gates, code review, architecture choices,
security-sensitive changes, migration plans, destructive operations, or any situation where
Claude may be too close to its own plan.

---

## Prerequisites Check

Before invoking Codex, verify it is ready:

```bash
codex --version   # should print codex-cli 0.132.0 or later
```

If missing: `npm install -g @openai/codex` then `codex login`.
Run Codex from the repository root unless the prompt explicitly names a different working
directory. Codex's strongest advantage is direct workspace inspection; do not hide the repo
behind pasted snippets.

---

## Model Routing

`codex review` does **not** accept `-m` — model selection uses `-c model="..."`.
`codex exec` accepts both `-m` and `-c`.

| Model                 | Via `codex exec`?             | Reasoning levels            | Use for                                                                                 |
| --------------------- | ----------------------------- | --------------------------- | --------------------------------------------------------------------------------------- |
| `gpt-5.4`             | Yes                           | low / medium / high / xhigh | Standard workhorse. All reviews, verification, analysis — including deep/security work. |
| `gpt-5.4-mini`        | Yes                           | low / medium / high / xhigh | Fast and cheap. Quick lookups, routine tasks, trivial fact-checks.                      |
| `gpt-5.3-codex`       | Yes                           | low / medium / high / xhigh | Legacy. Avoid for new tasks — OpenAI nudges toward gpt-5.4.                             |
| `gpt-5.2`             | Yes                           | low / medium / high / xhigh | Old. Avoid.                                                                             |
| `gpt-5.3-codex-spark` | **No** — interactive TUI only | —                           | **Cannot be used in `codex exec`.** Will fail silently. Use `gpt-5.4-mini` instead.     |

**Decision rules:**

- Default to `gpt-5.4 + medium` for most tasks — good balance of quality and speed
- Escalate to `gpt-5.4 + high` for architecture decisions, security review, multi-file deep analysis
- Drop to `gpt-5.4-mini + low` for quick lookups and cheap/fast passes
- For `codex review`: override model with `-c model="gpt-5.4"`, reasoning with `-c model_reasoning_effort="high"`

---

## Command Patterns

### Code Review — native subcommand (preferred for all reviews)

```bash
# Review a commit (preferred)
codex review --commit <sha> 2>/dev/null

# Review branch vs base
codex review --base main 2>/dev/null

# With custom focus instructions
codex review --commit <sha> "Focus on auth logic and error handling" 2>/dev/null

# With model override
codex review --commit <sha> -c model="gpt-5.4" -c model_reasoning_effort="high" 2>/dev/null
```

The `codex review` subcommand is read-only and inspects the repo directly — no pasting
needed. Expected output shape:

- **disposition**: `approve`, `approve-with-nits`, `block`, or `needs-more-evidence`
- **findings**: ordered by severity, with concrete file:line citations
- **missing verification**: tests, commands, or evidence still needed
- **risks / edge cases**: what could still go wrong
- **next steps**: smallest useful follow-up actions

**Cost control:** `codex review` is unbounded. On macOS, `timeout` is not available by
default — install via `brew install coreutils` to get `gtimeout`, then:

```bash
gtimeout 10m codex review --commit <sha> -c model="gpt-5.4" 2>/dev/null
```

On Linux, plain `timeout` works:

```bash
timeout 10m codex review --commit <sha> -c model="gpt-5.4" 2>/dev/null
```

Use this exact shape when you need structured output from a commit review:

```bash
codex review --commit <sha> \
  "Return:
   1. Disposition
   2. Findings ordered by severity
   3. Missing verification
   4. Risks / edge cases
   5. Next steps
   Findings must cite file:line or exact missing evidence.
   Do not approve if tests are missing, the diff is too broad, behavior is ambiguous,
   or the implementation relies on unverified assumptions." 2>/dev/null
```

### `-c` config overrides

`-c` overrides any Codex config key for that invocation. The value is parsed as TOML.

```bash
codex review --commit <sha> -c model="gpt-5.4"
codex review --commit <sha> -c model_reasoning_effort="high"
codex review --commit <sha> -c features.hooks=false
codex review --commit <sha> -c 'shell_environment_policy.inherit="all"'
codex review --commit <sha> -c 'sandbox_permissions=["disk-full-read-access"]'
```

### Standard Research / Second Opinion (`codex exec`)

For `codex exec`, run the search-first checklist below before writing the prompt.

```bash
codex exec \
  -m gpt-5.4 \
  -c model_reasoning_effort="medium" \
  --sandbox read-only \
  --full-auto \
  --skip-git-repo-check \
  "Context: [project / tech stack]. @/CLAUDE.md. Task: [question].
   Return: disposition, citations, findings/blockers, missing verification,
   risks, next steps, and open questions." 2>/dev/null
```

### Adversarial Review (challenges design decisions)

```bash
codex exec \
  -m gpt-5.4 \
  -c model_reasoning_effort="high" \
  --sandbox read-only \
  --full-auto \
  --skip-git-repo-check \
  "Context: [project]. Act as adversarial reviewer. Challenge the design of: [plan/code].
   Focus on: hidden assumptions, failure modes, better alternatives, rollback safety.
   Do NOT just agree. Find what could go wrong." 2>/dev/null
```

### Approval / Sign-off Gate

**Code exists → commit it, then review the commit:**

```bash
codex review --commit <sha> "Focus on [specific concerns]. Flag any bugs, type errors, security issues, or missing edge cases." 2>/dev/null
```

**Pure plan sign-off (no code yet) → use `codex exec`:**

```bash
codex exec \
  -m gpt-5.4 \
  -c model_reasoning_effort="high" \
  --sandbox read-only \
  --full-auto \
  --skip-git-repo-check \
  "Context: [project]. @/CLAUDE.md @/AGENTS.md.
   Review surface: [paths / diff / branch].
   Acceptance criteria: [criteria].
   Commands already run: [commands and results].
   Decision needed: approve, approve-with-nits, block, or needs-more-evidence.
   Be brutal and evidence-first. Findings must cite file:line or exact missing evidence.
   Do not approve if tests are missing, the diff is too broad, behavior is ambiguous,
   or the implementation relies on unverified assumptions." 2>/dev/null
```

### Write / Edit Task (workspace-write sandbox)

**Confirm with user before running.**

```bash
codex exec \
  -m gpt-5.4 \
  -c model_reasoning_effort="medium" \
  --sandbox workspace-write \
  --full-auto \
  --skip-git-repo-check \
  "Context: [project]. Task: [specific edit]. Constraints: [constraints]." 2>/dev/null
```

### Fast / Budget Lookup

```bash
codex exec \
  -m gpt-5.4-mini \
  -c model_reasoning_effort="low" \
  --sandbox read-only \
  --full-auto \
  --skip-git-repo-check \
  "[Your quick question]" 2>/dev/null
```

### Deep Architecture Analysis (max depth)

```bash
codex exec \
  -m gpt-5.4 \
  -c model_reasoning_effort="xhigh" \
  --sandbox read-only \
  --full-auto \
  --skip-git-repo-check \
  "Context: [project / tech stack]. @/CLAUDE.md.
   Question: [architecture question].
   Return: disposition, decisive recommendation, evidence citations,
   findings/blockers, missing verification, risks, next steps, and open questions." 2>/dev/null
```

### Resume Previous Session

```bash
echo "Follow-up prompt here" | codex exec --skip-git-repo-check resume --last 2>/dev/null
```

Never add `-m` or `-c` flags to resume — the session inherits them from the original run.

---

## Search-First Checklist (for `codex exec` only)

`codex review --commit` reads the repo directly — skip this checklist for review calls.
For `codex exec`, complete these before writing the prompt and paste findings as context:

- [ ] `rg <token>` — find existing patterns in the repo
- [ ] Skim `CLAUDE.md` / `AGENTS.md` (root and package-level) for project norms
- [ ] `git log -p -- <file>` — check if history reveals prior decisions
- [ ] Test/lint/typecheck output if already run — include failures and skipped checks explicitly
- [ ] Note relevant file paths and line numbers

Do not ask Codex to review vague prose when the repository is available. Give it paths,
diff scope, commands run, acceptance criteria, and the decision you need.

---

## Context Sharing Template (for `codex exec`)

```
Context: This is the [Project Name] repo — [1-sentence description] using [tech stack].

Key docs: @/CLAUDE.md (root), @/AGENTS.md (orchestration model).
[List other CLAUDE.md locations if relevant, e.g. @/lib/CLAUDE.md]

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

## Critical Evaluation of Codex Output

Treat Codex as a **hard-nosed peer reviewer, not an authority**. It can be wrong.

- Trust your own knowledge when confident. Push back if Codex contradicts something you know.
- Verify disagreements with WebSearch or docs before accepting Codex's claims.
- Remember Codex has a training cutoff. It may not know about recent API changes or library versions.
- If the work is not ready, say so directly. Do not soften a blocker into a suggestion.
- Do not approve, sign off, or endorse a change unless the evidence actually supports it.
- Treat `approve-with-nits` as approval only for non-blocking cleanup. If any correctness,
  security, migration, data-loss, product/compliance, or user-visible regression risk remains,
  the disposition is `block` or `needs-more-evidence`.
- If Codex says "looks fine" without citations, treat that as a failed review and rerun with
  a narrower prompt or better repository evidence.

**Common false positive: Codex confuses similar field names.** Verify any finding that
references a specific file/line by reading the actual code before accepting it as a blocker.

**When Codex is wrong:**

1. State the disagreement and your evidence to the user
2. Optionally resume the session peer-to-peer:

```bash
echo "This is Claude following up. I disagree with [X] because [evidence].
What's your reasoning?" | codex exec --skip-git-repo-check resume --last 2>/dev/null
```

---

## Sandbox Mode Reference

| Mode                       | Flag                           | Use when                                                        |
| -------------------------- | ------------------------------ | --------------------------------------------------------------- |
| Read-only review           | `--sandbox read-only`          | Analysis, review, research — **default for all exec calls**     |
| Apply local edits          | `--sandbox workspace-write`    | Refactoring, writing new files — confirm with user first        |
| Full network/system access | `--sandbox danger-full-access` | Only if task explicitly needs it — **always confirm with user** |

---

## After Every Codex Run

1. State the disposition exactly: `approve`, `approve-with-nits`, `block`, or `needs-more-evidence`
2. Summarize findings to the user — flag any you disagree with and explain why
3. If blocked: list the minimum changes or evidence needed to unblock
4. Verify each cited file:line actually contains the issue Codex describes before acting on it
5. Confirm whether to apply fixes, investigate further, or discard the findings
6. If the run was `codex exec`: remind user they can resume — "You can continue this Codex session anytime — just ask me to resume it"

---

## Error Handling

- If `codex --version` fails → install: `npm install -g @openai/codex`
- If `codex exec` exits non-zero → report the error, do NOT retry silently; ask user for direction
- If output contains partial results or warnings → summarize and ask how to proceed
- Expected timing: `codex review --commit` typically 1–3 min; `codex exec` 30s–5 min for complex tasks

---

## Performance Notes

- **Thinking tokens suppressed by default** (`2>/dev/null`) — keeps Claude's context window clean
- Show stderr only if user explicitly asks to see Codex's reasoning process
- For long-running tasks, start Codex early and continue local work while waiting

---

## Optional: Automatic Plan Review Hook

If you want Codex to automatically review every plan Claude creates before you approve it,
install the `cathrynlavery/codex-skill` hook separately:

```bash
claude plugin add cathrynlavery/codex-skill
```

Or for the full official OpenAI plugin with `/codex:review`, `/codex:adversarial-review`,
and `/codex:rescue` slash commands:

```bash
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
```
