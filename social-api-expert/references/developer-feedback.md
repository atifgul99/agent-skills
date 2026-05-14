# Developer Feedback & Pain Points

Real complaints from developers building with social media APIs. Sourced from GitHub issues,
Stack Overflow, Reddit r/webdev, Hacker News, G2 reviews, and Product Hunt discussions.

**IMPORTANT:** This file captures patterns observed through March 2026. For current sentiment,
always use WebSearch to check recent discussions. Developer priorities shift.

## Top 8 Pain Points (Ranked by Frequency)

### 1. "Why did my post fail?" (Error opacity)

**The problem:** Generic error messages with no platform-specific context.

- "Error: Request failed" — no platform name, no error code, no guidance
- Developers must guess which platform failed and why
- Support tickets are the only debugging path

**What developers want:**

```json
{
  "platform": "instagram",
  "error_code": "MEDIA_NOT_READY",
  "error_subcode": 2207050,
  "classification": "retry",
  "retryable": true,
  "message": "Media container is still processing. The system will retry automatically.",
  "platform_message": "Media is not ready for publishing"
}
```

**Our advantage:** social-core has the deepest error classification in the market.
4-way classification with platform-specific error maps (33 Instagram subcodes, 53 Reddit codes, 25 YouTube/TikTok codes, etc. — 200+ total).
No competitor exposes this level of detail.

**2026 update:** Meta now returns 200 OK with empty data `{"data": []}` for some accounts (works for app admins but not users) — a silent failure with no error message. X's March 2026 anti-LLM-spam update breaks legitimate apps with generic errors and no advance warning.

**Sources:** Ayrshare GitHub issues, Stack Overflow `[twitter-api-v2]` / `[instagram-graph-api]` tags, Reddit r/webdev.

---

### 2. "Which platform failed?" (No per-platform status)

**The problem:** Flat success/error response for multi-platform publishes.

```json
// What developers get from most APIs:
{ "status": "error", "message": "Some platforms failed" }

// What they need:
{
  "status": "partial",
  "platforms": [
    { "platform": "twitter", "status": "published", "post_url": "..." },
    { "platform": "instagram", "status": "processing" },
    { "platform": "linkedin", "status": "failed", "error": { ... } }
  ]
}
```

**Market leader:** Postproxy includes per-platform status in EVERY response. This is now
expected by developers who've used it.

---

### 3. "I need different text per platform" (Content forcing)

**The problem:** Most APIs take a single `post` string and send it everywhere.
Twitter's 280 chars vs LinkedIn's 3000 vs Instagram's hashtag culture require different text.

**What developers want:**

```json
{
  "text": "Default text for all platforms",
  "platforms": ["twitter", "linkedin", "instagram"],
  "overrides": {
    "twitter": { "text": "Short version for Twitter" },
    "linkedin": { "text": "Professional long-form version..." },
    "instagram": { "text": "Caption with #hashtags #social" }
  }
}
```

**Market reference:** Mixpost's `PostVersion` model is the best pattern — per-platform
content variations linked to the same post. Ayrshare does this with per-platform option
objects but inconsistently named.

---

### 4. "OAuth is a nightmare" (Connection complexity)

**The problem:** Developers hate:

- Being redirected to the API provider's domain during OAuth
- Not knowing when tokens will expire
- Handling reconnection without clear lifecycle events
- Meta's shared app complexity (Facebook + Instagram + Threads = 1 app)
- Reddit's 1-hour tokens requiring constant refresh
- Instagram Basic Display API was EOL'd December 4, 2024 — breaking existing integrations
- 7 different auth flows needed for 7 platforms (Nango: "Why is OAuth still hard in 2026?")

**What developers want:**

- Headless OAuth: "Give me the URL, I'll handle the UI" (Zernio pattern)
- Token lifecycle webhooks: `token.expiring`, `token.expired`, `token.refreshed`
- Account health endpoint: token validity, scope coverage, rate limit status
- Clear docs on which platforms share OAuth apps

---

### 5. "Can I check before publishing?" (No validation)

**The problem:** Only way to find out content is invalid is to try publishing and fail.
Text too long, wrong aspect ratio, missing required field — all discovered at publish time.

**What developers want:**

```
POST /posts/validate
{ same body as POST /posts }

Response:
{
  "valid": false,
  "errors": [
    { "platform": "twitter", "field": "text", "message": "Exceeds 280 characters (got 312)" },
    { "platform": "instagram", "field": "media", "message": "Aspect ratio 1:1 not in allowed range 4:5 to 1.91:1" }
  ]
}
```

**Market:** Only Ayrshare has `POST /validate`. Every other competitor lacks this.
social-core already has `validatePublishRequest()` on every adapter — this is ready to expose.

