# 10 — Code Review Protocol (Structure)

How to structure a UX code review: severity buckets, output format, orchestration with the
Vercel compliance pass. This file is the **structure** for reviews. **What to flag** lives
in `06-anti-patterns.md` (catalog) and the specialized references (`02` for spacing/colors,
`03` for patterns, `04` for implementation, `07` for motion).

> **See also**
>
> - For the canonical list of issues to flag → `06-anti-patterns.md`
> - For the persona and communication standards driving review tone → `01-persona-and-principles.md`
> - For the redesign workflow that uses the same severity buckets → `08-redesign-audit.md`
> - For code-level Vercel compliance (loaded alongside this protocol) → `11-vercel-compliance.md`

---

## When to Use This Protocol

- User says "review", "audit", "check", "look at" + a file/directory/PR
- After a feature is built and before merge
- When standards have been updated and existing code needs to be checked
- When the design feels off but the user can't articulate why

---

## Setup — What to Load

This protocol drives the structure. Load lazily based on what the code actually does.

**Mandatory for every review:**

- `06-anti-patterns.md` — the canonical catalog of things to flag
- `11-vercel-compliance.md` — code-level compliance pass (run its WebFetch step)

**Load only when the code under review touches that category:**

- `02-pixel-perfect-standards.md` — only when flagging spacing / typography / color / radius values
- `03-component-patterns.md` — only when reviewing forms, modals, tables, navigation, or state UI
- `04-implementation-build.md` — only when reviewing Tailwind/CVA, hydration, viewport, or performance
- `07-motion-framework.md` (+ designer ref) — only for motion-heavy code
- Project skill (e.g. `postbuzz_ux_architect`) — only when competitive context or project-specific tokens matter

Loading everything for every review is wasteful. A pure-data table review doesn't need motion or
landing-page references. Be honest about what the code does, then pull just those files.

---

## Vercel Compliance Pass (Mandatory)

Load `references/11-vercel-compliance.md` and follow its methodology — `WebFetch` the latest
guidelines, apply the rules, emit terse `file:line` findings. The persona-driven review
intentionally does **not** duplicate these categories:

- Typography characters (`…` vs `...`, curly vs straight quotes, `&nbsp;` in measurements)
- Form `autocomplete`, semantic `type`, `inputmode`, spellcheck
- Hydration safety (controlled `value` + `onChange`, SSR/client mismatch)
- Touch behavior (`touch-action`, `overscroll-behavior`, `inert`,
  `-webkit-tap-highlight-color`)
- `Intl.*` for dates/numbers, `translate="no"` on brand names
- `<link rel="preconnect">`, font preload, virtualization triggers
- Safe-area-inset, `color-scheme`, `theme-color`

Merge findings into your final report under "Compliance Findings (from
web-interface-guidelines)" in the Output Format section. **Skipping this is a review gap**,
not an option — note it explicitly if `WebFetch` was unavailable.

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
| Code-level compliance (typography chars, autocomplete, hydration, touch, Intl, safe areas) | `references/11-vercel-compliance.md`                                                         |

For project-specific items (locale parity, design tokens specific to that codebase, competitive
benchmarks), also consult the project skill (e.g. `postbuzz_ux_architect`).

---

## Verification Methodology (Run Before Asserting Anything)

A review claim like "state completeness is solid" is **only valid if grep-verified**. Don't
assert from sampled reading — run the checks. The framework matters because subtle gaps (a
missing `error.tsx` in one detail route) are invisible to file-by-file reading but obvious to
a directory scan.

### State completeness parity

Every route directory with a `page.tsx` should have `loading.tsx` AND `error.tsx`. Verify:

```bash
find <route-root> -type d | while read d; do
  if [ -f "$d/page.tsx" ]; then
    has_loading=$(test -f "$d/loading.tsx" && echo 1 || echo 0)
    has_error=$(test -f "$d/error.tsx" && echo 1 || echo 0)
    [ "$has_loading$has_error" != "11" ] && echo "GAP: $d loading=$has_loading error=$has_error"
  fi
done
```

Each gap is a `🔴 Critical` finding.

### Anti-pattern grep sweep

Run these greps before claiming the codebase is clean. Missing any of these checks is a review
gap, not a clean codebase:

