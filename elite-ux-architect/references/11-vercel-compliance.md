# 11 — Vercel Web Interface Guidelines Compliance

Code-level compliance pass against the Vercel Web Interface Guidelines (80+ rules). Loaded
during code reviews to catch the categories the persona-driven review doesn't cover by design:
typography characters, form attribute hygiene, hydration safety, touch behavior, Intl, safe
areas, dark-mode controls, and performance plumbing.

> **See also**
>
> - For the review structure that consumes this output → `10-review-protocol.md`
> - For the canonical anti-pattern catalog (broader categories) → `06-anti-patterns.md`
> - For implementation patterns (Tailwind, hydration, dependencies) → `04-implementation-build.md`

---

## When to Load This Reference

- During any "Review code" workflow — loaded **mandatorily** alongside `10 + 06 + 03 + 04`
- When the user asks for a "compliance check", "Vercel-style review", or "deep code audit"
- When you've completed the persona-driven review and need to catch the code-level rules the
  protocol intentionally doesn't duplicate

Skipping this reference is a **review gap**, not an option. Note it explicitly in your report
if you couldn't apply it (e.g., source URL unreachable).

---

## Methodology

### Step 1: Fetch the latest rules

The authoritative source is maintained by Vercel and updated continuously. Fetch fresh before
each review — do not rely on cached knowledge:

```
https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md
```

Use `WebFetch` to retrieve. The fetched content contains all rules + output-format
instructions. Apply those instructions literally.

If `WebFetch` is unavailable in the current environment, fall back to the categories below as
a degraded checklist — but note the staleness risk in the report.

### Step 2: Apply the rules to the target files

Read the files in scope. For each rule in the fetched guidelines, walk the relevant lines.
Emit findings in **terse `file:line: violation`** format. No prose, no celebrating wins —
just violations. The persona review (in `10-review-protocol.md`) does the wins; this pass is
pure compliance.

### Step 3: Merge into the review report

Hand findings to the review report's "Compliance Findings" section
(`10-review-protocol.md` → Output Format). Severity rules:

- **Critical** if the rule violates accessibility, security, or breaks core flow
- **Important** if it's a standards violation users will feel (touch delay, missing dark mode,
  CLS risk)
- **Opportunity** otherwise

---

## Rule Categories (Degraded-Mode Checklist)

If the fetched guidelines are unavailable, apply at least these categories. This is a subset
of what the fresh fetch covers.

### Typography characters

- `…` ellipsis character instead of three periods `...`
- Curly quotes `"` `"` `'` `'` instead of straight `"` `'`
- `&nbsp;` in measurements (`10&nbsp;MB`), keyboard shortcuts, and brand names
- `text-wrap: balance` on headings; `text-wrap: pretty` on body

### Form attributes

- Every `<input>` has a semantic `type` (`email`, `tel`, `url`, `number`, `search`)
- `inputmode` set when type and keyboard intent differ (`inputmode="numeric"` for OTPs)
- `autocomplete` with meaningful tokens (`autocomplete="email"`, `current-password`,
  `one-time-code`)
- `spellcheck="false"` on emails, codes, usernames
- `htmlFor` ties every `<label>` to its input
- `placeholder` ends with `…` and shows the example pattern, never a label
- Submit button enabled before user attempts submission

### Hydration safety

- Controlled inputs with `value` always have `onChange` (or use `defaultValue`)
- Date/time rendering uses `Intl.DateTimeFormat` after mount (placeholder on server)
- `suppressHydrationWarning` only on the specific element that needs it, not blanket on
  `<html>` or `<body>`
- No `Date.now()` / `Math.random()` directly in JSX

### Touch behavior

- `touch-action: manipulation` on interactive elements (kills 300 ms iOS double-tap delay)
- `-webkit-tap-highlight-color` set intentionally (transparent or brand color)
- `overscroll-behavior: contain` on modals, drawers, sheets
- `inert` applied to non-target regions during drag

### Animation rules

- Animate only `transform` and `opacity` (GPU)
- Never animate layout properties (`width`, `height`, `margin`, `padding`, `top`, `left`,
  `gap`)
- `transition: all` is banned — specify properties (`transition-[color,background-color]`)
- `transform-origin` matches interaction source (popovers from trigger, modals from center)
- Respect `prefers-reduced-motion`

### Accessibility

- Icon buttons have `aria-label`
- `focus-visible` (not `focus`) for keyboard-only focus rings
- `outline: none` requires a `focus-visible:ring-*` replacement
- Semantic HTML: `<nav>`, `<main>`, `<article>`, `<aside>`, `<section>` — not div soup
- `scroll-margin-top` on heading anchors when there's a sticky header
- "Skip to content" link in root layout

### URL state

- Filters, current tab, pagination, expanded panels, search query — all reflected in URL
- Use `nuqs` (Next.js) or equivalent — never local-state-only for shareable views

### Intl APIs

- `Intl.DateTimeFormat` for dates/times (never hardcoded `toLocaleDateString` strings)
- `Intl.NumberFormat` for numbers and currency
- `translate="no"` on brand names, code identifiers, product names
- ICU messages (`{count, plural, one {…} other {…}}`) — never `n === 1 ? '' : 's'`

### Safe areas

- `env(safe-area-inset-top|right|bottom|left)` on full-bleed layouts (notches, home indicator)
- `min-h-[100dvh]` not `h-screen` (iOS Safari layout jump)

### Dark mode

- `color-scheme: light dark` (or `colorScheme` style) on `<html>` — native scrollbars and
  form controls won't dark-mode without it
- `<meta name="theme-color">` matches the current page background
- Every component verified in both light and dark, every state

### Performance

- `<link rel="preconnect">` for CDN/asset domains
- Critical fonts: `<link rel="preload" as="font">` with `font-display: swap`
- Hero image: explicit dimensions + `priority` / `fetchpriority="high"`
- Below-fold images: `loading="lazy"`, `decoding="async"`
- Virtualize lists > 50 items (`virtua`, `react-virtual`, or `content-visibility: auto`)

### Content handling

- `truncate`, `line-clamp-*`, or `break-words` on every text container that can overflow
- Flex children containing text have `min-w-0` to allow truncation
- `text-wrap: balance` on headings; `pretty` on body

---

## Output Format

For each finding:

```
<file:line> — <rule violated> — <fix>
```

Example:

```
apps/web/src/app/layout.tsx:54 — missing color-scheme on <html> — add style={{ colorScheme: 'light dark' }}
apps/web/src/components/features/orgs/workspace-list.tsx:153 — transition-all banned, animating gap layout prop — transition-[color,gap]
apps/web/src/app/[locale]/(app)/orgs/[orgSlug]/workspaces/[workspaceSlug]/reports/_components/report-asset-image.tsx:25 — <img> missing width/height (CLS risk) — add explicit dimensions or next/image
```

Hand these to the review report under "Compliance Findings (from web-interface-guidelines)".

---

## Limitations

- **Not a substitute** for environment-specific validation (e2e, Playwright) or expert review.
- **Source freshness matters.** If `WebFetch` failed, say so — the degraded checklist above is
  weeks-to-months stale.
- **Code-only.** This pass reads source files. For Figma compliance, ask for the corresponding
  code first.
