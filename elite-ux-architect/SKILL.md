---
name: elite-ux-architect
description: "Principal UX architect for any frontend or product UI work. Use when the user asks to build, review, audit, redesign, polish, or modernize a component, page, dashboard, landing page, modal, form, or layout — or to check spacing, typography, color, motion, accessibility, or AI-generated 'tells'. Also triggers on phrasings like 'make this look better', 'the design feels off', 'fix the styling', 'audit my dashboard', 'review this component'. Covers persona, pixel-perfect standards, component patterns, Tailwind/React implementation, motion design (Emil Kowalski / Jakub Krehel / Jhey Tompkins), redesign workflow, anti-patterns catalog, and code review protocol. Use proactively on frontend work. Pair with a project-specific skill (e.g. postbuzz_ux_architect) for competitive context."
---

# Elite UX Architect

A router skill. Standards, patterns, motion frameworks, and review protocols live in
`references/` and load on demand based on the task.

> **Supersedes:** `ux-architect`, `elite-frontend-ux`, `emil-design-eng`,
> `design-motion-principles`, `redesign-existing-projects`, `review-ux`.

---

## Initialization

When invoked without a specific task: introduce capabilities briefly, ask for direction. **Do
not proactively audit, scan files, or assess implementation quality.** Wait for the user.

Before responding to any non-trivial task, read `references/01-persona-and-principles.md`. It
defines the persona, operating principles, hard constraints, and communication style — the
foundation for everything else.

---

## Router — Pick the Right Reference

| Task                                                                                                                      | Load                                       |
| ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| **Persona, operating principles, hard constraints**                                                                       | `references/01-persona-and-principles.md`  |
| Spacing, typography, color, radius, shadows, icons, touch targets, motion-timing tokens, responsive breakpoints           | `references/02-pixel-perfect-standards.md` |
| Forms, tables, modals, navigation, notifications, empty/loading/error states, layout primitives                           | `references/03-component-patterns.md`      |
| Tailwind, `cn()`, CVA, viewport, mobile-first, dark mode, hydration safety, third-party deps, performance building blocks | `references/04-implementation-build.md`    |
| SaaS dashboard architecture, landing-page sections, hero/CTA/pricing/forms                                                | `references/05-page-patterns.md`           |
| Canonical AI-tells catalog (visual, content, UX, technical, mobile, code quality) — **what to flag in reviews**           | `references/06-anti-patterns.md`           |
| Motion audit framework — which designer perspective applies (Emil / Jakub / Jhey)                                         | `references/07-motion-framework.md`        |
| Emil Kowalski — restraint, speed, springs, clip-path, gestures, Sonner principles                                         | `references/07a-emil-craft.md`             |
| Jakub Krehel — production polish, subtle enter/exit, shadows, optical alignment                                           | `references/07b-jakub-polish.md`           |
| Jhey Tompkins — playful CSS, `linear()`, `@property`, scroll-driven, 3D, CSS art                                          | `references/07c-jhey-experimental.md`      |
| Redesigning existing UI — Scan → Diagnose → Fix workflow, upgrade techniques, fix priority                                | `references/08-redesign-audit.md`          |
| Anti-slop layout patterns, Bento 2.0 dashboard paradigm, design intensity calibration                                     | `references/09-creative-arsenal.md`        |
| Code review **structure** — Critical/Important/Opportunities buckets, output format, severity                             | `references/10-review-protocol.md`         |
| Vercel Web Interface Guidelines compliance — typography characters, autocomplete, hydration, touch, Intl, safe areas      | `references/11-vercel-compliance.md`       |

---

## Standard Workflows

| Workflow                       | Mandatory                | Add when needed                                                                                                                                                                    |
| ------------------------------ | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Build a component**          | `01` + `04`              | `03` for the pattern, `02` for spacing/color values                                                                                                                                |
| **Build a page or dashboard**  | `01` + `04` + `05`       | `03` for component-level patterns, `09` for distinctive aesthetic                                                                                                                  |
| **Polish interactions**        | `01` + `07`              | `07` routes to the right designer (`07a` / `07b` / `07c`). `02` for timing-token values.                                                                                           |
| **Review code**                | `10` + `06` + `11`       | `03` only when reviewing forms/modals/tables/states. `04` only when reviewing Tailwind/CVA/hydration/perf. `02` only when flagging visual specifics (spacing, color, type values). |
| **Audit a motion / animation** | `07` (routes by context) | Whichever designer reference `07` weights for the project                                                                                                                          |
| **Redesign existing UI**       | `08` (Scan→Diagnose→Fix) | `06` for what to flag during Diagnose, `04` + `02` for the Fix pass                                                                                                                |

**Load lazily.** Don't preload everything in the "Add when needed" column. Pull a file only
when the task actually asks the question that file answers.

---

## Pair With Project Context

This skill is reusable across products. For project-specific competitive intelligence, tech
stack constraints, and routing to project-only utility skills (design tokens, RTL, performance
audit), the calling agent must also load the project's thin UX skill (e.g.
`postbuzz_ux_architect`). The project skill provides the "why this matters here" frame; this
skill provides the standards and craft.
