# 09 — Creative Arsenal: Anti-Slop Patterns and Bento 2.0

Named patterns to replace generic AI defaults. Use these when "make it distinctive" is part of
the brief or when redesigning generic interfaces. Always verify library availability before
use.

> **See also**
>
> - For what to REPLACE these generic defaults with — the catalog of generic patterns is in `06-anti-patterns.md`
> - For the redesign workflow that uses these as upgrades → `08-redesign-audit.md` → Upgrade Techniques
> - For motion patterns inside these creative arsenal moves → `07a-emil-craft.md` (springs, clip-path) and `07c-jhey-experimental.md` (linear(), @property)

---

## Design Intensity Calibration

Set these before coding so the rest of the work has a consistent personality:

- **`DESIGN_VARIANCE` 1–10:** 1 = perfect symmetry, 10 = artsy chaos. Default: 8 for marketing,
  4 for product UI.
- **`MOTION_INTENSITY` 1–10:** 1 = static CSS only, 10 = cinematic spring physics. Default: 6
  for marketing, 3 for SaaS.
- **`VISUAL_DENSITY` 1–10:** 1 = art gallery airy, 10 = cockpit packed data. Default: 4 for
  SaaS app, 2 for landing.

At density 8+, box cards are banned — use `border-t` / `divide-y` / negative space instead.

---

## Aesthetic Direction Library

Choose and commit to one. Timid design fails. Options:

- **Brutally minimal** (Stripe, Linear)
- **Maximalist editorial** (Bloomberg, Awwwards winners)
- **Retro-futuristic** (Y2K revival, vaporwave)
- **Organic / natural** (earthy, hand-drawn, textured)
- **Luxury / refined** (fashion houses, premium brands)
- **Playful / toy-like** (Figma, Notion)
- **Neo-brutalist** (raw, exposed, intentionally rough)
- **Art deco / geometric** (bold shapes, gold accents)
- **Soft / pastel** (gradient meshes, dreamy)
- **Industrial / utilitarian** (data-dense, functional)

**The memorability test:** what ONE thing will users remember? If you can't answer, the design
lacks focus.

---

## Navigation Patterns

- **Mac OS Dock magnification** — items grow under cursor
- **Magnetic buttons** (Framer `useMotionValue`) — buttons drift slightly toward the cursor
- **Dynamic Island pill** — collapsible status surface
- **Contextual radial menu** — actions arc out from cursor
- **Mega menu with staggered reveal** — multi-column expanding nav

---

## Layout Patterns

- **Bento grid** — asymmetric tiles (see Bento 2.0 section below)
- **Masonry layout** — variable heights, packed efficiently
- **Split-screen scroll** — halves move opposite directions
- **Broken grid** — elements deliberately overlap/bleed off-screen
- **Parallax card stacks** — sticky elements that stack on scroll

---

## Card Patterns

- **Parallax tilt card** — 3D mouse tracking on card surface
- **Spotlight border** — border illuminates under cursor
- **True glassmorphism** — `backdrop-filter: blur` + 1 px `border-white/10` inner border +
  inner shadow (not just blur — that alone looks fake)
- **Holographic foil** — iridescent gradient on hover
- **Morphing modal** — button expands into the dialog

---

## Scroll Patterns

- **Horizontal scroll hijack** — vertical scroll becomes horizontal in a section
- **Zoom parallax** — background zooms in/out with scroll
- **Scroll progress SVG path draw** — line draws along the path as user scrolls
- **Locomotive scroll sequence** — video framerate tied to scroll position
- **Curtain reveal** — hero parts like a curtain on scroll

---

## Typography Patterns

- **Kinetic marquee** — reverses direction on scroll
- **Text mask reveal** — typography as a window to video or animated imagery
- **Text scramble** — Matrix-style decode on hover
- **Gradient stroke animation** — gradient runs along the text stroke outline
- **Variable font animation** — interpolate weight or width on scroll/hover

