# Competitive Landscape

6 reference implementations studied in depth. Data from API docs, GitHub repos, and integration testing.

**IMPORTANT:** This data reflects state as of March 2026. For current pricing, features, or API changes, use WebSearch to verify before making recommendations.

## Commercial APIs

### Ayrshare ($10.99-499/mo) — Feature breadth leader

**Positioning:** Most platforms (15+), most features (ads, comments, DMs, feed ingestion).
**Pricing:** Free, Starter $10.99/user/mo, Premium $149/mo, Business $499/mo, Enterprise custom.

**API shape:**

```
Base: https://api.ayrshare.com/api
Auth: Authorization: Bearer API_KEY
Multi-tenant: Profile-Key: PROFILE_KEY header

POST /post
{
  "post": "Hello world",
  "platforms": ["twitter", "linkedin", "instagram"],
  "mediaUrls": ["https://..."],
  "scheduledFor": "2026-04-01T15:00:00Z",
  "firstComment": { "instagram": "First comment text" },
  "refId": "my-idempotency-key",
  "instagramOptions": { "format": "reel" },
  "youTubeOptions": { "title": "...", "privacy": "public" },
  "linkedInOptions": { "visibility": "connections" }
}

Response:
{
  "status": "success",
  "postIds": [
    { "platform": "twitter", "status": "success", "id": "123", "postUrl": "..." },
    { "platform": "instagram", "status": "pending", "id": null }
  ],
  "errors": [
    { "platform": "linkedin", "code": "RATE_LIMITED", "message": "..." }
  ],
  "id": "ayrshare-post-id"
}
```

**Other endpoints:**

- `POST /validate` — pre-publish content check (unique differentiator)
- `POST /analytics` — by post ID or platform
- `POST /comments` — first comment or reply
- Webhooks: 6 events, HMAC-SHA256, only 2 retries (5s, 30s)
- `POST /profiles` — multi-tenant profiles

**Strengths:** Feature breadth, analytics included, validation, first comment baked in, HMAC-SHA256 webhook signing.
**Weaknesses:** Inconsistent per-platform option naming, only 2 webhook retries, limited error detail. X/Twitter now requires BYO OAuth 1.0a keys (March 31, 2026).

---

### Zernio ($0-999/mo, formerly Late API / getlate.dev) — API design leader

**Positioning:** Cleanest API design, headless OAuth, 8 SDKs, 14 platforms (Instagram, TikTok, YouTube, LinkedIn, X/Twitter, Facebook, Pinterest, Threads, Bluesky, Reddit, Snapchat, Telegram, WhatsApp, GBP).
**Pricing:** Free (20 posts/mo), Build $19/mo, Accelerate $49/mo, Unlimited $999/mo. Annual = 2 months free.

**API shape:**

```
Base: https://zernio.com/api/v1
Auth: Authorization: Bearer API_KEY

POST /posts — clean REST CRUD
GET /connect/{platform} — headless OAuth URL generation
GET /accounts — list with health status
GET /analytics — cross-platform engagement
POST /queue — scheduling with timezone
```

**Key differentiator:** Headless OAuth — returns raw authorization URL. Developer builds their own connection UI. No iframe, no redirect to Zernio's domain.

**Account health:** `GET /accounts` returns health status per connected account — token validity, scope coverage, rate limit status.

**SDKs:** Node.js, Python, Go, Ruby, Java, PHP, .NET, Rust (8 total).

**Strengths:** API design quality, headless OAuth, account health, 8 SDKs, MCP Server for AI agents, public OpenAPI spec.
**Weaknesses:** Analytics as paid add-on, fewer features than Ayrshare.

---

### Postproxy ($0-49/mo) — DX leader

**Positioning:** Best developer experience. Per-platform status everywhere, draft workflow, threads.

**API shape:**

