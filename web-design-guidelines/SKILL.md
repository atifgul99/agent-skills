---
name: web-design-guidelines
description: "Vercel's Web Interface Guidelines compliance checker. Fetches the latest 80+ code-level rules and emits file:line violations. Use when reviewing existing frontend code for: typography characters (… vs ..., curly quotes, &nbsp; in measurements), form attributes (autocomplete, semantic type, inputmode, spellcheck, htmlFor), hydration safety (controlled value + onChange, SSR/client mismatch, suppressHydrationWarning), touch behavior (touch-action, overscroll-behavior, inert, -webkit-tap-highlight-color), animation rules (transform/opacity only, transform-origin, no transition:all), accessibility (aria-label, focus-visible, semantic HTML, scroll-margin-top), URL state management (deep-linking filters/tabs/pagination), Intl APIs (DateTimeFormat, NumberFormat, translate=no), safe areas (env(safe-area-inset-*)), dark mode (color-scheme, theme-color), performance (preconnect, font preload, virtualization, content-visibility), or content handling (truncate, line-clamp, min-w-0, text-wrap: balance). Invoke alongside elite-ux-architect's review-protocol for comprehensive code review — this tool catches code-level violations, elite-ux-architect catches design/UX violations. Output is terse file:line format. Not a general UX or design audit."
risk: safe
source: community
date_added: '2026-02-27'
---

# Web Interface Guidelines

Review files for compliance with Web Interface Guidelines.

## How It Works

1. Fetch the latest guidelines from the source URL below
2. Read the specified files (or prompt user for files/pattern)
3. Check against all rules in the fetched guidelines
4. Output findings in the terse `file:line` format

## Guidelines Source

Fetch fresh guidelines before each review:

```
https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md
```

Use WebFetch to retrieve the latest rules. The fetched content contains all the rules and output format instructions.

## Usage

When a user provides a file or pattern argument:

1. Fetch guidelines from the source URL above
2. Read the specified files
3. Apply all rules from the fetched guidelines
4. Output findings using the format specified in the guidelines

If no files specified, ask the user which files to review.

## When to Use

This skill is applicable to execute the workflow or actions described in the overview.

## Limitations

- Use this skill only when the task clearly matches the scope described above.
- Do not treat the output as a substitute for environment-specific validation, testing, or expert review.
- Stop and ask for clarification if required inputs, permissions, safety boundaries, or success criteria are missing.