---

### 6. "Webhook retries are unreliable" (Delivery gaps)

**The problem:** Ayrshare only retries twice. Many APIs have no delivery confirmation.
Developers lose track of async results (Instagram taking 2 minutes to process).

**What developers want:**

- 5+ retries with exponential backoff (Postproxy does this)
- Delivery history/log per webhook
- HMAC-SHA256 signing with replay protection
- Manual retry/replay endpoint
- Webhook testing/ping endpoint

**2026 update:** CDN/WAF/bot-protection services now randomly block webhook traffic — a new failure mode beyond just retry count. GitHub community discussion "Why Webhooks Still Fail Us in 2026" documents systemic issues: late/missing events, empty payloads, opaque errors.

---

### 7. "Analytics cost extra" (Paywalled insights)

**The problem:** Zernio charges extra for analytics. Developers expect basic metrics
(views, likes, comments, shares) as part of the core API.

**2026 update:** Getting worse — X eliminated free analytics entirely (pay-per-use model). Instagram tightened analytics to business/creator accounts only. TikTok gates analytics to approved partners. LinkedIn requires Partner Program for full access.

**What developers want included:**

- Post-level metrics: views, likes, comments, shares
- Account-level metrics: follower count, reach, engagement rate
- Time-series data (daily/weekly trends)
- Cross-platform comparison

---

### 8. "I want to self-host" (Privacy & control)

**The problem:** No commercial competitor offers self-hosting. SaaS means:

- Tokens stored on someone else's server
- Rate limits shared with other customers
- No audit trail for compliance
- Data residency concerns (GDPR)

**Our moat:** social-core IS the self-hosted solution. It's a library, not a SaaS.
Tokens stay in the developer's infrastructure. No shared rate limits.

**2026 update:** Demand growing strongly — Postiz hit Product Hunt #1 of the day. SaaS pricing rising fast (Hootsuite $199/mo, Sprout Social $199/seat/mo, Buffer API $99/mo). GDPR/data residency concerns driving enterprise interest in self-hosted.

## Emerging Pain Points (2025-2026)

### E1. "AI content is getting flagged" (Platform crackdowns)

Platforms actively fighting AI-generated content:

- X's March 2026 anti-LLM-spam update broke legitimate scheduling apps
- YouTube disqualifies repetitive AI Shorts from ad revenue (2025 policy)
- FTC now requires "AI-Generated" labels on sponsored content
- Instagram/Facebook deploy mandatory AI-Generated labels

**API design implication:** Developers need to know about platform AI policies. Content disclosure fields may become required. The API should expose platform-specific disclosure requirements.

### E2. "Short-form video APIs are a mess" (Fragmentation)

Each platform handles short-form video differently:

- TikTok: Content Marketing Partner status required, mandatory user consent UX
- Instagram Reels: business account + container polling, specific aspect ratios
- YouTube Shorts: quota system (1600 units), no separate API — same as regular video
- Different duration limits, aspect ratios, music licensing rules per platform

**API design implication:** A unified "publish short video" abstraction is extremely valuable but hard to get right. Per-platform format options are essential.

### E3. "Platform APIs die without warning" (Vendor risk)

- TikTok ownership transition (Oracle/MGX, closing Jan 2026) — API access uncertain
- X repeatedly removes endpoints (Follows, Manage Blocks removed from Basic/Pro)
- Meta deprecated Instagram Basic Display API with 90-day window (Dec 2024 EOL)
- One developer lost 8 months of work when Meta restricted access overnight

**API design implication:** The API needs graceful degradation, platform health endpoints, and clear "this platform is experiencing issues" signals — not just error codes after the fact.

## Secondary Complaints (Less frequent but important)

### 9. "I can't schedule recurring posts"

Cron-like scheduling, content series, evergreen rotation. Buffer had this but deprecated it.

### 10. "Rate limit headers are missing"

Developers want `X-RateLimit-Remaining`, `X-RateLimit-Reset` on every response.
Most APIs return these only after hitting the limit.

### 11. "No draft/review workflow"

Postproxy's `draft: true` -> edit -> publish pattern is loved by teams.
Developers want a staging area before content goes live.

### 12. "Thread support is broken"

Twitter threads, LinkedIn article series — most APIs treat posts as atomic.
Postproxy is the only one with `thread[]` array support.

### 13. "Bulk operations are missing"

Publishing 30 posts for a month's content calendar. No API has good bulk support.
Developers end up writing loops and hitting rate limits.

### 14. "No request IDs for debugging"

When something goes wrong, developers need a request ID to give to support.
`X-Request-Id` header on every response.