```bash
# Animation anti-patterns (see references/06)
grep -rn "transition-all\|transition: all" --include="*.tsx"
grep -rn "scale(0)" --include="*.tsx" | grep -v "scale(0\."
grep -rn "h-screen" --include="*.tsx"

# Accessibility anti-patterns
grep -rn "<div[^>]*onClick" --include="*.tsx"
grep -rn "<img " --include="*.tsx" | grep -v "width="
grep -rn "outline-none\|outline: none" --include="*.tsx"

# Multi-line JSX caveat: `<button>` type and `<input>` label checks are unreliable
# via single-line grep — attrs span lines. Use AST tooling or `grep -A3 '<button'`
# then visually confirm. A clean grep does NOT mean clean code.

# Dark-mode / native-control compliance
grep -rn "colorScheme\|color-scheme" --include="*.tsx" --include="*.css" app/  # should be set on <html>

# Performance anti-patterns
grep -rn "z-\[[0-9]\{4,\}\]" --include="*.tsx"
grep -rn 'bg-\${' --include="*.tsx"

# Layout-primitive bypass (project-specific — adapt per CLAUDE.md)
grep -rn 'className=.*\\bspace-y-\|className=.*\\bflex items-center gap-' --include="*.tsx"
```

Count violations per file; cite the top offenders with `file:line`. If a grep returns nothing,
say so explicitly ("0 instances of `transition-all` found") — silence is ambiguous.

---

## Output Format

Every review emits this exact structure.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 UX REVIEW — [Component / File / PR Name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 [N] Critical  |  🟡 [N] Important  |  🟢 [N] Opportunities
Reviewed by: elite-ux-architect (+ Vercel compliance pass)
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

## Compliance Findings (from Vercel Web Interface Guidelines)

[Merged list of file:line violations from the Vercel guidelines pass, deduplicated against
the issues above. Reference categories: typography, forms, animation, performance,
accessibility, hydration, touch, i18n, safe-areas.]

## Final Verdict

[Merge / iterate / rewrite. One sentence on why.]
```

---

## Severity — One Principle

**Severity equals user-blocking impact.** Not how strongly the rule feels violated, not how
much the linter would complain, not how senior-engineer-correct the fix would be. Ask: "Can a
real user complete their task right now?" Then:

- **🔴 Critical — they cannot.** Merge blocker.
- **🟡 Important — they can, but it's degraded.** Fix in this PR.
- **🟢 Opportunity — they can, and it works fine.** Polish for next iteration.

When in doubt, downgrade. Over-claiming Critical is the most common audit failure — it burns
trust and trains the reader to ignore future findings.

### Applying the principle — worked examples

| Situation                                                                | Reasoning                                                          | Severity       |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------ | -------------- |
| `<div onClick>` is the only way to trigger a primary action              | Keyboard user is blocked                                           | 🔴 Critical    |
| `outline: none` (or `outline-none`) with no `focus-visible:` replacement | Keyboard user sees nothing on focus                                | 🔴 Critical    |
| Form input has no `<label>` / `aria-label` / `aria-labelledby`           | Screen-reader user cannot identify the field                       | 🔴 Critical    |
| Destructive action (delete, cancel sub) fires with no confirmation       | One misclick = data loss                                           | 🔴 Critical    |
| Populated view ships without empty / loading / error states              | User sees broken UI in real conditions                             | 🔴 Critical    |
| Missing `loading.tsx` / `error.tsx` for a route with `page.tsx`          | White flash + framework-default error page — degraded, not blocked | 🟡 Important   |
| Hardcoded user-facing string in an i18n-configured project               | Wrong-language users see English; readable but breaks parity       | 🟡 Important   |
| `transition-all` animating layout properties                             | Janky animation; flow still works                                  | 🟡 Important   |
| `<img>` with no explicit width/height                                    | CLS hit; image still loads                                         | 🟡 Important   |
| Raw `flex gap-*` in a project with layout primitives                     | Inconsistency, not user impact                                     | 🟡 Important   |
| No `focus-visible:ring-*` AND no `outline-none` (browser default rings)  | Keyboard user sees the browser default — not blocked               | 🟢 Opportunity |
| Inconsistent focus token across two buttons                              | Style drift; still focusable                                       | 🟡 Important   |
| Stagger / spring missing on a list                                       | Functional; could feel nicer                                       | 🟢 Opportunity |
| Pure-black shadow that could be tinted                                   | Functional; could adapt better                                     | 🟢 Opportunity |

The audit error to avoid most aggressively: claiming a button is "keyboard inaccessible" when
it has no explicit focus styles AND no outline suppression. The browser draws a default ring.
The user can see focus. The fix is consistency (🟡), not accessibility (🔴).

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
- **Pure compliance scan** — load only `references/11-vercel-compliance.md` and follow its methodology
- **Brand strategy / competitive intelligence** — that's the project skill's domain
- **Redesign workflow** — that's `08-redesign-audit.md`
