---
name: campaign-generator
description: "End-to-end social media campaign generator. Takes a product name/description, builds a brand kit, generates campaign concepts, creates raw images via Segmind API, composites branded overlays via HTML+Playwright, and outputs production-ready posts in PNG+WebP. Invoke when the user asks to create a social media campaign, generate branded posts, build campaign visuals, or produce marketing assets for a product."
---

# Campaign Generator

You are a **full-stack campaign production engine** that takes a product from concept to production-ready social media posts. You combine brand strategy, creative direction, AI image generation, and design compositing into a single automated pipeline.

## Pipeline Overview

```
INPUT: Product name + description (+ optional brand kit, logo, colors)
  |
  v
STAGE 1: Brand Kit Generation (or ingestion if provided)
  |
  v
STAGE 2: Campaign Concept (series name, 4-6 posts, headlines, copy)
  |
  v
STAGE 3: Raw Image Generation (Segmind PrunaP API via t5-image-prompts)
  |
  v
STAGE 4: HTML Overlay Compositing (branded post templates)
  |
  v
STAGE 5: Playwright Screenshot + WebP Conversion
  |
  v
OUTPUT: Campaign folder with raw/, html/, final PNGs + WebPs
```

---

## Required Arguments

When invoked, gather (or infer) these from the user:

| Argument                | Required | Description                                                                                                                  |
| ----------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **product_name**        | Yes      | The product/brand name exactly as it should appear                                                                           |
| **product_description** | Yes      | 1-3 sentence description of what the product does                                                                            |
| **target_audience**     | Yes      | Who the posts are for (infer from description if not given)                                                                  |
| **campaign_theme**      | No       | A theme/angle for the campaign (auto-generate if not given)                                                                  |
| **post_count**          | No       | Number of posts in the series (default: 4)                                                                                   |
| **post_format**         | No       | Dimensions: `instagram` (1080x1350), `linkedin` (1200x627), `twitter` (1600x900), `square` (1080x1080). Default: `instagram` |
| **brand_colors**        | No       | Primary + accent hex colors (auto-generate if not given)                                                                     |
| **brand_fonts**         | No       | Font stack (default: Space Grotesk + Inter + JetBrains Mono)                                                                 |
| **logo_path**           | No       | Path to logo file for compositing (omit brand mark if not given)                                                             |
| **output_dir**          | No       | Output directory (default: `generated-images/{product-slug}/campaigns/{campaign-slug}`)                                      |
| **style**               | No       | Visual mood: `dark-corporate`, `editorial-moody`, `clean-minimal`, `bold-startup`, `luxury-dark` (default: `dark-corporate`) |

---

## Stage 1: Brand Context

If the user provides a BRAND-KIT.md or equivalent, read and internalize it. Extract:

- Product name + capitalization rules
- Color system (surface palette + signal palette + gradients)
- Typography stack (display, body, data/mono fonts)
- Brand voice rules
- Target audience
- Brand URL / domain

If no brand kit exists, generate a minimal brand context from the product description:

```markdown
## Quick Brand Context

- **Name**: {product_name}
- **Domain**: {inferred or asked}
- **Primary Color**: {hex} — used for accent elements, CTAs
- **Surface Dark**: {hex} — page background (always near-black for dark campaigns)
- **Surface Card**: {hex} — cards, panels (slightly lighter)
- **Border**: {hex} — subtle dividers
- **Text Primary**: #F1F5F9
- **Text Secondary**: rgba(241,245,249,0.45)
- **Text Muted**: rgba(241,245,249,0.20)
- **Gradient**: linear-gradient(135deg, {primary}, {secondary})
- **Display Font**: {font} (Google Fonts)
- **Body Font**: Inter
- **Mono Font**: JetBrains Mono
- **Voice**: {2-3 rules}
```

---

## Stage 2: Campaign Concept

Generate a campaign concept document with:

1. **Series Name** — A punchy 1-3 word campaign name (e.g., "After Hours", "The Shift", "Always On")
2. **Campaign Angle** — The emotional/strategic hook in one sentence
3. **Post Sequence** — For each post:
   - **Slug** (filename-safe)
   - **Overline** — Small caps label (time, stat, or category)
   - **Headline** — 2-3 lines, max 10 words per line. Use `<br>` for line breaks. One key phrase gets gradient treatment via `<em>` tag
   - **Body copy** — One sentence, max 15 words, understated
   - **CTA text** — 2-3 words, uppercase
   - **Image prompt brief** — What the background image should depict (mood, subject, setting)

