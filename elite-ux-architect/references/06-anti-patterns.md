# 06 — Anti-Patterns and AI Tells (Canonical Catalog)

The catalog of things that mark an interface as AI-generated, generic, or fundamentally broken.
**This is the canonical home** for anti-patterns. Other reference files brief-mention items here
and link back.

> **See also**
>
> - For the hard "what you will not accept" constraint list (stricter, structural rules) → `01-persona-and-principles.md`
> - For implementation rules cross-referenced from technical anti-patterns → `04-implementation-build.md`
> - For the review structure that consumes this catalog → `10-review-protocol.md`
> - For motion-specific anti-tells (scale(0), ease-in on UI) → `07a-emil-craft.md`

---

## Contents

- [Visual AI Tells](#visual-ai-tells) — color, typography, layout, depth
- [Content Anti-Patterns](#content-anti-patterns) — the "Jane Doe" effect
- [UX Anti-Patterns](#ux-anti-patterns) — dark patterns, missing states
- [Technical Anti-Patterns](#technical-anti-patterns) — code-level failures
- [Mobile Anti-Patterns](#mobile-anti-patterns)
- [Strategic Omissions](#strategic-omissions) — what AI forgets
- [Composition Anti-Patterns](#composition-anti-patterns)
- [Code Quality Anti-Patterns](#code-quality-anti-patterns)
- [Quick-Reject Checklist](#quick-reject-checklist-for-code-review) — for code review

---

## Visual AI Tells

The most common fingerprints of unedited AI-generated UI.

- **Purple/blue gradient on white.** Most common AI fingerprint. Banned. Use neutral bases +
  single considered accent.
- **`Inter` as display font.** The default AI font choice. Banned. Use Geist, Outfit, Cabinet
  Grotesk, Satoshi, Space Grotesk, Fraunces, or Instrument Serif. Same banlist for Roboto,
  Arial.
- **Pure `#000000`.** Use off-black or dark charcoal (`#0a0a0a`, `#121212`, Zinc-950).
- **Three equal-width card columns as feature row.** Most generic AI layout. Use zig-zag,
  asymmetric grid, or horizontal scroll. See `08-redesign-audit.md` for upgrade techniques.
- **Centered hero with text over dark image.** Try split-screen, left-aligned asymmetric, or
  product-shot-driven hero.
- **Oversaturated accents.** Keep saturation below 80%. Desaturate so accents blend, not scream.
- **More than one accent color.** Pick one. Remove the rest. See `02-pixel-perfect-standards.md`
  → Color for the 60-30-10 ratio.
- **Generic black `box-shadow`** at low opacity. Tint shadows to match the surrounding hue. See
  `07b-jakub-polish.md` for shadow-over-border technique on varied backgrounds.
- **Inconsistent border-radius.** One value across the visual group.
- **Mixed gray families** (warm + cool). Stick to one gray temperature throughout.
- **Perfectly even gradients.** Break with radial gradients, noise overlays, or mesh gradients.
- **Lucide / Feather icons exclusively.** The default AI icon library. Try Phosphor, Heroicons,
  or a custom set.
- **Rocket for "Launch", shield for "Security".** Cliche metaphors. Use bolt, fingerprint,
  spark, vault, beacon.
- **Stock "diverse team" photos.** Use real team photos, candid shots, or a consistent
  illustration style.
- **Flat design with zero texture.** Add subtle noise/grain/micro-patterns.
- **Random dark sections inside an otherwise light-mode page.** Looks like a copy-paste
  accident. Commit to one direction or use a slightly darker shade of the same palette.
- **Empty flat sections with no visual depth.** Add background imagery, subtle patterns, or
  ambient gradients.

---

## Content Anti-Patterns (The "Jane Doe" Effect)

These tell readers instantly that no one edited the output.

- **Generic names:** "John Doe", "Jane Smith" → diverse, realistic-sounding names
- **Round fake numbers:** `99.99%`, `50%`, `$100.00` → organic data (`47.2%`, `$99`)
- **Placeholder company names:** "Acme Corp", "Nexus", "SmartFlow" → contextual, believable
  names
- **AI copywriting clichés:** "Elevate", "Seamless", "Unleash", "Next-Gen", "Game-changer",
  "Delve", "Tapestry", "In the world of…" → plain, specific language
- **Lorem Ipsum** → real draft copy. Lorem hides bad copy decisions.
- **Exclamation marks in success messages** → be confident, not loud
- **"Oops!" error messages** → direct: "Connection failed. Please try again."
- **Title Case On Every Header** → sentence case for most; reserve Title Case for primary CTAs
  and pricing tier names
- **Identical blog post dates** → randomize plausibly
- **Same avatar image for multiple users** → unique assets per person
- **Passive voice in errors** → active: "We couldn't save your changes" not "Mistakes were made"

---

## UX Anti-Patterns

These actively harm users.

- **Confirmshaming.** "No thanks, I hate saving money."
- **Pre-selected options** that benefit the company over the user.
- **Cancellation flow harder than signup.**
- **Fake urgency/scarcity indicators.**
- **Infinite scroll without pagination option.** Breaks back button + keyboard nav.
- **Disabled submit buttons before user attempts submission.** Show validation errors after they
  try, not before.
- **Placeholder text as the only label.** Disappears on focus, confuses screen readers.
- **No empty states.** Empty dashboard is wasted onboarding. See `03-component-patterns.md` →
  Empty States.
- **No error states.** Inline messages required. Never `window.alert()`.
- **Generic circular spinners.** Use skeleton loaders matching the layout shape. See
  `03-component-patterns.md` → Loading States.
- **Dead links / `href="#"`.** Either link to a real destination or disable the element.
- **No indication of current page in navigation.** Active state must be visually distinct.

---

## Technical Anti-Patterns

Code-level failures that are easy to spot in review.
**Implementation rules live in `04-implementation-build.md`** — items below cross-reference it.

- **`outline: none`** without `:focus-visible` replacement. See `04` → Anti-Patterns in
  Implementation.
- **`<div onClick>`** instead of `<button>`. Same for `<span onClick>`.
- **Dynamic Tailwind classes** (`bg-${color}-500`). Use object maps. See `04` → Never Use Dynamic
  Class Names.
- **Animating layout properties** (`width`, `height`, `margin`, `padding`, `top`, `left`). Use
  `transform` and `opacity`. See `07a-emil-craft.md` → Performance Rules.
- **Reading layout properties in render loops** (`getBoundingClientRect` in render). Batch
  reads.
- **Missing `alt` text on images.** Never leave `alt=""` or `alt="image"` on meaningful images.
- **Forms without `<label>`.** Even one missing label fails the form.
- **`h-screen`** for full-height sections. Use `min-h-[100dvh]`. See `04` → Viewport Height.
- **Complex flexbox percentage math.** Use Grid. See `04` → Grid over Flex Math.
- **Arbitrary z-index values** like `z-[9999]`. Establish a z scale. See `04` → Z-Index
  Discipline.
- **Commented-out dead code.** Remove before merging.
- **Import hallucinations.** Verify every import exists in `package.json`. See `04` →
  Dependency Verification.
- **Missing meta tags** (`<title>`, `description`, `og:image`).
- **`transition: all`.** Specify exact properties: `transition: transform 200ms ease-out`. See
  `07a-emil-craft.md`.
- **`user-scalable=no`** or `maximum-scale=1` (disables zoom).
- **`onPaste` + `preventDefault`** on text inputs.
- **Inline `onClick` navigation** without `<a>`.
- **Images without explicit `width`/`height`.** Causes layout shift.
- **Large arrays `.map()` without virtualization.** Slow render past 50 items.
- **Icon buttons without `aria-label`.**
- **Hardcoded date/number formats** instead of `Intl.*`.
- **`autoFocus` without justification.** Avoid on mobile.

---

## Mobile Anti-Patterns

Canonical sizing rules: `02-pixel-perfect-standards.md` → Touch Targets and Responsive Precision.

| Anti-pattern                                              | Fix                                                        |
| --------------------------------------------------------- | ---------------------------------------------------------- |
| Touch target < 44×44 px                                   | Extend hit area via padding (visual size can stay smaller) |
| Body text < 16 px on mobile                               | 16 px minimum to avoid iOS auto-zoom on focus              |
| Horizontal scrolling on content                           | Use `overflow-x: clip` on the root and audit child widths  |
| No tap feedback (> 100 ms)                                | Add `touch-action: manipulation`; `:active` scale feedback |
| Fixed-position elements blocking thumb zone               | Move actions to thumb-reachable bottom band                |
| Asymmetric desktop layouts without single-column fallback | Restructure (don't shrink) at the `md` breakpoint          |

---

## Strategic Omissions

What AI forgets — these show up as gaps, not as bugs.

- **No legal links** (privacy policy, terms of service).
- **No back navigation.** Dead ends in user flows.
- **No custom 404 page.**
- **No form validation.** Client-side validation for emails, required fields, format checks.
- **No "skip to content" link.** Essential for keyboard users.
- **No cookie consent** (where required by jurisdiction).
- **No `prefers-reduced-motion` handling.** See `07-motion-framework.md` for the universal
  pattern.
- **No favicon.**

---

## Composition Anti-Patterns

- **Generic card look** (border + shadow + white background). Remove the border, or use
  background-only, or use spacing-only. Cards exist when elevation communicates hierarchy.
- **Always one filled + one ghost button.** Add text links or tertiary styles to reduce noise.
- **Pill-shaped "New" and "Beta" badges everywhere.** Try square badges, flags, or plain text.
- **Accordion FAQ as the only pattern.** Try side-by-side list, searchable help, or inline
  progressive disclosure.
- **3-card carousel testimonials with dots.** Replace with masonry wall, embedded social posts,
  or a single rotating quote with photo.
- **Modals for everything.** Use inline editing, slide-over panels, or expandable sections for
  simple actions.
- **Avatar circles exclusively.** Try squircles or rounded squares.
- **Light/dark sun/moon toggle.** Use a 3-state segmented control or system-preference
  detection.
- **Footer link farm with 4 columns.** Simplify to main paths + legally required links.

---

## Code Quality Anti-Patterns

- **Div soup.** Use semantic HTML: `<nav>`, `<main>`, `<article>`, `<aside>`, `<section>`.
- **Inline styles mixed with CSS classes.** Move all styling to the project's system.
- **Hardcoded pixel widths.** Use relative units (`%`, `rem`, `em`, `max-width`).
- **Missing alt text on meaningful images.**
- **Commented-out dead code in PRs.**
- **`{count} {count === 1 ? '' : 's'}`** for pluralization. Use ICU messages (Arabic etc. break
  English plural).

---

## Quick-Reject Checklist for Code Review

When the diff includes any of these, reject and ask for the fix. For the full code review
structure see `10-review-protocol.md`.

| Pattern                            | Find by                                    | Fix                                                  |
| ---------------------------------- | ------------------------------------------ | ---------------------------------------------------- |
| `outline: none` (no replacement)   | grep `outline-none\|outline: none`         | Add `focus-visible:ring-2` or equivalent             |
| `<div onClick>` / `<span onClick>` | grep `<div[^>]*onClick\|<span[^>]*onClick` | Convert to `<button>`                                |
| `transition: all`                  | grep `transition: all\|transition-all`     | Specify properties                                   |
| `h-screen` on full layout          | grep `h-screen`                            | `min-h-[100dvh]`                                     |
| `bg-${...}` dynamic class          | grep `\\$\\{[a-z]+\\}-[0-9]`               | Object map                                           |
| `z-[\d{4,}]`                       | grep `z-\\[[0-9]{4,}\\]`                   | Z-scale token                                        |
| Missing `alt`                      | grep `<img[^>]*>` without `alt=`           | Add alt or `aria-hidden`                             |
| `<input>` without label            | inspect each form                          | `<label htmlFor>` or wrapping label                  |
| `transform: scale(0)` entry        | grep `scale\\(0\\)`                        | `scale(0.95) opacity:0` (see `07a-emil-craft.md`)    |
| `ease-in` on UI element            | grep `ease-in[^-]`                         | `ease-out` or custom curve (see `07a-emil-craft.md`) |
| `user-scalable=no`                 | grep `user-scalable`                       | Remove                                               |
| Hardcoded English in JSX           | grep for capitalized literal strings       | Wrap in `t()`                                        |

For the deep Vercel-style code compliance pass (typography characters, autocomplete, hydration,
touch action, Intl, safe areas, etc.) invoke the `/web-design-guidelines` skill alongside this
catalog. Merge findings in the structure defined by `10-review-protocol.md`.
