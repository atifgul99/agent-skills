# 07 — Motion Audit Framework

Motion design is context-dependent, not universal. The same animation that is correct for a
kids app is wrong for a high-frequency productivity tool. **Canonical home** for the audit
methodology: reconnaissance, motion gap analysis, designer-perspective weighting, and the
universal checklist.

> **See also**
>
> - For motion-timing token values (durations, easing curves) → `02-pixel-perfect-standards.md` → Transitions and Motion Timing
> - For implementation specifics (Framer Motion hardware acceleration, `useReducedMotion`) → `04-implementation-build.md` → Reduced Motion + Performance: Animation under load

This file routes you to the right designer perspective for the project at hand.

For deep dives on each designer's craft, load:

- `07a-emil-craft.md` — Emil Kowalski (restraint, speed, productivity tools)
- `07b-jakub-polish.md` — Jakub Krehel (subtle production polish)
- `07c-jhey-experimental.md` — Jhey Tompkins (playful CSS experimentation)

---

## STEP 1 — Reconnaissance (Do This First)

Before auditing any code, understand the project context. Never apply rules blindly.

**Gather:**

1. **Project type.** Marketing site? SaaS dashboard? Kids app? Mobile PWA? Creative portfolio?
2. **Existing animations.** Grep for `motion`, `animate`, `transition`, `@keyframes`. What
   durations? What patterns?
3. **Existing project rules.** CLAUDE.md, design system docs, brand guidelines.
4. **User base.** Enterprise users repeating high-frequency actions? Casual visitors? Kids?