```
Base: https://api.postproxy.dev

POST /api/posts
{
  "post": { "body": "Hello", "scheduled_at": "2026-04-01T15:00:00Z", "draft": true },
  "profiles": ["prof_123", "prof_456"],
  "media": [{ "url": "https://..." }],
  "platforms": { "instagram": { "format": "reel" } },
  "thread": [
    { "body": "Thread reply 1" },
    { "body": "Thread reply 2" }
  ]
}

Response (every response includes per-platform status):
{
  "id": "post_abc",
  "status": "processing",
  "platforms": [
    {
      "profile_id": "prof_123",
      "platform": "twitter",
      "status": "published",
      "post_url": "https://x.com/...",
      "params": { "tweet_id": "123" },
      "insights": { "impressions": 0 },
      "error": null
    },
    {
      "profile_id": "prof_456",
      "platform": "instagram",
      "status": "processing",
      "post_url": null,
      "params": null,
      "insights": null,
      "error": null
    }
  ]
}
```

**Draft workflow:** `POST /api/posts` with `draft: true` -> edit -> `POST /api/posts/:id/publish`
**Thread support:** `thread[]` array for Twitter/Threads thread children.
**Time-series analytics:** `GET /api/posts/stats?post_ids=...&from=...&to=...`
**Post statuses:** `draft | processing | processed | scheduled | media_processing_failed`
**Platform statuses:** `processing | published | failed | deleted`
**Webhooks:** 8 events, HMAC-SHA256 (`t=timestamp,v1=hmac`), 5 retries exponential backoff, delivery history.
**Calendar:** `GET /api/calendar?from=...&to=...`

**Strengths:** Per-platform status in EVERY response, draft->publish, threads, webhook reliability, best DX. SDKs in 8 languages. MCP server + n8n + Zapier integrations.
**Weaknesses:** Only 8 platforms, no comments/DMs, no standalone analytics endpoint.

**Pricing:** Free (10 posts/mo, 2 profile groups), paid tiers scale by volume. Cross-post to multiple platforms = 1 post.

---

### Buffer — UI-first (API rebuilding)

Old REST API deprecated since 2019. New **GraphQL-based API** announced July 2025, currently in beta/early access. Not publicly available yet. API access tied to higher-tier plans (~$99/mo per user). Analytics NOT available via API. Developer community moved to Discord (community.buffer.com is now a product feature, not a forum). Study for queue/slot patterns only.

---

### Hootsuite — Enterprise

Team workflows, approval chains, compliance. API exists but enterprise-focused.
Not relevant for developer self-serve API design. Study for team/approval patterns only.

## Open-Source References

### Postiz (AGPL-3.0) — Most complete OSS reference

**Stack:** NestJS + Next.js + Prisma + Temporal.io. ~27.6K GitHub stars, 4.9K forks. 28+ channels.
**Hosted pricing:** $23/mo (5 channels), Agency $79/mo (100 channels).
**Note:** Migrated from BullMQ to Temporal in v2.12.0 (now required). Also launched `postiz-agent` CLI for AI integration.

**Architecture patterns worth studying:**

- `SocialProvider` interface: `authenticate()`, `refreshToken()`, `generateAuthUrl()`, `post()`, optional `comment()`, `analytics()`
- Per-provider task queues with concurrency: X=1, LinkedIn=2, Facebook=100, Instagram=400
- Post model: one row per platform, linked by `group` field. States: `QUEUE | PUBLISHED | ERROR | DRAFT`
- OAuth state stored in Redis with 1h TTL
- Plug system for post-publish automation

**Public API shape:**

```
POST /public/v1/posts — { type: "draft"|"schedule"|"now", ... }
GET  /public/v1/posts — list with date range
DELETE /public/v1/posts/:id
DELETE /public/v1/posts/group/:group — delete cross-platform group
GET  /public/v1/integrations — list connected channels
GET  /public/v1/social/:integration — generate OAuth URL
GET  /public/v1/analytics/:integration?date= — account analytics
GET  /public/v1/analytics/post/:postId?date= — post analytics
POST /public/v1/upload — file upload
POST /public/v1/upload-from-url — URL-based upload
GET  /public/v1/integration-settings/:id — maxLength, validation schemas per provider
```

**Strengths:** 28+ providers, Temporal workflows, plug system, integration-settings endpoint. Hit Product Hunt #1 of the day.
**Weaknesses:** Plain text tokens (security gap), `@ts-ignore` scattered, no tests, string `.includes()` error matching (fragile), no HMAC on webhooks.

