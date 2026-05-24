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

| Trigger | Mode |
|---|---|
| Review uncommitted changes | `codex review --uncommitted` |
| Review branch vs main | `codex review --base main` |
| Challenge a plan / design decision | adversarial review (`codex exec`) |
| Verify an architecture approach | research query (`codex exec`) |
| Delegate a write/edit task | `codex exec` with workspace-write sandbox |
| Continue a previous Codex session | `codex exec resume --last` |
| Quick fact-check or lookup | `codex exec` with `gpt-5.4-mini` |

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

Always specify `-m` and `-c model_reasoning_effort` explicitly — never rely on the user's
`~/.codex/config.toml` default, which can change at any time. Pick based on task complexity:

| Model | Via `codex exec`? | Reasoning levels | Use for |
|---|---|---|---|
| `gpt-5.5` | Yes | low / medium / high / xhigh | Hard problems. Novel architecture, security review, deep multi-file analysis. |
| `gpt-5.4` | Yes | low / medium / high / xhigh | Standard workhorse. Most reviews, verification, everyday analysis. |
| `gpt-5.4-mini` | Yes | low / medium / high / xhigh | Fast and cheap. Quick lookups, routine tasks, trivial fact-checks. |
| `gpt-5.3-codex` | Yes | low / medium / high / xhigh | Legacy. Avoid for new tasks — OpenAI nudges toward gpt-5.4. |
| `gpt-5.2` | Yes | low / medium / high / xhigh | Old. Avoid. |
| `gpt-5.3-codex-spark` | **No** — interactive TUI only | — | **Cannot be used in `codex exec`.** Will fail silently. Use `gpt-5.4-mini` instead. |

**Decision rules:**
- Default to `gpt-5.4 + medium` for most tasks — good balance of quality and speed
- Escalate to `gpt-5.5 + high` for architecture decisions, security review, multi-file deep analysis
- Use `gpt-5.5 + xhigh` only when maximum reasoning depth is genuinely needed
- Drop to `gpt-5.4-mini + low` for quick lookups and cheap/fast passes
- Prefer `codex exec` over `codex review` when you need explicit model routing, structured output, project-specific acceptance criteria, or adversarial plan review.
- Prefer native `codex review` for fast broad scans of uncommitted changes or branch-vs-base diffs where default model routing is acceptable.

---

## Search-First Checklist

Always run these before sending a query to Codex — paste findings as "Repository evidence":

- [ ] `rg <token>` — find existing patterns in the repo
- [ ] Skim `CLAUDE.md` / `AGENTS.md` (root and package-level) for project norms
- [ ] `git log -p -- <file>` — check if history reveals prior decisions
- [ ] `git status --short` and the relevant `git diff -- <paths>` — define the exact review surface
- [ ] Test/lint/typecheck output if already run — include failures and skipped checks explicitly
- [ ] Note relevant file paths and line numbers

Do not ask Codex to review vague prose when the repository is available. Give it paths,
diff scope, commands run, acceptance criteria, and the decision you need.

---

## Command Patterns

### Code Review — native subcommand (preferred for reviews)

```bash
# Review all uncommitted changes
codex review --uncommitted 2>/dev/null

# Review branch vs base
codex review --base main 2>/dev/null

# Review a specific commit
codex review --commit <sha> 2>/dev/null

# With custom focus instructions
codex review --uncommitted "Focus on auth logic and error handling" 2>/dev/null
```

The `codex review` subcommand is read-only and uses the user's configured default model.
No sandbox flags needed — it cannot modify files.

### Standard Research / Second Opinion

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
  -m gpt-5.5 \
  -c model_reasoning_effort="high" \
  --sandbox read-only \
  --full-auto \
  --skip-git-repo-check \
  "Context: [project]. Act as adversarial reviewer. Challenge the design of: [plan/code].
   Focus on: hidden assumptions, failure modes, better alternatives, rollback safety.
   Do NOT just agree. Find what could go wrong." 2>/dev/null
```

### Approval / Sign-off Gate

Use this when Claude wants Codex to approve a plan, diff, or release decision. Codex must be
allowed to block.

```bash
codex exec \
  -m gpt-5.5 \
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

```bash
codex exec \
  -m gpt-5.4 \
  -c model_reasoning_effort="medium" \
  --sandbox workspace-write \
  --full-auto \
  --skip-git-repo-check \
  "Context: [project]. Task: [specific edit]. Constraints: [constraints]." 2>/dev/null
```