---

## Micro-Interactions

- **Particle explosion button** — CTA shatters into particles on success
- **Directional hover-aware button** — fill enters from the direction the mouse approached
- **Ripple from click coordinates** — Material-style ripple originating from the click point
- **Mesh gradient background** — animated lava-lamp blobs
- **Skeleton shimmer** — light reflection moving across the placeholder
- **Spring-physics drag** — items move with weight on drag

---

## Performance Notes for Creative Patterns

- Use **Framer Motion** for UI / Bento / micro-interactions
- Use **GSAP** or **Three.js** exclusively for full-page scroll-telling or canvas backgrounds —
  never mix them in the same component tree
- Grain / noise overlays: apply only to `fixed pointer-events-none` pseudo-elements, never to
  scrolling containers (GPU repaint cost)
- Perpetual animations must be isolated in their own `"use client"` leaf component to prevent
  parent re-renders

---

## Bento 2.0 Dashboard Paradigm

For SaaS dashboards and feature sections, use this architecture instead of generic card grids.

### Aesthetic baseline

- Page: `bg-[#f9fafb]`
- Cards: pure white (`bg-white border border-slate-200/50`)
- Containers: `rounded-[2.5rem]`
- Shadows: diffusion (`shadow-[0_20px_40px_-15px_rgba(0,0,0,0.05)]`)
- Padding: `p-8` or `p-10`
- Labels: **outside and below** cards, not inside

### Typography

Geist, Satoshi, or Cabinet Grotesk only. `tracking-tight` for headers.

### The 5 card archetypes (with perpetual motion)

1. **Intelligent List** — infinite auto-sort loop using Framer `layoutId`. Items swap positions
   simulating AI prioritization.
2. **Command Input** — AI search bar cycling through prompts via typewriter effect with blinking
   cursor and shimmer loading state.
3. **Live Status** — scheduling view with "breathing" status dots. Notification badge appears
   with overshoot spring (`stiffness: 400, damping: 10`), stays 3 s, vanishes.
4. **Wide Data Stream** — seamless horizontal carousel (`x: ["0%", "-100%"]`) of metrics at
   effortless speed.
5. **Focus Mode** — document view with staggered text highlight, then float-in action toolbar.

### Motion rules for all cards

- Spring physics only: `type: "spring", stiffness: 100, damping: 20`
- Every card has an infinite loop state (pulse, typewriter, float, or carousel) so the
  dashboard feels alive
- Wrap dynamic lists in `<AnimatePresence>`
- Perpetual animations: `React.memo` + isolated Client Component — never trigger parent
  re-renders
- Use `layout` and `layoutId` for smooth re-ordering and shared element transitions

---

## Decision Helper: Which Pattern to Pick

| Brief                           | Suggested patterns                                                 |
| ------------------------------- | ------------------------------------------------------------------ |
| "Make the dashboard feel alive" | Bento 2.0 + Live Status + Wide Data Stream                         |
| "Hero feels generic"            | Split-screen scroll + Variable font animation, or Text mask reveal |
| "Features section is boring"    | Bento grid (asymmetric tiles), or zig-zag rows                     |
| "CTA needs more weight"         | Particle explosion or Magnetic button                              |
| "Onboarding needs delight"      | Skeleton shimmer + staggered entry + Spring-physics drag           |
| "Pricing feels samey"           | Holographic foil on recommended tier, color emphasis (not extra    |
| height)                         |

---

## What to Avoid (Even When Going Creative)

- **More than one signature pattern per page.** Pick one memorable thing. The rest supports it.
- **Animations on high-frequency interactions** (covered in `07-motion-framework.md`).
- **Decoration without purpose.** Every creative pattern must serve workflow, brand, or
  comprehension — never "it looks cool".
- **Library conflicts.** GSAP + Framer Motion + Three.js in one tree = janky and bloated.
  Pick the right one for the job.