**Motion gap analysis (critical — don't skip):**

After cataloging existing animations, search for **missing** ones — conditional UI changes that
snap in/out:

```bash
grep -n "&&\s*(" --include="*.tsx" -r .
grep -n "?\s*<" --include="*.tsx" -r .
```

For each conditional render:

- Wrapped in `<AnimatePresence>`? If not, that's a gap.
- Does it have enter/exit animations? If not, gap.
- Snap-in/snap-out modals, panels, mode switches, loading states are all gaps.

---

## STEP 2 — State Your Inference

Before doing the audit, tell the user what you found and propose a weighting:

```
## Reconnaissance Complete

**Project type:** [e.g. "Productivity SaaS, B2B, repeat-use dashboard"]
**Existing animation style:** [e.g. "Spring 200–400 ms, Framer Motion, no scale(0) entries"]
**Likely intent:** [e.g. "Speed and clarity for power users"]

**Motion gaps found:** [N] conditional renders without AnimatePresence
- [list specific files/areas]

**Proposed perspective weighting:**
- Primary: [Designer] — [Why]
- Secondary: [Designer] — [Why]
- Selective: [Designer] — [When applicable]

Does this approach sound right?
```

**WAIT for confirmation** before doing the full audit.

---

## STEP 3 — Context → Perspective Mapping

| Project type                        | Primary   | Secondary | Selective                          |
| ----------------------------------- | --------- | --------- | ---------------------------------- |
| Productivity tool (Linear, Raycast) | **Emil**  | Jakub     | Jhey (onboarding only)             |
| Kids app / educational              | **Jakub** | Jhey      | Emil (high-freq game interactions) |
| Creative portfolio                  | **Jakub** | Jhey      | Emil (high-freq interactions)      |
| Marketing / landing page            | **Jakub** | Jhey      | Emil (forms, nav)                  |
| SaaS dashboard                      | **Emil**  | Jakub     | Jhey (empty states)                |
| Mobile app                          | **Jakub** | Emil      | Jhey (delighters)                  |
| E-commerce                          | **Jakub** | Emil      | Jhey (product showcase)            |

---

## STEP 4 — Audit Output Format

### Summary box (show first)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 AUDIT SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 [X] Critical  |  🟡 [X] Important  |  🟢 [X] Opportunities
Primary perspective: [Designer(s)] ([context reason])
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Overall assessment

One paragraph: does this feel polished? Too much? Too little? What works, what doesn't?

### Per-designer sections

Each weighted designer gets:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ EMIL'S PERSPECTIVE — Restraint & Speed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**What's working well:**
- ✓ [Observation] — `file.tsx:line`

**Issues to address:**
- ✗ [Issue] — `file.tsx:line`
  [Brief explanation]

**Emil would say:** [1–2 sentence summary]
```

Use ⚡ for Emil, 🎯 for Jakub, ✨ for Jhey.

### Combined recommendations

Severity-tagged tables:

```
**Critical (must fix)**
| | Issue | File | Action |
|-|-------|------|--------|
| 🔴 | [issue] | `file:line` | [fix] |

**Important (should fix)**
| | Issue | File | Action |
|-|-------|------|--------|
| 🟡 | [issue] | `file:line` | [fix] |

**Opportunities (could enhance)**
| | Enhancement | Where | Impact |
|-|-------------|-------|--------|
| 🟢 | [idea] | `file:line` | [impact] |
```

### Final designer reference summary

```
> **Who was referenced most:** [Designer]
>
> **Why:** [Explanation based on project context]
>
> **If you want to lean differently:**
> - To follow Emil more strictly: [specific actions]
> - To follow Jakub more strictly: [specific actions]
> - To follow Jhey more strictly: [specific actions]
```

---

## Universal Checklist (Apply Regardless of Designer Weighting)

### Philosophy

- [ ] How often will users trigger this? (Frequent = less/no animation)
- [ ] Is this keyboard-initiated? (If yes, don't animate)
- [ ] Does this serve a purpose? (orientation, feedback, continuity — not decoration)
- [ ] Will users notice it consciously? (If yes in production UI, probably too much)
- [ ] Tested with `prefers-reduced-motion: reduce`?
- [ ] Feels natural after the 10th interaction?
- [ ] Easing appropriate for brand/context?
- [ ] Duration appropriate for context?

### Motion gap analysis

- [ ] Searched for conditional renders without `AnimatePresence`
- [ ] Searched for ternary swaps without transitions
- [ ] Searched for dynamic inline styles without transitions
- [ ] Each conditional render either has AnimatePresence OR doesn't need animation
- [ ] Mode switches (tabs, toggles) animate their content changes
- [ ] Settings panels with conditional controls have enter/exit
- [ ] Expandable sections animate height
- [ ] Loading → content transitions are smooth, not instant swaps

### Enter/exit states

- [ ] Enter combines opacity + translateY + blur
- [ ] Exit subtler than enter (smaller translateY, same blur/opacity)
- [ ] `animation-fill-mode: backwards` used for delayed sequences
- [ ] Elements don't flash before their delayed animation starts

### Easing and timing

- [ ] Appropriate easing for context (not default `ease` everywhere)
- [ ] Custom bezier curves used instead of built-in easing
- [ ] Spring animations for interactive elements
- [ ] Durations appropriate (Emil: < 300 ms; others: whatever serves the design)
- [ ] Consistent timing values across related animations
- [ ] Transform-origin matches the interaction source

### Performance

- [ ] `will-change` used sparingly and specifically
- [ ] Animations use transform/opacity (not layout properties)
- [ ] Tested on low-end devices
- [ ] No continuous animations without purpose
- [ ] CSS transitions (not keyframes) for interruptible animations
- [ ] Direct style updates for drag operations (not CSS variables)
- [ ] Velocity-based thresholds (not distance) for swipe dismiss

### Accessibility

- [ ] Respects `prefers-reduced-motion`
- [ ] No vestibular triggers (excessive zoom, spin, parallax)
- [ ] Looping animations can be paused
- [ ] Functional animations have non-motion alternatives

---

## Severity Levels

**Critical (must fix):**

- Missing `prefers-reduced-motion` support
- Animating layout properties (width, height, top, left)
- No exit animations (elements just disappear)
- Motion gaps in primary UI (conditional controls/panels that snap)
- Animating keyboard-initiated actions
- Animations on high-frequency actions (100s/day)

**Important (should fix):**

- Exit as prominent as enter
- Missing blur in enter animations (productivity context)
- Animating from `scale(0)` instead of `0.9+`
- Default CSS easing instead of custom curves
- Wrong transform-origin on dropdowns/popovers

**Context-dependent (check designer):**

- Durations over 300 ms (Emil flags; Jakub/Jhey may approve)

**Nice to have:**

- Optical alignment refinements
- `oklch` color space for gradients
- Spring animations instead of ease
- Button scale feedback on press
- Tooltip delay pattern (first delayed, subsequent instant)

---

## Universal Reduced-Motion Pattern

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

This effectively disables animation while preserving final states (so layouts don't break).
Functional motion (state indication, spatial continuity) may need an instant alternative; pure
decoration can be fully removed.
