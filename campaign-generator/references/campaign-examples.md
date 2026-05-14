# Campaign Examples Reference

These are real campaign outputs produced by this pipeline for PostBuzz and Hey Alara.

---

## Example 1: PostBuzz — "After Hours" Campaign

**Product**: PostBuzz — AI-native social media command center for agencies
**Audience**: Agency creative directors, heads of social
**Style**: dark-corporate
**Colors**: Electric Coral `#FF6B6B` / gradient `#FF6B6B → #FF8E53`
**Fonts**: Plus Jakarta Sans (display), Inter (body), JetBrains Mono (data)
**Format**: Instagram (1080x1350)

### Post Sequence

| #   | Slug            | Overline         | Headline                                                        | Body                                                         | CTA |
| --- | --------------- | ---------------- | --------------------------------------------------------------- | ------------------------------------------------------------ | --- |
| 1   | nine-pm         | 9:47 PM          | Your posts are live.<br>Your reports are sent.<br>It's 9:47 PM. | When operations run themselves, your evening is yours again. | —   |
| 2   | tuesday-morning | TUESDAY, 8:12 AM | Your client deck<br>was built overnight.<br>You just woke up.   | PostBuzz assembles performance reports while you sleep.      | —   |
| 3   | saturday        | SATURDAY         | Your competitor<br>is still copying data<br>into spreadsheets.  | You automated that 6 months ago.                             | —   |
| 4   | the-bath        | —                | The best ideas<br>don't happen at a desk.                       | When your operations are handled, you can think again.       | —   |

### Image Prompts (abbreviated)

- **nine-pm**: Cinematic nighttime cityscape through apartment window, warm interior glow, laptop closed on desk, city lights bokeh
- **tuesday-morning**: Morning light through blinds onto an empty desk, coffee steam, clean workspace, golden hour warmth
- **saturday**: Overhead view of cluttered desk with spreadsheets and sticky notes, harsh fluorescent, stressed energy
- **the-bath**: Serene bathtub scene, steam, soft warm light, phone face-down on bath edge, relaxation

### HTML Overlay Pattern

```html
<!-- PostBuzz uses a simpler top-bar + bottom-content layout -->
<div class="top-bar">
  <span class="wordmark">PostBuzz</span>
  <!-- text wordmark, no logo image -->
  <span class="tag">After Hours</span>
  <!-- series name in pill -->
</div>
<div class="coral-line"></div>
<!-- brand accent stripe -->

<div class="content">
  <!-- absolutely positioned at bottom -->
  <div class="overline">9:47 PM</div>
  <div class="headline">Your posts are live.<br />...</div>
  <div class="body-copy">When operations run themselves...</div>
  <div class="bottom-bar">
    <span class="url">postbuzz.ai</span>
    <span class="post-num">1 of 4</span>
  </div>
</div>
```

---

## Example 2: Hey Alara — "Always On" Campaign

**Product**: Hey Alara — AI fund simulation platform with 8 specialized agents
**Audience**: Thesis-driven hedge fund managers ($10M-$500M AUM)
**Style**: dark-corporate
**Colors**: Indigo `#6366F1` / Emerald `#10B981` / gradient `#6366F1 → #10B981`
**Fonts**: Space Grotesk (display), Inter (body), JetBrains Mono (data)
**Format**: Instagram (1080x1350)
**Logo**: PNG logo image composited in top-right

### Post Sequence

| #   | Slug      | Time Stamp | Headline                                                           | Data Line                                      | Body                                                     | CTA              |
| --- | --------- | ---------- | ------------------------------------------------------------------ | ---------------------------------------------- | -------------------------------------------------------- | ---------------- |
| 1   | dawn      | 5:47 AM    | You were sleeping.<br><em>Your portfolio wasn't.</em>              | Overnight rebalance complete. NAV +0.3%        | 8 agents ran risk analysis while you slept.              | Meet Your Team   |
| 2   | rain      | 11:23 PM   | Markets moved.<br><em>So did your agents.</em>                     | VIX spike +18%. Portfolio hedged in 4.2s       | You were offline. They weren't.                          | See It Live      |
| 3   | altitude  | 35,000 FT  | You're at cruising altitude.<br><em>Your team isn't cruising.</em> | 3 thesis backtests completed mid-flight        | Somewhere over the Atlantic, 8 agents earned their keep. | Start Simulating |
| 4   | redscreen | 3:47 AM    | Red screens.<br><em>Green portfolio.</em>                          | Drawdown contained to -0.8%. Auto-hedge fired  | The market panicked. Your agents didn't.                 | Build Your Team  |
| 5   | empty     | SUNDAY     | The office is empty.<br><em>The simulation isn't.</em>             | Weekend run: 12 scenarios, 847 trades analyzed | Monday's meeting is already prepared.                    | Meet Your Team   |
| 6   | sunday    | 6:00 AM    | Sunday morning.<br><em>Monday's edge.</em>                         | Pre-market analysis: 3 new signals identified  | While others recover, your agents prepare.               | Start Early      |

### HTML Overlay Pattern

```html
<!-- Hey Alara uses logo image + richer data elements -->
<div class="top-bar">
  <!-- flex-direction: row-reverse -->
  <div class="logo-area"><img src="../logo.png" /></div>
  <!-- logo image top-right -->
  <div class="tag">01 / 06</div>
  <!-- numbered series tag -->
</div>
<div class="spacer"></div>
<!-- flex: 1 pushes copy to bottom -->

<div class="copy-zone">
  <div class="time-stamp">5:47 AM</div>
  <!-- large gradient mono text -->
  <div class="accent-line"></div>
  <!-- brand gradient bar -->
  <div class="headline">
    You were sleeping.<br /><em>Your portfolio wasn't.</em>
  </div>
  <div class="data-line">
    <span class="dot"></span>Overnight rebalance complete. NAV +0.3%
  </div>
  <div class="body-copy">8 agents ran risk analysis while you slept.</div>
  <div class="bottom-row">
    <div class="cta">Meet Your Team</div>
    <!-- solid white button -->
    <div class="url">heyalara.com</div>
  </div>
</div>
```

### Key Differences from PostBuzz

| Element           | PostBuzz                    | Hey Alara                                                 |
| ----------------- | --------------------------- | --------------------------------------------------------- |
| Brand mark        | Text wordmark               | Logo PNG image                                            |
| Accent element    | Coral stripe below top bar  | Gradient accent line above headline                       |
| Unique element    | —                           | Time stamp (large gradient mono) + Data line (dot + stat) |
| Headline gradient | Not used                    | `<em>` tags get gradient text                             |
| CTA               | None (awareness campaign)   | Solid white button                                        |
| Series label      | Campaign name text          | Numbered "01 / 06" format                                 |
| Bottom layout     | URL left, post number right | CTA right, URL left (row-reverse)                         |

---

## Example 3: Hey Alara — "Terminal" Campaign (No Background Image)

Some campaigns use pure HTML/CSS design without a raw background image:

```html
<!-- No .bg-image div — pure dark canvas with styled content -->
<body style="background: #0A0E1A">
  <div class="canvas">
    <div class="content">
      <!-- Styled terminal/code blocks, agent tiles, data visualizations -->
      <!-- All done with CSS — no raw image needed -->
    </div>
  </div>
</body>
```

This pattern works for:

- Terminal/code aesthetic campaigns
- Data-heavy posts with tables/grids
- Meeting/conversation mockup posts
- Pure typographic posts