**License: AGPL-3.0 — study patterns ONLY, never copy code.**

---

### Mixpost (MIT) — Clean relational model

**Stack:** PHP/Laravel + Vue 3. Latest v2.6.0. 3 platforms OSS (X, Facebook, Mastodon). Pro/Enterprise: 11 platforms (+ LinkedIn, IG, YouTube, TikTok, Pinterest, Threads, Bluesky, GBP). One-time payment model (no monthly fees). Self-hosted via Docker.

**Architecture patterns worth studying:**

- `SocialProviderResponse`: 5-status enum `OK | ERROR | UNAUTHORIZED | EXCEEDED_RATE_LIMIT | NO_CONTENT` with `rateLimitAboutToBeExceeded`, `retryAfter`, `isAppLevel`
- Post <-> Account pivot table with per-account `provider_post_id`, `data`, `errors`
- `PostVersion` model: per-platform content variations (`account_id` + `content` + `is_original`)
- Batch publish with `allowFailures()` — individual platform failures don't kill the batch
- `SocialProviderPostConfigs` — declarative constraints (max chars, photo/video counts, mixed media)

**Database schema (12 tables):**

- `posts` + `post_accounts` pivot (per-platform status/errors)
- `post_versions` (content variations per platform)
- `media` with `conversions` JSON
- `metrics` + `audience` (daily aggregated analytics)
- `imported_posts` (feed ingestion)
- `accounts` with encrypted tokens

**Strengths:** Clean schema, PostVersion variations, batch publishing, encrypted tokens, audience tracking.
**Weaknesses:** Only 3 OSS platforms, no webhooks, session auth (not API keys), no validation endpoint.

**License: MIT — safe to reference patterns and code.**

## Portal Competitors (2026)

OneCast also competes as a portal/SaaS product (like Buffer/Hootsuite), not just an API.
Primary target: Buffer's audience — solo creators, freelancers, small teams.
Brand: OneCast (onecast.social). Tagline: "Social scheduling made simple."

### Tier 1: Direct Competitors (same audience, same price range)

| Tool            | Price       | Model            | Platforms | Known For                               | Free Tier               |
| --------------- | ----------- | ---------------- | --------- | --------------------------------------- | ----------------------- |
| **Buffer**      | $5/ch/mo    | Per-channel      | 11        | Simplicity, clean UX                    | 3 channels, 10 posts/ch |
| **Publer**      | $4-8/mo     | Per-account      | 10+       | Cheapest option                         | 3 accounts              |
| **Metricool**   | Free/$22/mo | Per-brand        | 10+       | Generous free tier, competitor analysis | 1 brand, 50 posts/mo    |
| **Pallyy**      | $15/mo      | Per social set   | 9         | Intuitive, agency-friendly              | Free plan with limits   |
| **SocialBee**   | $29/mo      | Per-profile tier | 11+       | Evergreen content recycling             | 14-day trial            |
| **Zoho Social** | $10/mo      | Tiered           | 6+        | Zoho CRM ecosystem                      | 1 brand, 1 user         |

### Tier 2: Team/Agency Tools

| Tool              | Price  | Model            | Platforms | Known For                            |
| ----------------- | ------ | ---------------- | --------- | ------------------------------------ |
| **Later**         | $25/mo | Per-social-set   | 9         | Visual/IG planning, grid preview     |
| **Loomly**        | $49/mo | Per-account tier | 7+        | Approval workflows, brand compliance |
| **Planable**      | $33/mo | Per-workspace    | 10+       | Collaboration, real-time feedback    |
| **Sendible**      | $25/mo | Per-profile tier | 8+        | White-label, agency CRM              |
| **ContentStudio** | $49/mo | Tiered           | 10+       | AI content curation                  |
| **Vista Social**  | $39/mo | Tiered           | 8+        | AI automation                        |

### Tier 3: Enterprise

| Tool              | Price        | Known For                                      |
| ----------------- | ------------ | ---------------------------------------------- |
| **Hootsuite**     | $99/user/mo  | Social listening (Talkwalker), ads, compliance |
| **Sprout Social** | $199/seat/mo | Enterprise analytics, unified inbox            |