## Cross-Posting vs Repurposing — The Real User Behavior (March 2026 Research)

**Key finding:** The use case is NOT "same content everywhere." It's "compose once, customize per platform, publish in one workflow."

### Data Points

- **48% of social media marketers** share repurposed/adapted content across platforms — not identical content (Content Marketing Institute)
- **Repurposed content generates 3x more engagement** than duplicated content (Sprout Social)
- **75.4% of social media professionals** feel they "do too many things"; 91% feel negative friction toward planning/creation (SkedSocial)
- LinkedIn, Instagram, TikTok algorithms **reward native-looking content** and deprioritize cross-posted/mismatched content
- Hootsuite's own guide warns: "Posting identical content can make you come across as spammy"

### Three User Segments

| Segment                  | Behavior                                                      | What They Need from the API                                        |
| ------------------------ | ------------------------------------------------------------- | ------------------------------------------------------------------ |
| **Solo/small biz**       | Same-ish content with minor tweaks (hashtags, length)         | Default content + quick per-platform edits                         |
| **SM managers/agencies** | Distinct copy per platform from one brief, adapted media      | Full per-platform override (text, media, timing, platform options) |
| **SaaS builders**        | Programmatic publishing, often AI-generated, need API control | Per-channel `overrides` object, per-channel status                 |

### How Competitors Handle It

- **Ayrshare:** `post` field can be string (same everywhere) OR object keyed by platform name `{ "instagram": "IG text", "default": "fallback" }`. Plus `mediaUrls` same pattern. Plus `instagramOptions`, `youTubeOptions` etc.
- **Late (getlate.dev):** `customContent` per platform entry in the `platforms[]` array
- **Buffer UI:** "Customize for each network" button splits one text field into per-network fields — core feature, not afterthought
- **Postproxy:** `platforms: { instagram: { format: "reel" } }` per-platform options

### Implication for API Design

The `overrides` keyed by channel ID (not platform name) is the right call because:

- Handles multiple channels on same platform (2 LinkedIn pages with different audiences)
- More explicit than platform-name keying
- Simple case stays simple (omit overrides = same content everywhere)

### Sources

- Buffer: buffer.com/resources/how-to-crosspost/, /repurposing-content-guide/, /what-to-post-on-each-social-media-platform/
- Hootsuite: blog.hootsuite.com/cross-promote-social-media/
- Ayrshare API: ayrshare.com/docs/apis/post/overview, /post/post
- Late API: docs.getlate.dev/core/posts, getlate.dev/changelog/set-custom-publish-times-for-each-social-platform
- Outstand comparison: outstand.so/blog/best-unified-social-media-apis-for-devs
- Postproxy comparison: postproxy.dev/blog/best-social-media-scheduling-apis-compared/
- PostEverywhere: posteverywhere.ai/blog/cross-posting-vs-repurposing
- Planable: planable.io/blog/cross-posting-social-media/
- Mailchimp: mailchimp.com/resources/cross-posting/
- SkedSocial: skedsocial.com/blog/social-media-workflow-challenges
- Multibrain: multibrain.net/cross-posting-vs-repurposing-content-whats-the-difference
- Agorapulse: agorapulse.com/blog/social-media-content-creation/crossposting-on-social-media/

---

## Where to Find Current Feedback

### High-signal sources (check these first)

- `github.com/ayrshare/social-media-api/issues` — real developer bugs
- `github.com/gitroomhq/postiz-app/issues` — OSS feature requests
- `reddit.com/r/webdev` search "social media API"
- `reddit.com/r/SaaS` search "social media scheduling"
- `news.ycombinator.com` search "social media API"
- Stack Overflow: use platform-specific tags `[twitter-api-v2]`, `[instagram-graph-api]`, `[facebook-graph-api]` (generic `[social-media-api]` tag is low-activity)

### Enterprise/review sources

- G2.com reviews for Ayrshare, Buffer, Hootsuite, Sprout Social
- Capterra reviews for social media management tools
- Product Hunt comments on API product launches

### Platform-specific developer forums

- `devcommunity.x.com` — Twitter/X API feedback (active, Discourse-based)
- `developers.facebook.com/community` — Meta (BROKEN as of Mar 2026, returns error; use Facebook Developer Community FB group instead)
- `tiktok.com/community/developers` — TikTok API issues
- `developers.pinterest.com` — Pinterest API docs/feedback
- Buffer developer community moved to Discord (community.buffer.com is now a product page)

### Search patterns for live research

```
"social media API" (frustrating OR broken OR terrible) site:reddit.com
"ayrshare" OR "postproxy" OR "zernio" review 2026
[platform] API deprecation 2026
"social media scheduling" developer experience
```
