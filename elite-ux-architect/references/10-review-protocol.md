# 10 — Code Review Protocol (Structure)

How to structure a UX code review: severity buckets, output format, orchestration with
`/web-design-guidelines`. This file is the **structure** for reviews. **What to flag** lives
in `06-anti-patterns.md` (catalog) and the specialized references (`02` for spacing/colors,
`03` for patterns, `04` for implementation, `07` for motion).

> **See also**
>
> - For the canonical list of issues to flag → `06-anti-patterns.md`
> - For the persona and communication standards driving review tone → `01-persona-and-principles.md`
> - For the redesign workflow that uses the same severity buckets → `08-redesign-audit.md`
> - For code-level Vercel compliance (invoked alongside this protocol) → `/web-design-guidelines`

---

## When to Use This Protocol

- User says "review", "audit", "check", "look at" + a file/directory/PR
- After a feature is built and before merge
- When standards have been updated and existing code needs to be checked
- When the design feels off but the user can't articulate why

---

## Setup — What to Load

This protocol drives the structure. To know what to flag, also load:

- `06-anti-patterns.md` — the canonical catalog of things to flag
- `02-pixel-perfect-standards.md` — for spacing/typography/color violations
- `03-component-patterns.md` — for pattern expectations (forms, modals, states)

For motion-heavy code, also load `07-motion-framework.md` and route to the right designer
reference based on project context.

For project-specific code, also load the project's UX skill (e.g. `postbuzz_ux_architect`) for
competitive context and project-specific constraints.

---

## Companion Skill: `/web-design-guidelines`

After your persona-driven review, invoke `/web-design-guidelines` on the same files. It
catches code-level compliance issues this protocol intentionally does **not** duplicate:

- Typography characters (`…` vs `...`, curly vs straight quotes, `&nbsp;` in measurements)
- Form `autocomplete`, semantic `type`, `inputmode`, spellcheck
- Hydration safety (controlled `value` + `onChange`, SSR/client mismatch)
- Touch behavior (`touch-action`, `overscroll-behavior`, `inert`,
  `-webkit-tap-highlight-color`)
- `Intl.*` for dates/numbers, `translate="no"` on brand names
- `<link rel="preconnect">`, font preload, virtualization triggers
- Safe-area-inset, `color-scheme`, `theme-color`

Merge `/web-design-guidelines` findings into your final report under the appropriate severity
buckets below.

---

## What to Walk Through (Pointers, Not Content)

Cover these categories. Specific violations to flag live in the referenced file — don't
duplicate them here.

| Category                                                                                   | Where to find the checks                                                                     |
| ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Visual fidelity (spacing, typography, color, radius, shadows, icons, motion timing)        | `02-pixel-perfect-standards.md`                                                              |
| State completeness (loading, empty, error, populated)                                      | `03-component-patterns.md` → Empty/Loading/Error States                                      |
| Component patterns (forms, tables, modals, navigation, notifications)                      | `03-component-patterns.md`                                                                   |
| Responsive and cross-context (375 / 768 / 1280+, dark mode, RTL)                           | `02-pixel-perfect-standards.md` → Responsive Precision                                       |
| Interaction quality (keyboard, touch targets, focus states, confirmations)                 | `02-pixel-perfect-standards.md` → Touch Targets + `03` → Buttons                             |
| Accessibility (landmarks, accessible names, live regions, contrast, reduced motion)        | `02-pixel-perfect-standards.md` → Color contrast + `07-motion-framework.md` → reduced-motion |
| Performance (lazy load, image dims, Server Components, Suspense, virtualization)           | `04-implementation-build.md` → Performance Building Blocks                                   |
| Content and i18n (no hardcoded strings, locale formatters, RTL verified)                   | `04-implementation-build.md` → Internationalization                                          |
| Anti-patterns (AI tells, dark patterns, technical anti-patterns)                           | `06-anti-patterns.md` (full catalog)                                                         |
| Code-level compliance (typography chars, autocomplete, hydration, touch, Intl, safe areas) | Invoke `/web-design-guidelines`                                                              |

For project-specific items (locale parity, design tokens specific to that codebase, competitive
benchmarks), also consult the project skill (e.g. `postbuzz_ux_architect`).

---

## Output Format

Every review emits this exact structure.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 UX REVIEW — [Component / File / PR Name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 [N] Critical  |  🟡 [N] Important  |  🟢 [N] Opportunities
Reviewed by: elite-ux-architect (+ /web-design-guidelines)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Overall Assessment

[1 paragraph: what's working, what's not, recommendation to merge / iterate / rewrite]

## Critical (Must Fix — Blocks Merge)

| | Issue | File | Action |
|-|-------|------|--------|
| 🔴 | Form input missing `<label>` — fails accessibility | `signup-form.tsx:42` | Wrap input in `<label>` or add `htmlFor` |
| 🔴 | `<div onClick>` for primary action | `card.tsx:18` | Convert to `<button>` |

## Important (Should Fix — This PR)

| | Issue | File | Action |
|-|-------|------|--------|
| 🟡 | Hardcoded `text-red-500` instead of token | `error-banner.tsx:12` | Use `text-destructive` |
| 🟡 | Skeleton dimensions don't match content | `dashboard.tsx:88` | Set explicit width/height on skeleton |

## Opportunities (Next Iteration)

| | Enhancement | Where | Impact |
|-|-------------|-------|--------|
| 🟢 | Add stagger to list entry | `feed.tsx:24` | More polished feel; 30 ms delay between items |
| 🟢 | Tint shadow instead of pure black | `card.tsx:8` | Better adaptation on varied backgrounds |

## What's Working Well

- [Concrete observation — file:line]
- [Concrete observation]

## Compliance Findings (from /web-design-guidelines)

[Merged list of file:line violations from the Vercel guidelines pass, deduplicated against
the issues above. Reference categories: typography, forms, animation, performance,
accessibility, hydration, touch, i18n, safe-areas.]

## Final Verdict

[Merge / iterate / rewrite. One sentence on why.]
```

---

## Severity Definitions

- **🔴 Critical** — blocks merge. Accessibility failure, security vulnerability, broken core
  flow, destructive action without confirmation, missing required state (empty/loading/error
  for a populated view).
- **🟡 Important** — should fix this PR. Standards violation that the user will feel but won't
  block them. Hardcoded tokens, missing hover states, suboptimal animation, missing
  `prefers-reduced-motion`.
- **🟢 Opportunity** — could enhance. Optical alignment, additional polish, a better creative
  pattern, performance optimization beyond targets.

---

## Scope Rules

- **Code-only.** This protocol reads source files. For screenshot/Figma audits without code,
  ask for the corresponding files first.
- **Cite `file:line` for every finding.** No vague "the modal needs work" — point to the line.
- **Propose the fix.** "Missing focus ring" is incomplete. "Missing focus ring — add
  `focus-visible:ring-2 focus-visible:ring-ring`" is complete.
- **Don't write fixes during review.** Output the punch list. The user applies them with a
  follow-up build-mode invocation.
- **Don't trigger reviews proactively.** Wait until the user names a file or directory.

---

## What This Protocol Doesn't Cover

- **Strategy and roadmap decisions** — that's the persona's job, see `01-persona-and-principles.md`
- **Building new UI from scratch** — load `02` + `03` + `04` instead
- **Motion-only audits** — use `07-motion-framework.md` directly
- **Pure compliance scan** — use `/web-design-guidelines` directly without this protocol
- **Brand strategy / competitive intelligence** — that's the project skill's domain
- **Redesign workflow** — that's `08-redesign-audit.md`