### OneCast Pricing (flat workspace model)

|                    | Free | Pro          | Team                   |
| ------------------ | ---- | ------------ | ---------------------- |
| Price              | $0   | $19/mo       | $49/mo                 |
| Workspaces         | 1    | 3            | 10                     |
| Channels/workspace | 3    | 15           | Unlimited              |
| Posts/mo           | 30   | Unlimited    | Unlimited              |
| Users              | 1    | 1            | Unlimited              |
| Analytics          | No   | Full history | Full history + reports |

**Key pricing differentiator:** Buffer at 10 channels = $50-100/mo. OneCast Pro = $19/mo for up to 45 channels.

**Notable:** Crowdfire shut down June 2025. Market is crowded but fragmented — nobody dominates.

---

## New Entrants (2025-2026)

### Outstand.so — Usage-based pricing leader

**Positioning:** Lowest per-post cost, consistent data model across platforms.
**Pricing:** $5/mo base + $0.01/post overage. Volume discounts >500K posts/mo.
**Platforms:** 10+ (X, LinkedIn, IG, FB, Threads, TikTok, YouTube, Bluesky, Pinterest, GBP).
**Key features:** 99.9% SLA, <200ms latency, MCP server support, intelligent rate limiting with automatic retry.
**Why it matters:** Usage-based pricing is a new model in this space — no per-profile or per-seat fees.

### Bundle.social — Scale-friendly

**Positioning:** No account limits, built because Ayrshare got expensive at scale.
**Platforms:** 14+ (includes Discord, Slack, Mastodon, Bluesky alongside traditional platforms).
**Origin:** Launched on Hacker News Show HN (Oct 2025).
**Why it matters:** Explicitly targets teams with many accounts — a real pain point with per-seat pricing.

## Market Trends (2025-2026)

1. **MCP Server support is table stakes** — Zernio, Postproxy, Outstand all offer MCP integration for AI agents (Claude, Cursor, Windsurf). Any new API without MCP/AI integration feels incomplete.
2. **X/Twitter BYO keys** — Ayrshare now requires users to bring own OAuth 1.0a credentials for X (March 2026). X moved to pay-per-use consumption model (Feb 2026).
3. **Usage-based pricing emerging** — Outstand ($0.01/post), Postproxy (by volume) alongside traditional tier-based models.
4. **Platform count inflation** — Companies claim 15+ but messaging platforms (Telegram, WhatsApp, Slack, Discord) are counted alongside traditional social networks. Actual publishing-capable integrations vary.
5. **AI agent integration** — CLI tools, MCP servers, n8n/Zapier/Make integrations are now expected by developer audience.

## Market Consensus (Table Stakes)

These patterns appear in ALL/MOST competitors. Omitting them requires justification:

1. Bearer token auth
2. `POST /posts` with `platforms[]` array
3. ISO 8601 scheduling (`scheduledAt` or `scheduled_at`)
4. Media as URLs (server fetches, not inline base64)
5. JSON responses
6. Pagination (cursor-based preferred over page-based)
7. Webhook events for async results
8. Profile/workspace model for multi-tenant
9. Per-platform status in responses (Postproxy proved this is expected)
10. Idempotency support (Ayrshare's `refId` pattern)

## Competitive Gaps (Our Opportunities)

| Gap                  | Who has it           | Our advantage                                               |
| -------------------- | -------------------- | ----------------------------------------------------------- |
| Self-hosting         | Nobody (SaaS only)   | We're a library — self-host is default                      |
| Error classification | Nobody exposes 4-way | 200+ error codes mapped across 10 adapters                  |
| Validation endpoint  | Only Ayrshare        | We have `validatePublishRequest()` on every adapter         |
| Integration settings | Only Postiz          | We have Zod schemas for every platform                      |
| Encrypted tokens     | Only Mixpost         | AES-256-GCM in Redis (Postiz: plain text)                   |
| Thread support       | Only Postproxy       | X/Twitter adapter already supports threads                  |
| Plug automation      | Only Postiz (basic)  | 4 trigger types, engagement thresholds                      |
| No vendor lock-in    | Nobody               | Library = no API keys to our service, no shared rate limits |
