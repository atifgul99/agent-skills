---
name: brand-voice-ultimate
description: "Complete brand voice system — analyze, extract, build, and enforce brand voice. Combines URL-based brand analysis, personal voice extraction, build-from-scratch questionnaire, competitor comparison, consistency auditing, messaging hierarchy, and AI content cleanup. Use when creating brand voice guidelines, extracting voice from content, building voice from scratch, auditing brand consistency, comparing voice to competitors, or enforcing voice in AI-generated content."
version: "1.0.0"
---

# Brand Voice Ultimate

Complete brand voice system. Analyze an existing brand, extract voice from content, build one from scratch, compare against competitors, and enforce it in everything you produce.

---

## Mode

Detect from context or ask:

| Mode | What you get | Best for |
|------|-------------|----------|
| `analyze` | Full brand analysis from URL — dimensions, archetype, competitor comparison, consistency audit, messaging hierarchy | Brands with existing web presence |
| `extract` | Voice profile extracted from writing samples — phrases, confidence zones, rhythm, anti-patterns | Founders, thought leaders, personal brands with existing content |
| `build` | Voice profile constructed from scratch via questionnaire — identity, audience, positioning, aspiration | New brands, rebrand, or no existing content to analyze |
| `full` | All three: analyze brand presence + extract founder voice + build/refine profile + messaging + enforcement | Complete brand voice system from the ground up |

**Default: detect from context.** If the user provides a URL, start with `analyze`. If they provide writing samples, start with `extract`. If they say "from scratch" or have nothing yet, use `build`. If unclear, ask.

---

## Phase 0: Foundation — Product & Market Context

Before voice work, establish the strategic context that voice depends on. Skip sections the user has already documented.

**Check first:** Does `.agents/product-marketing-context.md` or `.claude/product-marketing-context.md` exist? If yes, load it and skip to Phase 1.

**If no context exists, gather the essentials:**

### 0A. Product Core
- One-line description
- What it does (2-3 sentences)
- Product category (what "shelf" — how customers search for you)
- Business model and pricing

