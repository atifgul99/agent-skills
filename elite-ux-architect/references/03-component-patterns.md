# 03 — Component and Pattern Standards

How specific UI patterns must behave. **Canonical home** for form, table, modal,
notification, navigation, empty/loading/error state, and layout primitive behaviors.

> **See also**
>
> - For underlying spacing/typography/motion-timing values → `02-pixel-perfect-standards.md`
> - For implementation (Tailwind, CVA, viewport) → `04-implementation-build.md`
> - For dashboard-specific empty states and toast timing → `05-page-patterns.md`
> - For polish on the patterns (button press feedback, popover origins, tooltips) → `07a-emil-craft.md`

---

## Forms

- Labels **above** inputs. Never floating labels — they fail accessibility and usability at
  scale.
- Required fields visually indicated (asterisk or "required" text), not by color alone.
- Inline validation **on blur**, not while typing.
- Error messages below the field with `role="alert"`.
- Success state on submission.
- Submit button **disabled during request** with spinner — but enabled before user attempts
  submission. Don't preemptively disable.
- Logical tab order. Never `tabindex > 0`.
- Long forms use sections with clear headers.
- Single column layout — 120% fewer errors than multi-column. Mobile-friendly by default.
- Minimize fields. Every additional field reduces conversion. Phone field alone drops conversion
  ~58% — only ask if essential.

**Input attributes:**

- Use semantic `type` (`email`, `tel`, `url`, `number`) and `inputmode`
- Use `autocomplete` with meaningful `name` attributes — let password managers and browser
  autofill work
- Disable spellcheck on emails, codes, usernames (`spellcheck="false"`)
- Use `autocomplete="off"` on non-auth fields where password managers would interfere
- Placeholders end with `…` and show example patterns (not labels)
- Block `onPaste` with `preventDefault` is an anti-pattern — let users paste
- Labels must be clickable via `htmlFor` or by wrapping the input
- Checkboxes and radios: label and control share a single hit target

**Submission:**

- Warn before navigation when there are unsaved changes
- Display errors inline and focus the first error on submit
- `autoFocus` sparingly — desktop only, single primary input, avoid on mobile

---

## Data Tables

- Sortable columns with visual indicator (chevron or arrow)
- Sticky column headers on scroll
- Row hover state
- Bulk selection with select-all
- Pagination with page size selector
- Empty state when filters return zero
- Loading skeleton matches table structure
- Mobile: horizontal scroll with frozen first column, or card-based stacked layout
- Large lists (>50 items) should virtualize using a library like `virtua` or `react-virtual`,
  or use `content-visibility: auto`
- Numeric columns use `font-variant-numeric: tabular-nums`

---

## Modals and Dialogs

- Focus trapped inside
- Close on Escape
- Close button always visible
- Backdrop click closes non-destructive dialogs; doesn't close destructive ones
- Title + description + actions
- Destructive actions right-aligned, primary visually dominant
- Never nest modals — use sheets or drill-in
- Modals keep `transform-origin: center` (unlike popovers, which scale from trigger — see
  Notifications/Tooltips below and `07a-emil-craft.md`)
- Use `overscroll-behavior: contain` to prevent body scrolling when modal scrolls

---

## Notifications, Toasts, and Tooltips

- Toast for transient confirmations — auto-dismiss 4–5 seconds (minimum 6s for accessibility)
- Toast duration formula: `500 ms × word count + 3 s base`
- Toast stack: max 3 visible, newest on top
- Inline alerts for persistent messages
- Action toasts (with undo) persist until dismissed
- Error toasts persist until dismissed
- Never toast for errors requiring user action — use inline alerts
- Always include a dismiss button
- No exclamation marks in success messages — be confident, not loud

**Tooltips:**

- First tooltip: delayed + animated
- Subsequent tooltips in the same toolbar: instant (skip delay + skip animation)
- This pattern makes the whole toolbar feel fast without defeating the initial delay

---

## Navigation

- Active state clearly distinct from hover
- Breadcrumbs for depth > 2; add `scroll-margin-top` to heading anchors
- Mobile: bottom nav for primary actions, sheet for full menu
- Sidebar collapse state persists across sessions
- Navigation never causes full page reload
- Hierarchical heading structure `<h1>`–`<h6>`; include skip-to-content link for keyboard users

**Pattern by hierarchy:**

| Scenario       | Pattern             |
| -------------- | ------------------- |
| 10+ sections   | Collapsible sidebar |
| 3–6 sections   | Top navigation      |
| Secondary nav  | Tabs (max 6)        |
| Deep hierarchy | Breadcrumbs         |

URL must reflect state: filters, tabs, pagination, expanded panels. Deep-link all stateful UI
(`nuqs` is a good helper in Next.js).

---

## Empty States

Icon + headline + description + primary CTA.