### Campaign Style Rules

- Headlines use **light weight** display font (300) — elegant, not shouty
- One phrase per headline gets **gradient color** treatment (the key value prop)
- Body copy is always low-opacity (0.35-0.45) — supporting, not competing
- Every post has a numbered tag (e.g., "01 / 04") for series consistency
- Monospace elements (overlines, URLs, tags) use JetBrains Mono at small sizes
- The brand URL sits bottom-left, almost invisible (opacity 0.18-0.20)

---

## Stage 3: Raw Image Generation

For each post, generate a background image using the t5-image-prompts skill's `generate.sh` script:

```bash
SCRIPT="$HOME/.claude/skills/t5-image-prompts/scripts/generate.sh"

"$SCRIPT" \
  --prompt "{T5 prompt}" \
  --output "{output_dir}/raw-{slug}.png" \
  --aspect-ratio {aspect_ratio}
```

### Image Prompt Guidelines

The raw images serve as **backgrounds beneath text overlays**. They must:

1. **Have visual weight in the top half** — the bottom 40% gets crushed by gradient overlay for text
2. **No text, logos, or UI elements** in the raw image — those come from the HTML layer
3. **Mood-first, not literal** — atmospheric scenes that evoke the campaign theme
4. **Muted/dark tonality** preferred — the image shouldn't fight the overlay text
5. Use the t5-image-prompts skill's prompt engineering principles: describe physics, not feelings

### Aspect Ratios by Format

| Format    | Raw Image AR | HTML Canvas Size |
| --------- | ------------ | ---------------- |
| instagram | 3:4          | 1080 x 1350      |
| linkedin  | 16:9         | 1200 x 627       |
| twitter   | 16:9         | 1600 x 900       |
| square    | 1:1          | 1080 x 1080      |

---

## Stage 4: HTML Overlay Compositing

For each post, generate an HTML file that composites the raw image with branded typography.

### Template Structure

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      @import url('https://fonts.googleapis.com/css2?family={DisplayFont}:wght@300;400;500;700&family=Inter:wght@300;400;500&family=JetBrains+Mono:wght@300;400;500&display=swap');
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { width: {width}px; height: {height}px; overflow: hidden; background: {surface_dark}; }

      .canvas { width: {width}px; height: {height}px; position: relative; }

      .bg-image {
        position: absolute; inset: 0;
        background: url('../raw-{slug}.png') center top / cover no-repeat;
      }

      .gradient-overlay {
        position: absolute; inset: 0;
        background: linear-gradient(
          to bottom,
          rgba({r},{g},{b},0.15) 0%,
          rgba({r},{g},{b},0.05) 20%,
          rgba({r},{g},{b},0.35) 48%,
          rgba({r},{g},{b},0.88) 62%,
          {surface_dark} 74%
        );
      }

      .content {
        position: absolute; inset: 0;
        display: flex; flex-direction: column;
        padding: 48px 64px 56px;
      }

      /* ... brand-specific styles ... */
    </style>
  </head>
  <body>
    <div class="canvas">
      <div class="bg-image"></div>
      <div class="gradient-overlay"></div>
      <div class="content">
        <!-- top bar: logo/wordmark + series tag -->
        <!-- spacer -->
        <!-- copy zone: overline, headline, body, bottom row (CTA + URL) -->
      </div>
    </div>
  </body>
</html>
```

### Gradient Overlay Formula

The gradient overlay is critical — it makes text readable over any background image:

- **Top 20%**: Nearly transparent (0.05-0.15) — let the image breathe
- **Middle 48%**: Transition zone, start darkening (0.35)
- **62%**: Heavy darken (0.88) — text zone begins
- **74%+**: Solid background color — pure readability

Adjust these stops based on where the headline sits. The copy zone must always have solid or near-solid backing.

### Typography Sizing by Format

| Element          | Instagram (1080w) | LinkedIn (1200w) | Twitter (1600w) |
| ---------------- | ----------------- | ---------------- | --------------- |
| Display headline | 56-66px           | 40-48px          | 48-56px         |
| Body copy        | 22-24px           | 16-18px          | 18-22px         |
| Overline/mono    | 14-16px           | 11-13px          | 13-15px         |
| Tag/URL          | 14px              | 11px             | 12px            |

---

## Stage 5: Screenshot + Conversion

### Screenshot Script (Playwright)

Generate a `screenshot.mjs` file for the campaign:

```javascript
import { chromium } from "playwright";

const pages = [
  { html: "{slug}-overlay.html", out: "{slug}-final.png" },
  // ... one entry per post
];

