# 08 — Redesign Workflow

Upgrading an existing website or app: audit generic patterns, apply premium fixes, preserve
working behavior. Not a rewrite — a targeted upgrade.

> **See also**
>
> - For **what to flag** during the audit (the catalog) → `06-anti-patterns.md`
> - For the severity buckets and output tables used during Diagnose → `10-review-protocol.md`
> - For pixel-perfect values during Fix → `02-pixel-perfect-standards.md`
> - For implementation specifics (Tailwind, dark mode, hydration) during Fix → `04-implementation-build.md`
> - For anti-slop pattern library (Bento 2.0, tilt cards, etc.) → `09-creative-arsenal.md`

---

## When to Use This Workflow

- User asks to redesign, restyle, modernize, polish, or improve an existing UI
- Audit current frontend code and make targeted visual improvements without changing the
  product architecture
- Design feels generic, AI-generated, poorly spaced, visually flat, or missing responsive,
  interactive, loading, empty, or error states

---

## Limitations

- Upgrade existing UI — do not rewrite frameworks, restructure information architecture, or
  expand product scope by default
- Preserve working behavior, routing, data flows, accessibility semantics, and tests
- Validate redesigned screens in the actual app across supported browsers and viewport sizes
  before declaring done

---

## The Sequence

### 1. Scan

Read the codebase. Identify:

- Framework (Next.js, Vite, plain HTML, etc.)
- Styling method (Tailwind, vanilla CSS, styled-components, CSS modules)
- Current design patterns
- Component library in use
- Token/theme system (if any)

### 2. Diagnose

Run the full anti-pattern catalog from `06-anti-patterns.md` against the codebase. Walk
through each section in `06`:

- Visual AI Tells (color, typography, layout, depth)
- Content Anti-Patterns
- UX Anti-Patterns
- Technical Anti-Patterns
- Mobile Anti-Patterns
- Strategic Omissions
- Composition Anti-Patterns
- Code Quality Anti-Patterns

Output a punch list with `file:line` for every violation. Use the severity buckets from
`10-review-protocol.md` (Critical / Important / Opportunities).

### 3. Fix

Apply targeted upgrades working with the existing stack. Do not rewrite from scratch.

Use the **Upgrade Techniques** below to replace specific generic patterns with stronger ones.
For canonical spacing/typography/color values consult `02-pixel-perfect-standards.md`. For
implementation patterns (Tailwind, dark mode, hydration) consult `04-implementation-build.md`.

---

## Upgrade Techniques

High-impact patterns to replace generic ones. For the full anti-slop pattern library (Bento
2.0, parallax tilt cards, kinetic typography, holographic foil, etc.) see
`09-creative-arsenal.md`.

### Typography upgrades

- **Variable font animation** — interpolate weight or width on scroll/hover
- **Outlined-to-fill transitions** — text starts as stroke, fills with color on scroll entry
- **Text mask reveals** — typography as a window to video or animated imagery behind it
- **Distinctive display + body pairing** — Fraunces + Inter Tight, Cabinet Grotesk + IBM Plex,
  etc. See `02-pixel-perfect-standards.md` → Typography for the recommended pairings.

### Layout upgrades

- **Broken grid / asymmetry** — elements deliberately overlap or bleed off-screen
- **Whitespace maximization** — force focus on a single element
- **Parallax card stacks** — sections stick and stack on scroll
- **Split-screen scroll** — halves move opposite directions
- **Bento grid** — asymmetric tiles; see `09-creative-arsenal.md` for Bento 2.0 baseline

### Motion upgrades

For the full motion framework (which designer perspective applies — Emil / Jakub / Jhey), see
`07-motion-framework.md`. Common upgrade moves:

- **Smooth scroll with inertia** — cinematic feel
- **Staggered entry** — cascade with 30–80 ms delays + Y-axis + opacity. See
  `07a-emil-craft.md` → Stagger Animations.
- **Spring physics** — replace linear easing
- **Scroll-driven reveals** — expanding masks, draw-on SVG paths

### Surface upgrades

- **True glassmorphism** — `backdrop-filter: blur` + 1 px inner border + inner shadow (not just
  blur)
- **Spotlight borders** — card borders illuminate under cursor
- **Grain/noise overlays** — `fixed pointer-events-none` pseudo-element
- **Colored, tinted shadows** — carry the hue of the background. See `07b-jakub-polish.md` →
  Shadows Instead of Borders for multi-layer recipe.

---

## Fix Priority Order

Apply changes in this order for maximum visual impact with minimum risk:

1. **Font swap** — biggest instant improvement, lowest risk
2. **Color palette cleanup** — remove clashing or oversaturated colors
3. **Hover and active states** — makes interface feel alive
4. **Layout and spacing** — proper grid, max-width, consistent padding
5. **Replace generic components** — swap cliche patterns for modern alternatives
6. **Add loading, empty, and error states** — makes it feel finished
7. **Polish typography scale and spacing** — the premium final touch

---

## Rules

- Work with the existing tech stack. Do not migrate frameworks or styling libraries.
- Do not break existing functionality. Test after every change.
- Before importing a new library, check `package.json`.
- If the project uses Tailwind, check the major version (v3 vs v4) before modifying config —
  see `04-implementation-build.md` → Dependency Verification.
- If the project has no framework, use vanilla CSS.
- Keep changes reviewable and focused. Small, targeted improvements over big rewrites.

---

## Output Format During Redesign

When reporting findings during the Diagnose phase, use the severity-tagged tables from
`10-review-protocol.md`:

```
## Critical (must fix this PR)
| | Issue | File | Action |
|-|-------|------|--------|
| 🔴 | [issue] | `file:line` | [fix] |

## Important (should fix in redesign pass)
| | Issue | File | Action |
|-|-------|------|--------|
| 🟡 | [issue] | `file:line` | [fix] |

## Opportunities (next iteration)
| | Enhancement | Where | Impact |
|-|-------------|-------|--------|
| 🟢 | [idea] | `file:line` | [impact] |
```

When proposing fixes during the Fix phase, also invoke `/web-design-guidelines` on the same
files for code-level compliance checks.