**Confirm with user before running write tasks.**

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
  -m gpt-5.5 \
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

## Context Sharing Template

Always give Codex project context so it doesn't work blind:

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

## Structured Output Discipline

Always ask Codex to return these sections:

1. **Disposition** — `approve`, `approve-with-nits`, `block`, or `needs-more-evidence`
2. **Citations** — `file:line` references, not pasted code blocks
3. **Findings / blockers** — what is wrong, what is missing, what is likely to break
4. **Missing verification** — tests, checks, runtime validation, docs, migrations, or rollback evidence still needed
5. **Risks / edge cases** — what could go wrong if the issue ships as-is
6. **Next steps** — concrete recommended actions
7. **Open questions** — what Codex is uncertain about

Summaries + references are preferable to large pasted snippets.
Never include secrets, API keys, or env values in prompts.
Tell Codex to say "needs-more-evidence" when it cannot verify the claim from the
provided repository state.

---

## Critical Evaluation of Codex Output

Treat Codex as a **hard-nosed peer reviewer, not an authority**. It can be wrong and it should be challenged when the evidence does not hold.

- Trust your own knowledge when confident. Push back if Codex contradicts something you know.
- Verify disagreements with WebSearch or docs before accepting Codex's claims.
- Remember Codex has a training cutoff. It may not know about recent API changes or library versions.
- Evaluate suggestions critically for model names, recent library versions, evolving best practices, missing tests, regression risk, and unsafe assumptions.
- If the work is not ready, say so directly. Do not soften a blocker into a suggestion.
- Do not approve, sign off, or endorse a change unless the evidence actually supports it.
- Treat `approve-with-nits` as approval only for non-blocking cleanup. If any correctness,
  security, migration, data-loss, product/compliance, or user-visible regression risk remains,
  the disposition is `block` or `needs-more-evidence`.
- If Codex says "looks fine" without citations, treat that as a failed review and rerun with
  a narrower prompt or better repository evidence.

**When Codex is wrong:**
1. State the disagreement clearly to the user
2. Provide evidence (your knowledge, web search, documentation)
3. Optionally resume the session to discuss peer-to-peer:

```bash
echo "This is Claude following up. I disagree with [X] because [evidence].
What's your reasoning?" | codex exec --skip-git-repo-check resume --last 2>/dev/null
```

---

## Sandbox Mode Reference

| Mode | Flag | Use when |
|---|---|---|
| Read-only review | `--sandbox read-only` | Analysis, review, research — **default for all exec calls** |
| Apply local edits | `--sandbox workspace-write` | Refactoring, writing new files — confirm with user first |
| Full network/system access | `--sandbox danger-full-access` | Only if task explicitly needs it — **always confirm with user** |

---

## Verification Checklist (after receiving Codex output)

Before accepting Codex's suggestions:

- [ ] Compatible with current library versions (not deprecated patterns)
- [ ] Follows this project's directory structure and conventions
- [ ] Matches auth / database / deployment patterns already in use
- [ ] Aligns with project-specific constraints from `CLAUDE.md` / `AGENTS.md`
- [ ] Considers performance and security implications
- [ ] Has a clear disposition, with citations for every blocking claim
- [ ] Names missing tests or explicitly states why existing verification is enough
- [ ] Does not ask Claude to run destructive or write-capable commands without user approval

---

## Error Handling

- If `codex --version` fails → install: `npm install -g @openai/codex`
- If `codex exec` exits non-zero → report the error, do NOT retry silently; ask user for direction
- If output contains partial results or warnings → summarize and ask how to proceed
- Codex responses typically take 30s–2 min for complex tasks; start queries early and continue local work while waiting

---

## Performance Notes

- **Thinking tokens suppressed by default** (`2>/dev/null`) — keeps Claude's context window clean
- Show stderr only if user explicitly asks to see Codex's reasoning process
- For long-running tasks, start Codex early and parallelize local analysis

---

## After Every Codex Run

1. Summarize the key findings to the user
2. Flag any disagreements or concerns
3. State the disposition exactly: approve, approve-with-nits, block, or needs-more-evidence
4. If blocked, list the minimum changes or evidence needed to unblock
5. Remind user they can resume: "You can continue this Codex session anytime — just ask me to resume it"
6. Confirm whether to apply, investigate further, or discard the findings

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