const browser = await chromium.launch();

for (const { html, out } of pages) {
  const ctx = await browser.newContext({
    viewport: { width: { width }, height: { height } },
    deviceScaleFactor: 2,
  });
  const page = await ctx.newPage();
  await page.goto(`file://${process.cwd()}/html/${html}`, {
    waitUntil: "load",
    timeout: 15000,
  });
  await page.waitForTimeout(4000); // wait for Google Fonts
  await page.screenshot({ path: out, fullPage: false });
  console.log(`Captured: ${out}`);
  await ctx.close();
}

await browser.close();
console.log("All done.");
```

**Important**: The `deviceScaleFactor: 2` produces @2x resolution output (e.g., 2160x2700 for Instagram).

### WebP Conversion

After screenshots, convert each final PNG to WebP:

```bash
POST_PROCESS="$HOME/.claude/skills/t5-image-prompts/scripts/post-process.sh"

"$POST_PROCESS" --input "{slug}-final.png" --action convert --format webp --quality 85 --output "{slug}-final.webp"
```

If `post-process.sh` is unavailable, fall back to ImageMagick:

```bash
magick "{slug}-final.png" -quality 85 "{slug}-final.webp"
```

---

## Output Directory Structure

```
{output_dir}/
  raw-{slug1}.png         # Raw AI-generated background
  raw-{slug2}.png
  ...
  html/
    {slug1}-overlay.html  # Branded HTML composite
    {slug2}-overlay.html
    ...
  screenshot.mjs          # Playwright capture script
  {slug1}-final.png       # Final composited post (@2x)
  {slug1}-final.webp      # WebP version
  {slug2}-final.png
  {slug2}-final.webp
  ...
  logo.png                # Logo copy (if provided)
```

---

## Execution Flow

When the user invokes this skill:

1. **Gather arguments** — product name, description, audience. Infer or ask for anything missing.
2. **Check for existing brand kit** — look for BRAND-KIT.md in the product's generated-images folder, or ask if one exists.
3. **Generate campaign concept** — series name, post sequence with headlines/copy/image briefs.
4. **Show the concept to the user** — let them approve or adjust before generating images (images cost API credits).
5. **Generate raw images** — one per post via `generate.sh`. Run sequentially (API rate limits).
6. **Generate HTML overlays** — one per post, using the brand's design system.
7. **Run Playwright screenshots** — serve HTML locally, capture at 2x.
8. **Convert to WebP** — production-ready output.
9. **Display results** — show the final composited posts to the user.

### Error Handling

- If `generate.sh` fails: check SEGMIND_API_KEY, retry once, then report.
- If Playwright fails: ensure `npx playwright` works, check Chrome installation.
- If fonts don't load: the 4000ms `waitForTimeout` in screenshot.mjs handles this. If still broken, increase to 6000ms.
- If WebP conversion fails: check ImageMagick installation (`magick` or `convert`).

---

## Style Presets

### dark-corporate (default)

- Surface: `#0B0F1A` / `#141926` / `#1C2230`
- Gradient: bottom-heavy, 62% solid
- Headlines: Light weight (300), white
- Accent: Via brand primary color

### editorial-moody

- Surface: `#0A0A0A` / `#111111` / `#1A1A1A`
- Gradient: Earlier fade, 55% solid — more image visible
- Headlines: Light weight (300), slightly warm white `#F5F0EB`
- Accent: Muted, desaturated tones

### clean-minimal

- Surface: `#FFFFFF` / `#F8F9FA` / `#E9ECEF`
- Gradient: Top-down white fade over image
- Headlines: Medium weight (500), dark `#1A1A2E`
- Accent: Single bold color

### bold-startup

- Surface: `#0B0F1A` / `#141926`
- Gradient: Aggressive — 50% solid, punchy
- Headlines: Bold (700), large, short
- Accent: Vivid, saturated, gradient text

### luxury-dark

- Surface: `#0C0C0C` / `#161616` / `#1E1E1E`
- Gradient: Slow elegant fade, 70% solid
- Headlines: Light (300), generous tracking (+0.05em)
- Accent: Gold `#C9A96E` or silver `#B8C0CC`

---

## Dependencies

- **Segmind API key** — for raw image generation (via t5-image-prompts skill)
- **Playwright** — for HTML-to-PNG screenshot (`npx playwright`)
- **ImageMagick** — for WebP conversion (`magick` or `convert`)
- **Google Fonts** — loaded via CSS @import in HTML templates (requires internet)
