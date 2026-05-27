# 05 — Page Patterns: SaaS Dashboards and Landing Pages

How to architect full pages, not just components. **Canonical home** for dashboard layout,
landing-page section flow, above-the-fold rules, social proof placement, and the dashboard
empty-state-as-onboarding pattern. For component-level behavior (forms, modals, buttons,
pricing tier rules) this file defers to `03-component-patterns.md`.

> **See also**
>
> - For component-level patterns (forms, modals, tables, navigation) → `03-component-patterns.md`
> - For spacing, typography, and color tokens → `02-pixel-perfect-standards.md`
> - For distinctive aesthetic and the Bento 2.0 paradigm → `09-creative-arsenal.md`
> - For anti-patterns to avoid (equal-card-columns, hero-over-dark-image) → `06-anti-patterns.md` → Visual AI Tells
> - For redesigning an existing page → `08-redesign-audit.md`

---

## SaaS Dashboard Layout

```
┌─────────────────────────────────────────────────────────┐
│ Top Bar (56–64 px): logo, search, user menu             │
├──────────┬──────────────────────────────────────────────┤
│ Sidebar  │  Main content area                            │
│ 240–280  │  (breadcrumbs if depth > 2)                   │
│ collapsed│                                               │
│  64–80   │  Cards / data / forms                         │
│          │                                               │
└──────────┴──────────────────────────────────────────────┘
```

For the navigation-pattern-by-hierarchy table (sidebar vs top nav vs tabs vs breadcrumbs), see
`03-component-patterns.md` → Navigation. Sidebar collapse state persists across sessions;
active state visually distinct from hover.

---

## Dashboard Content Hierarchy

1. **Value-first metrics.** "You saved 4 hours" > raw numbers. Surface insight, not data.
2. **Actionable insights.** Every metric should imply a next action.
3. **Progressive disclosure.** Summary → detail on demand. Don't dump 50 fields on a card.
4. **Role-based views.** Different personas need different data on the same dashboard. Don't
   build one giant dashboard for everyone.
5. **Time-to-first-value.** New users land and immediately see what to do. Empty dashboard with
   no CTA = activation bleeding.

---

## Data Visualization

- Use semantic colors: red = negative, green = positive
- Pattern/icon backup for colorblind accessibility (don't rely on color alone)
- Always include legends
- Axis labels are mandatory
- Truncate long labels with tooltips
- Numeric columns use `font-variant-numeric: tabular-nums`
- Empty state when filters return zero results

---

## Empty States (Dashboard)

For the base empty-state pattern (icon + headline + description + CTA), see
`03-component-patterns.md` → Empty States. Dashboard-specific application:

- **Brand-new account:** design a composed "getting started" view that walks the user to
  activation — not just an icon and a button.
- **Filtered list returning zero:** explain what filter is hiding results and offer a one-click
  "clear filters" action.
- The dashboard empty state is your single highest-leverage onboarding surface. Treat it as a
  feature, not a placeholder.

---

## Settings Pages

See `03-component-patterns.md` → Settings Pages for the canonical bucket + side-panel layout
and Danger Zone rules.

---

## Toast / Notification Timing

See `03-component-patterns.md` → Notifications, Toasts, and Tooltips for the canonical timing
formula, stacking rules, and dismissal behavior.

---

## URL State for Dashboards

URL must reflect:

- Active filters
- Current tab
- Pagination
- Expanded panels
- Search query

Use `nuqs` or equivalent. Users expect to share URLs and have the recipient see the same view.

---

## Landing Page Sections (Standard Flow)

```
1. Hero (headline + subheadline + CTA + visual)
2. Social proof (logo bar, testimonial snippet)
3. Problem / Solution
4. Features / Benefits (3–4 max)
5. Detailed testimonials
6. Pricing (if applicable)
7. FAQ
8. Final CTA
9. Footer
```

---

## Above the Fold

Within the initial viewport, the user must see:

1. Clear headline (5–10 words)
2. Supporting subheadline (value proposition, one sentence)
3. **Single** primary CTA
4. Visual element (hero image, illustration, or product shot)

No surprises below the fold — if the value isn't visible in 3 seconds, the visitor bounces.

---

## CTA Button Design

For universal button rules (touch target, copy patterns, transitions), see
`03-component-patterns.md` → Buttons. Landing-page-specific:

- **Padding:** ~2× the CTA font size (oversized vs in-app buttons)
- **Color:** high contrast against the section background; warm colors create urgency
- **Frequency:** one primary CTA per viewport. Secondary CTAs are ghost or text style — never
  two equally-weighted CTAs side by side
- **Hierarchy:** if a secondary action exists (e.g. "watch demo"), it must look distinctly
  secondary — not just a different color of the same shape

---

## Social Proof Placement

- **Logo bar:** immediately after hero
- **Testimonials:** near points of objection (next to pricing, on long-form sections)
- **Stats:** near pricing
- **Trust badges:** near forms and checkout

---

## Pricing Tables (Landing-Page)

See `03-component-patterns.md` → Pricing Tables for the canonical tier rules (max count,
highlight method, toggle, alignment). On a landing page specifically, also:

- Place near a testimonial block (objection-handling proximity)
- Annual/monthly toggle defaults to whichever yields the better headline price
- Stats and trust badges adjacent to the table, not buried in the footer

---

## Form Optimization for Conversion

For the canonical form rules (single column, label position, blur validation, placeholder
patterns) see `03-component-patterns.md` → Forms. Landing-page-specific conversion data:

- **4 fields vs 11 fields = 120% more conversions** — minimize aggressively
- **Phone field alone drops conversion ~58%** — only ask if essential
- **Single column** also has 120% fewer errors than multi-column

---

## Layout Variety (Anti-AI-Layout)

Avoid the three default AI-generated landing layouts:

1. **Three equal-width feature card columns** — most generic. Replace with:
   - Zig-zag rows (image+text alternating sides)
   - Asymmetric grid (one large + two small)
   - Horizontal scroll
   - Masonry layout
2. **Centered hero with text over dark image** — try:
   - Split-screen (left text, right visual)
   - Left-aligned asymmetric (visual breaks the column on the right)
3. **Three-tower pricing** — highlight the recommended tier with **color + emphasis**, not extra
   height alone

---

## Above-the-Fold Performance

- LCP under 2.5 s
- CLS under 0.1
- INP under 200 ms
- Hero image: explicit dimensions, `priority`/`fetchpriority="high"`, optimized format
- Fonts: `next/font` (or framework equivalent) with `font-display: swap`
- Preconnect to CDN/asset domains
- Above-fold should render before any heavy client JS hydrates

---

## Spacing for Landing

- Section spacing: 80–120 px between major sections
- Section header → content gap consistent across sections
- Aggressive whitespace beats density on marketing pages
- Cap content width around 1200–1440 px with auto margins for ultrawide screens