The CTA is the most important element — it tells the user what to do next. Optional secondary
action for learning more. Empty states are onboarding surfaces, not dead ends.

Contextual: dashboard empty state differs from filtered-list empty state.

```jsx
// Good
<EmptyState
  icon={<InboxIcon />}
  title="No messages yet"
  description="When you receive messages, they'll appear here."
  action={<Button>Compose message</Button>}
/>

// Bad
<p>No data</p>
```

---

## Loading States

- Skeleton screens **match content dimensions exactly** — wrong dimensions cause layout shift,
  which is worse than no skeleton
- Skeleton pulse: 1.5 s duration
- Spinners only for inline actions (button submissions, fetches), never for page-level loading
- Page-level loading: skeleton. Inline: spinner.
- Progressive: show what you have, stream the rest via Suspense
- Loading text ends with `…`: "Loading…"
- A fast-spinning spinner makes the app feel like it loads faster, even when the load time is
  identical — perceived performance matters

```jsx
// Skeleton over spinner
<div className="animate-pulse">
  <div className="h-4 bg-muted rounded w-3/4 mb-2" />
  <div className="h-4 bg-muted rounded w-1/2" />
</div>
```

---

## Error States

- User-friendly message. Never expose technical details, stack traces, or error codes
- Include the fix or next step in every error message
- Recovery action (retry, go back, contact support)
- Illustration for full-page errors; inline for field-level
- Error boundaries at route level to prevent full-app crashes
- Log the real error server-side; show a human message client-side
- "Oops!" is wrong. Be direct: "Connection failed. Please try again."
- Use active voice: "We couldn't save your changes" not "Mistakes were made"

---

## Buttons

- Active/pressed feedback: `transform: scale(0.97)` on `:active` for instant tactile feedback
- Transition `transform 160 ms ease-out` (only `transform`, never `all`)
- Visible focus state via `:focus-visible` (not `:focus`)
- Hover state with consistent transition (150–200 ms)
- Disabled state ≥ 40% opacity, `cursor-not-allowed`
- Icon button: minimum 36 px hit area with `aria-label`
- Button copy: action verbs, first-person ("Get my free trial" > "Sign up"), 2–5 words max
- Specific labels: "Save API Key" not "Continue"
- Title Case for primary actions; sentence case for secondary
- Use `<button>` for actions, `<a>`/`<Link>` for navigation — never `<div onClick>` or
  `<span onClick>`

---

## Settings Pages

- Bucket + side panel layout for complex settings
- Group destructive actions in a "Danger Zone" at bottom
- Destructive confirmations require typing the resource name and use specific button labels
  ("Delete account" not "Yes")
- Describe the exact consequence of destructive actions

---

## Pricing Tables

- 3–4 tiers maximum (more causes paralysis)
- Highlight recommended tier with color + emphasis, not just extra height
- Annual/monthly toggle with savings shown
- Checkmarks for quick feature scanning
- CTA button on every tier
- Tiers must align horizontally — same start position for feature lists, same vertical position
  for CTA buttons

---

## Layout Primitives

Five structural components enforce the spacing scale through the type system. At 50+ pages they
eliminate drift that tokens alone cannot prevent — tokens exist but a developer can still write
`space-y-5`. Primitives make invalid spacing impossible.

- **Stack** — Vertical spacing between children. `spacing` prop mapped to the 4 px scale.
  Replaces raw `space-y-*`. Page sections, form fields, list items, card bodies.
- **Inline** — Horizontal layout with `gap`, `align`, `justify` props. Replaces raw
  `flex items-center gap-*`. Header rows, icon+text, tag groups, toolbars, breadcrumbs, action
  buttons.
- **Grid** — Responsive grid with named `preset` prop (stats, cards, detail, images, form) or
  custom `cols` + `gap`. Replaces raw `grid grid-cols-*`. Card grids, stat grids, detail
  layouts, media galleries.
- **Box** — Padding container with scale-locked `padding` prop. Replaces raw `p-*` on container
  divs. Card bodies, section wraps, dialog content, sidebar panels.
- **Center** — Center content on both axes with optional `minHeight`. Replaces raw
  `flex items-center justify-center`. Empty states, loading states, auth pages, error pages.

All primitives are thin wrappers (~15–25 lines each): className mapping, `as` prop for semantic
HTML, ref forwarding, no internal state, no side effects. Zero runtime overhead.

**Prohibited in domain components:** raw `space-y-*`, `flex items-center gap-*`,
`grid grid-cols-*`, layout `p-*`.

---

## Content Handling

Every text container handles the full range:

- Short text: don't break layout
- Average text: render cleanly
- Long text: truncate with `truncate`, `line-clamp-*`, or `break-words`
- Flex children that contain text need `min-w-0` to allow truncation
- Empty data: render an empty state, not broken UI

Use `text-wrap: balance` on headings to prevent orphans. Use `text-wrap: pretty` on body for
better line breaks.