### 0B. Customer Language
This is the most valuable input for voice work. Push for verbatim quotes.
- How customers describe the problem (their exact words)
- How they describe the solution (their exact words)
- Words/phrases to use (customer language)
- Words/phrases to avoid (internal jargon customers don't use)

### 0C. Competitive Landscape
- 2-3 direct competitors
- How each positions themselves
- Where they fall short for customers

### 0D. Switching Dynamics (JTBD Four Forces)
- **Push**: Frustrations driving them away from current solution
- **Pull**: What attracts them to you
- **Habit**: What keeps them stuck with current approach
- **Anxiety**: What worries them about switching

**Save to:** `.agents/product-marketing-context.md` if it doesn't exist. This context improves every subsequent phase.

---

## Phase 1: Brand Voice Analysis (from URL/content)

*Skip if mode is `build` with no existing presence.*

### 1A. Source Material Gathering

Analyze content from multiple channels. Prioritize in this order:

**Primary (must analyze):**
1. Homepage — most curated brand representation
2. About page — how the brand describes itself
3. Product/service pages — how they present offerings

**Secondary (if available):**
4. Blog posts (3-5 recent)
5. Social media profiles (bio, recent posts, engagement style)
6. Email newsletters (welcome email, recent sends)
7. Customer-facing copy (error messages, onboarding, help docs)

**Tertiary:**
8. Job postings (reveals internal culture)
9. Ad copy (paid messaging approach)
10. Video/podcast transcripts (spoken voice)

### 1B. Voice Dimension Scoring

Map the brand along four dimensions. Each is a spectrum scored 1-10. **Quote 3-5 specific examples as evidence for each rating.**

#### Formal (1) <-----> Casual (10)
| Signal | Formal | Casual |
|---|---|---|
| Contractions | Avoids ("do not", "cannot") | Uses freely ("don't", "can't") |
| Sentence structure | Complex, longer | Short, punchy |
| Vocabulary | Professional, industry-standard | Conversational, everyday |
| Pronouns | Third person ("the company", "one") | First/second person ("we", "you") |
| Humor | Rare or absent | Frequent, natural |

#### Serious (1) <-----> Playful (10)
| Signal | Serious | Playful |
|---|---|---|
| Tone | Authoritative, measured | Light-hearted, fun |
| Metaphors | Rare, conservative | Creative, unexpected |
| Exclamation marks | Rare | Frequent |
| Wordplay/puns | Never | Enjoys them |
| Error messages | "An error has occurred" | "Oops! Something went sideways" |

#### Technical (1) <-----> Simple (10)
| Signal | Technical | Simple |
|---|---|---|
| Jargon | Uses freely | Avoids or explains all |
| Acronyms | Uses without definition | Spells out on first use |
| Detail level | In-depth explanations | High-level overviews |
| Data/statistics | Frequent, detailed | Occasional, simplified |

#### Reserved (1) <-----> Bold (10)
| Signal | Reserved | Bold |
|---|---|---|
| Claims | Hedged ("we believe", "may help") | Direct ("we guarantee", "the best") |
| Opinions | Neutral, balanced | Strong, opinionated |
| Competitive references | Avoids mentioning competitors | Directly compares |
| Promises | Conservative | Ambitious |

### 1C. Brand Personality Archetype

Map to one primary and optional secondary archetype:

**The Authority** — Expert, trustworthy, data-driven. "Research shows...", "Our experts..."
Examples: McKinsey, IBM, Mayo Clinic

**The Innovator** — Forward-thinking, disruptive, visionary. "Reimagine...", "The future of..."
Examples: Tesla, Stripe, Notion

**The Friend** — Warm, approachable, helpful. "We get it...", "You've got this..."
Examples: Mailchimp, Slack, Duolingo

**The Rebel** — Bold, challenging conventions. "Stop settling for...", "The truth is..."
Examples: Nike, Oatly, Cards Against Humanity

**The Guide** — Wise, patient, methodical. "Here's how to...", "Step by step..."
Examples: HubSpot, Khan Academy, Ahrefs

### 1D. Tone-by-Context Mapping

Map how tone shifts across contexts (voice stays consistent, tone adapts):

| Context | Typical Tone | Evidence |
|---|---|---|
| Homepage | [Confident/Welcoming/Urgent/etc.] | "[quote]" |
| Product pages | [Informative/Persuasive/Technical/etc.] | "[quote]" |
| Blog | [Educational/Conversational/Authoritative/etc.] | "[quote]" |
| Social media | [Casual/Engaging/Promotional/etc.] | "[quote]" |
| Email | [Direct/Personal/Nurturing/etc.] | "[quote]" |
| Error/404 pages | [Apologetic/Humorous/Helpful/etc.] | "[quote]" |
| CTA buttons | [Action-oriented/Benefit-driven/Urgent/etc.] | "[quote]" |

### 1E. Competitor Voice Comparison

Compare against 2-3 competitors from Phase 0:

| Dimension | Your Brand | Competitor 1 | Competitor 2 | Competitor 3 |
|---|---|---|---|---|
| Formal ↔ Casual | X/10 | X/10 | X/10 | X/10 |
| Serious ↔ Playful | X/10 | X/10 | X/10 | X/10 |
| Technical ↔ Simple | X/10 | X/10 | X/10 | X/10 |
| Reserved ↔ Bold | X/10 | X/10 | X/10 | X/10 |
| Primary Archetype | [type] | [type] | [type] | [type] |

**Differentiation assessment:**
- How distinct is your voice from competitors?
- Where do voices overlap? (differentiation opportunity)
- What voice territory is unoccupied?

### 1F. Consistency Audit

Assess voice consistency across all analyzed channels:

| Channel | Consistency | Issues Found |
|---|---|---|
| Homepage | Strong / Moderate / Weak | [specifics] |
| Blog | Strong / Moderate / Weak | [specifics] |
| Social | Strong / Moderate / Weak | [specifics] |
| Email | Strong / Moderate / Weak | [specifics] |
| Product pages | Strong / Moderate / Weak | [specifics] |

**Overall Consistency Score: X/10**

Common issues to flag:
- Different writers creating noticeably different tones
- Social voice drastically different from website
- Old pages not updated to match current voice
- Microcopy (errors, tooltips) that feels off-brand

---

## Phase 2: Voice Extraction (from writing samples)

*Skip if mode is `build` with no existing content.*

### 2A. Sample Collection & Assessment

**Collect writing samples.** Minimum: 3 samples OR 500 total words.

**Sample priority (most → least authentic):**
1. Casual Slack or email (raw, unedited voice)
2. Podcast or call transcript
3. LinkedIn posts or articles
4. Website copy (often edited, less authentic)

**If samples < 500 words, stop:**
> "These samples are too short for reliable extraction. Add 2-3 more — emails, Slack messages, or transcripts work best. The messier and more casual, the better."

**Assess before extracting:**
1. **Authenticity** — Are samples from raw or polished contexts?
2. **Variety** — Do they cover different contexts?
3. **Exclusions** — Flag patterns that are NOT authentic voice:
   - Platform formatting tics (LinkedIn line breaks, Twitter brevity)
   - Typos and autocorrect errors
   - Phrases borrowed from others
4. **Corporate voice detection** — If passive voice >30%, no personal opinions, heavy hedging throughout, flag: "These may reflect committee-written voice. For best results, share something you wrote quickly and unfiltered."

Output assessment:
> "I have [X samples / Y words]. Quality: [high/medium — why]. Excluding: [patterns and why]."

### 2B. Core Energy

**Role** — Which communication mode dominates:
- Teacher (breaks things down systematically)
- Challenger (pushes back on assumptions)
- Cheerleader (builds confidence and momentum)
- Straight-shooter (cuts through BS efficiently)

**Default energy:**
- Calm authority ("Here's what works.")
- High enthusiasm ("This is exciting — let me show you.")
- Understated confidence ("I've seen this a hundred times.")

**Recurring themes** — Topics that appear unprompted across samples. These reveal what the person actually cares about.

### 2C. Signature Phrase Extraction

Scan all samples and extract verbatim:

**Transition phrases** (how they shift topics):
- Quote exact examples with source
- Pattern: "Here's the thing...", "What I've learned...", "Let me put it differently..."

**Emphasis phrases** (how they land a point):
- Quote exact examples
- Pattern: "The reality is...", "This is the part people miss..."

**Closers** (how they wrap up):
- Quote exact examples
- Pattern: "That's the move.", "Start there.", "You've got this."

### 2D. Confidence Zone Mapping

| Zone | Topics | Language Markers |
|---|---|---|
| Full authority | [topics they're expert in] | No hedging, definitive statements, "here's what works" |
| Earned perspective | [topics with experience] | "In my experience...", "What I've found..." |
| Active exploration | [topics they're learning] | "I'm testing this...", "What I'm seeing..." |

This calibration makes voice feel real vs. one-dimensional. An authentic voice hedges on some topics and speaks with full authority on others.

### 2E. Rhythm & Structure Analysis

- Average words per sentence (count across all samples)
- Sentence length variance (flag if >40% cluster at same length — monotone rhythm)
- Fragment use frequency
- Paragraph length patterns
- List frequency and style
- Mix of short/punchy vs. longer/flowing

### 2F. Anti-Patterns

Extract what they'd NEVER say:
- Words that would feel wrong in their voice
- Phrases that make them cringe
- Tones they naturally avoid
- Industry jargon they hate

Source from evidence: "You never used [word] across [X samples] — it doesn't fit your voice."

---

## Phase 3: Build from Scratch (questionnaire)

*Use when no existing content to analyze. Also use to supplement/refine after Phase 1 or 2.*

### Identity (who you are)
1. What are 3-5 words that describe your personality?
2. What do you stand for? What's your core belief about your industry?
3. What's your background? What shaped how you see things?
4. What makes you genuinely different from others in your space?

### Audience (who you're talking to)
5. Who are you talking to? (Be specific — not "entrepreneurs")
6. What tone resonates with them? What do they respond to?
7. What would make them trust you? What would turn them off?

### Positioning (how you show up)
8. Are you the expert, the peer, the rebel, the guide, the insider?
9. Where do you sit on accessible ↔ exclusive?
10. Where do you sit on approachable ↔ authoritative?

### Aspiration (what you want to sound like)
11. Name 2-3 people or brands whose voice you admire. What specifically about their voice?
12. What do you NOT want to sound like?
13. Any signature words or phrases that feel like "you"?
14. Any words you hate or want to avoid?
15. How do you feel about humor? Profanity? Hot takes?

**Do not dump all 15 questions at once.** Walk through conversationally, one section at a time. Confirm answers before moving on.

---

## Phase 4: Messaging Hierarchy

Build the messaging stack from most compressed to most expanded:

### Level 1: Tagline (under 10 words)
Most compressed form of brand message.
- Current tagline (if exists) or draft one
- Assessment: Does it capture the core value proposition?

### Level 2: Value Propositions (1 sentence each)
3-5 core value propositions supporting the brand promise.

### Level 3: Elevator Pitch (30 seconds / 75 words)
Conversational explanation of what the brand does and why it matters.

### Level 4: Boilerplate (100-150 words)
Standard "about us" paragraph for press, email signatures, speaker bios.

### Level 5: Full Brand Story (300-500 words)
Complete narrative of who the brand is, what they stand for, why they exist.

---

## Phase 5: Validation & Enforcement

### 5A. Validation Test (Required)

Generate 2 test sentences on the same topic:

**Version A** (using the extracted voice):
> "[Sample sentence in the brand voice]"

**Version B** (wrong voice — contrasting example):
> "[Same content, different voice]"

Ask: "Does Version A sound like you? What feels off?"

### 5B. Copy Samples in Voice

Generate 8 samples demonstrating the voice across contexts:
1. Homepage headline
2. Product description paragraph
3. Blog post opening
4. Social media post
5. Email subject line
6. CTA button text
7. Error message
8. Customer thank-you message

### 5C. AI Content Quality Gate

Built-in enforcement checklist. Run against any content produced using this voice profile.

**AI patterns to detect and remove (47 patterns across 5 categories):**

**Overused transitions (14):** "Moreover", "Furthermore", "Additionally", "Nevertheless", excessive "However" (>2 per 500 words), "While X, Y" openings (>3 per page), "In conclusion"

**AI cliches (18):** "In today's fast-paced world", "Let's dive deep", "Unlock your potential", "Harness the power of", "It's no secret that", "The key takeaway is", "Game-changer", "Paradigm shift"

**Hedging language (8):** "It's important to note", "It's worth mentioning", "One might argue", vague quantifiers ("various", "numerous", "myriad", "plethora"), "Arguably" overuse

**Corporate buzzwords (12):** "utilize" → "use", "facilitate" → "help", "optimize" → "improve", "leverage" → "use", "synergize" → "work together", "ideate" → "brainstorm"

**Robotic patterns (9):** Rhetorical questions immediately answered, obsessive parallel structures, always exactly three bullet points, announcement of emphasis ("Importantly", "Crucially"), list prefacing ("Here are the top X ways...")

**Human voice markers to add:**
- Varied sentence rhythm (mix 5-10 word and 20-30 word sentences)
- Conversational connectors ("So,", "But here's the thing,", "And yet")
- Direct statements (replace "It could be argued that X is Y" with "X is Y")
- Specific examples (replace "many companies" with named examples)
- Contractions in casual content
- Active voice
- Confident assertions (remove hedging unless genuinely uncertain)

**Scoring (0-10 human-ness scale):**
- 0-3: Obviously AI-generated
- 4-5: AI-heavy, needs major work
- 6-7: Mixed, lacks strong voice
- 8-9: Human-like, minimal AI patterns
- 10: Indistinguishable from skilled human writer

**Target: 8+ for any public content.**

### 5D. Self-Critique (Required)

After generating the complete voice profile:
- [ ] Are extracted phrases actually from the samples, or inferred?
- [ ] Does the anti-pattern list include specific words/phrases, not just vague categories?
- [ ] Do validation sentences demonstrate a real difference between in-voice and out-of-voice?
- [ ] Is confidence zone mapping specific to named topics, not generic?
- [ ] Would a new writer be able to use this guide without asking follow-up questions?
- [ ] Is every voice dimension rating backed by quoted evidence?
- [ ] Does the competitor comparison use real data, not assumptions?

Flag gaps: "The anti-pattern section only has 2 entries — need more samples or direct input."

---

## Output: BRAND-VOICE.md

Save to project root as `BRAND-VOICE.md`.

```markdown
# Brand Voice Guide
## [Brand Name]
### Generated: [Date]

---

## Voice Summary
[2-3 sentences. What does this voice FEEL like to encounter?]

---

## Product & Market Context
**One-liner:** [from Phase 0]
**Customer language:** [verbatim quotes — how they describe the problem and solution]
**Competitive position:** [where you sit vs competitors]

---

## Voice Dimensions

### Visual Voice Map
```
Formal                                    Casual
|----[X]----------------------------------|
Serious                                   Playful
|--------[X]------------------------------|
Technical                                 Simple
|------------------[X]--------------------|
Reserved                                  Bold
|------------[X]--------------------------|
```

### Formal ↔ Casual: [X/10]
[Evidence and explanation with quoted examples]

### Serious ↔ Playful: [X/10]
[Evidence and explanation with quoted examples]

### Technical ↔ Simple: [X/10]
[Evidence and explanation with quoted examples]

### Reserved ↔ Bold: [X/10]
[Evidence and explanation with quoted examples]

---

## Brand Personality
- **Primary archetype:** [which + why]
- **Secondary archetype:** [if applicable]
- **Core energy:** [calm authority / high enthusiasm / understated confidence]
- **Role:** [teacher / challenger / cheerleader / straight-shooter]
- **Recurring themes:** [topics that appear unprompted]

---

## Tone by Context
| Context | Tone | Example |
|---|---|---|
| Homepage | [tone] | "[quote]" |
| Product pages | [tone] | "[quote]" |
| Blog | [tone] | "[quote]" |
| Social media | [tone] | "[quote]" |
| Email | [tone] | "[quote]" |
| Error/support | [tone] | "[quote]" |
| CTAs | [tone] | "[quote]" |

---

## Signature Phrases
**Transitions:**
- "[Phrase]" (source: [context])

**Emphasis:**
- "[Phrase]" (source: [context])

**Closers:**
- "[Phrase]" (source: [context])

---

## Confidence Calibration
**Full authority (no hedging):**
Topics: [list]
Sounds like: "[example sentence]"

**Earned perspective:**
Topics: [list]
Sounds like: "[example sentence]"

**Active exploration:**
Topics: [list]
Sounds like: "[example sentence]"

---

## Vocabulary

### Words We Use
**Action words:** [verbs]
**Descriptive words:** [adjectives]
**Value words:** [words reflecting values]
**Customer language:** [their exact words]

### Words We Kill
- [word/phrase] — why: [evidence]
- [word/phrase] — why: [evidence]

### Jargon Level
[Heavy / Light / Translated — and how to handle domain terms]

---

## Voice Chart
| Our Voice IS | Our Voice IS NOT |
|---|---|
| [trait] | [anti-trait] |
| [trait] | [anti-trait] |
| [trait] | [anti-trait] |
| [trait] | [anti-trait] |

---

## Writing Guidelines

### Do's
- [specific guideline with example]
- [specific guideline with example]
- [specific guideline with example]
- [specific guideline with example]
- [specific guideline with example]

### Don'ts
- [specific anti-pattern with example]
- [specific anti-pattern with example]
- [specific anti-pattern with example]
- [specific anti-pattern with example]
- [specific anti-pattern with example]

---

## Rhythm & Structure
**Sentences:** [avg length, variance, fragment use]
**Paragraphs:** [length, whitespace patterns]
**Openings:** [story? question? bold claim?]
**Closers:** [CTA? summary? open loop?]
**Formatting:** [headers, bullets, whitespace preferences]

---

## Messaging Hierarchy

### Tagline
[under 10 words]

### Value Propositions
1. [value prop]
2. [value prop]
3. [value prop]

### Elevator Pitch (75 words)
[pitch]

### Boilerplate (100-150 words)
[boilerplate]

### Brand Story (300-500 words)
[full narrative]

---

## Competitor Voice Comparison
| Dimension | [Brand] | [Comp 1] | [Comp 2] | [Comp 3] |
|---|---|---|---|---|
| Formal ↔ Casual | X/10 | X/10 | X/10 | X/10 |
| Serious ↔ Playful | X/10 | X/10 | X/10 | X/10 |
| Technical ↔ Simple | X/10 | X/10 | X/10 | X/10 |
| Reserved ↔ Bold | X/10 | X/10 | X/10 | X/10 |
| Archetype | [type] | [type] | [type] | [type] |

**Voice territory unoccupied by competitors:** [opportunity]
**Differentiation recommendations:** [specifics]

---

## Consistency Audit
| Channel | Score | Issues |
|---|---|---|
| [channel] | Strong/Moderate/Weak | [specifics] |

**Overall Consistency: X/10**

---

## Copy Samples in Voice
1. **Homepage headline:** "[sample]"
2. **Product description:** "[sample]"
3. **Blog opening:** "[sample]"
4. **Social post:** "[sample]"
5. **Email subject:** "[sample]"
6. **CTA button:** "[sample]"
7. **Error message:** "[sample]"
8. **Thank-you message:** "[sample]"

---

## Validation
**This sounds like you:**
"[Version A]"

**This doesn't:**
"[Version B — contrast]"

---

## AI Enforcement Rules
When generating content using this voice profile, always:
1. Run the 47-pattern AI detection check
2. Score content on human-ness scale (target: 8+)
3. Apply confidence zone calibration (hedge only where appropriate)
4. Use signature phrases naturally (don't force them)
5. Verify rhythm matches documented patterns

---

## Self-Critique Notes
[Any gaps, things to validate, areas needing more data]

---

## Recommendations
### Immediate Actions
1. [recommendation]

### Voice Evolution Opportunities
1. [recommendation]

### Consistency Improvements
1. [recommendation]

---

## Usage
- **For AI agents:** Load this file as context before any content generation
- **For ghostwriters:** Share on day 1 — cuts revision cycles in half
- **For team:** This is the benchmark for "on brand"
- **To update:** Run this skill again with new samples or answers
```

---

## After Delivery

Always offer next steps:

```
Your brand voice guide is complete. What's next?

A) Test it — Generate 3 sample pieces in this voice to validate
B) Refine it — Tell me what feels off, I'll diagnose which pattern needs adjustment
C) Strengthen it — I'll identify the weakest dimension and deepen it
D) Apply it — Use this voice to write something specific right now
E) Done — Save and reference in future content work
```

---

## Memory Protocol

**Save output to:** `BRAND-VOICE.md` in project root

**At session start:** Check if a prior `BRAND-VOICE.md` exists. If yes:
- Load it into context
- Note this is a refinement session
- Compare new inputs to prior profile — flag if voice has evolved or patterns conflict

**Cross-session rule:** Always load prior voice profile before starting. Do not treat every run as a cold start.

---

## How This Connects to Other Skills

This skill produces a complete `BRAND-VOICE.md` ready for use in any content workflow:

- Voice profile → **copywriting:** "Write landing page copy using this voice"
- Voice profile → **email-sequence:** "Draft this sequence matching my voice"
- Voice profile → **social-content:** "Create posts in this voice"
- Voice profile → **content-strategy:** "Plan content aligned with this voice"
- Voice profile → **de-ai-ify:** "Clean this content to match my voice profile"
- Voice profile → **market-copy:** "Generate copy using this voice"

**The workflow:** Run brand-voice-ultimate first → Save the profile → Reference it in everything.
