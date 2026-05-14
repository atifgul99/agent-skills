# Platform API Reality

How each social media API actually behaves — engineering reality, not marketing pages.
Data sourced from building 10 adapters in social-core and auditing against current API docs (v4.1 audit, March 2026).

## Publish Flows

### Instant platforms (can return final status in API response)

| Platform           | Endpoint                       | Latency   | Gotchas                                                                                                                                                                                                                      |
| ------------------ | ------------------------------ | --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Twitter/X**      | `POST /2/tweets`               | <1s       | 280 chars (25K premium). CJK=2 chars. 4 images XOR 1 video XOR 1 GIF. v2 `uploadMedia()` (v1.1 deprecated). `media.write` scope required.                                                                                    |
| **LinkedIn**       | `POST /rest/posts` (Posts API) | 1-3s      | UGC API deprecated — use Posts API. 2s token propagation delay after refresh (publish too fast = 401). 4MB chunked video with ETags (strip quotes). 15 reserved chars need LTF escaping. 3K char limit.                      |
| **Facebook Pages** | `POST /{page-id}/feed`         | 1-2s text | 3-phase video upload (start/transfer/finish). Multi-image via unpublished photo IDs. Page selection via Business Manager. Composite `pageId_videoId` for analytics.                                                          |
| **Pinterest**      | `POST /v5/pins`                | 1-2s      | Image required. Board selection required. 800 char description (not 500). Simple.                                                                                                                                            |
| **Reddit**         | `POST /api/submit`             | 2-5s      | `application/x-www-form-urlencoded` (not JSON). Images: 3-step S3 upload (lease/upload/submit). 1h access tokens with permanent refresh. Basic Auth for token exchange. 60 RPM shared across ALL users of your OAuth client. |

### Async platforms (MUST use webhooks/polling — cannot fake synchronous)

| Platform      | Flow                                                      | Latency | Gotchas                                                                                                                                                                                                                                                                                    |
| ------------- | --------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Instagram** | Create container -> poll status (2s intervals) -> publish | 30-120s | No text-only posts. Aspect ratio 4:5 to 1.91:1 enforced. 33 error subcodes. Carousel 2-10 items (native app: 20). Stories: no caption, no collaborators. Collaborators max 3. Graph API v22.0+: `views` replaces `impressions` (deprecated Apr 2025). Rate limit slashed to 200/hr (2025). |
| **TikTok**    | PULL_FROM_URL -> heartbeat poll                           | 30-120s | Give TikTok a video URL, it downloads. FILE_UPLOAD (chunked) also available. Disclosure settings legally required. Standalone axios (no SDK). 15 posts/day/creator. 6 RPM per token.                                                                                                       |
| **YouTube**   | Resumable upload via `@googleapis/youtube` SDK            | 5-60s   | Quota: 1600 units/upload, 10K units/day. Channel selection. Privacy, made-for-kids, tags, thumbnails. Stream-based upload. Redis INCRBY quota tracking.                                                                                                                                    |
| **Threads**   | Container create -> poll (like IG) -> publish             | 30-60s  | 500 char limit (text attachments: 10K). `graph.threads.net/v1.0`. Shares Meta OAuth. 2s/15 attempts (images), 2s/60 attempts (video). GIF via GIPHY support added Feb 2026.                                                                                                                |

### Planned platforms (not yet implemented)

| Platform     | Auth Model                            | Key Challenge                                                                                                                                          |
| ------------ | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Bluesky**  | AT Protocol (OAuth now recommended)   | DID resolution, 1MB image limit (max 4), video via `app.bsky.video.uploadVideo` (50MB/3min), 300 char limit, decentralized PDS. Rate: 1500 creates/hr. |
| **Mastodon** | Per-server dynamic OAuth registration | Each instance is a separate OAuth app. No central auth.                                                                                                |
| **Telegram** | Bot token (not OAuth)                 | Channels via bot API. No user-level OAuth at all.                                                                                                      |
| **Discord**  | Bot token + OAuth2                    | Webhook-based posting simpler than bot API                                                                                                             |
| **Slack**    | OAuth 2.0 + Bot tokens                | Workspace scoping, channel selection                                                                                                                   |
| **Medium**   | OAuth 2.0 (deprecated?)               | API largely abandoned by Medium. Integration tokens exist.                                                                                             |
| **Dev.to**   | API key                               | Simple REST, no OAuth needed                                                                                                                           |

## OAuth Complexity

| Tier         | Platforms                         | What makes it hard                                                                                                       |
| ------------ | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Simple       | Twitter (PKCE), Pinterest, TikTok | Standard OAuth 2.0, no entity selection                                                                                  |
| Medium       | LinkedIn, Reddit                  | LinkedIn: org vs personal. Reddit: Basic Auth exchange, 1h tokens.                                                       |
| Complex      | Facebook, Instagram, Threads      | Shared Meta app, page/account selection, long-lived token exchange                                                       |
| Non-standard | Bluesky, Mastodon, Telegram       | Bluesky: OAuth now stable (2025+) with granular scopes. Mastodon: per-server dynamic registration. Telegram: bot tokens. |

**Key patterns in social-core:**

- Clerk handles OAuth for most platforms
- Custom `oauth_custom_instagram` provider for standalone IG
- `oauth_threads` provider for Threads (CRITICAL: was missing from task queue routing — fixed v4.1)
- `ITokenProvider` interface abstracts token storage (PostBuzz registers implementation)
- Static delay map `REFRESH_WAIT_MS` for per-provider post-refresh delays (2000ms for LinkedIn)

## Error Classification

social-core classifies every platform error into exactly one of 4 types:

| Classification  | Meaning                  | API should expose as                            | Retry?          |
| --------------- | ------------------------ | ----------------------------------------------- | --------------- |
| `refresh-token` | Token expired/revoked    | `token_expired` — developer must reconnect      | No              |
| `bad-body`      | Content invalid          | `validation_error` — developer must fix content | No              |
| `retry`         | Transient platform error | `platform_error` — system will retry            | Yes (automatic) |
| `rate-limit`    | Platform rate limit hit  | `rate_limited` — system will retry after delay  | Yes (delayed)   |

**Error map sizes (verified against codebase, March 2026):**

- Instagram: 33 subcodes (expanded from 27 during v4.1 audit)
- YouTube: 25 error codes
- TikTok: 25 error codes
- Facebook: 14 error codes (data-driven map)
- LinkedIn: 7 error codes (data-driven map)
- Reddit: 53 error codes (comprehensive coverage)
- Pinterest: 17 error codes
- Twitter/X: HTTP status + error code mapping
- Threads: 18 error codes

## Rate Limits

| Platform  | Limit                                  | Scope                | Nature                               |
| --------- | -------------------------------------- | -------------------- | ------------------------------------ |
| Twitter/X | Free: 17/day, Basic: 100/day per user  | Per-app + per-user   | Time-windowed (pay-per-use Feb 2026) |
| LinkedIn  | 100 calls/day (member), 1000/day (org) | Per-member/org       | Daily quota                          |
| Facebook  | 200 calls/user/hour                    | Per-user             | Time-windowed                        |
| Instagram | Shared with Facebook                   | Per-user             | Time-windowed                        |
| TikTok    | Varies by endpoint                     | Per-app              | Varies                               |
| YouTube   | 10,000 units/day default               | Per-project          | Quota-based (NOT request count)      |
| Pinterest | 1000/min                               | Per-app              | Time-windowed                        |
| Reddit    | 60/min per OAuth client                | Per-client (shared!) | Time-windowed                        |
| Threads   | Shared with Instagram                  | Per-user             | Time-windowed                        |

**API design implication:** Rate limits aren't just "429 retry later." YouTube is quota-based (units, not requests). Reddit is shared across ALL users. The API must expose the nature of the limit, not just "rate limited."

## Content Type Support

| Platform          | text | image    | video   | carousel | story | reel | poll | article | document |
| ----------------- | ---- | -------- | ------- | -------- | ----- | ---- | ---- | ------- | -------- |
| Twitter/X         | Y    | Y(4)     | Y(1)    | -        | -     | -    | Y    | -       | -        |
| LinkedIn Biz      | Y    | Y(9)     | Y       | -        | -     | -    | Y    | Y       | Y(PDF)   |
| LinkedIn Personal | Y    | Y        | Y       | -        | -     | -    | Y    | Y       | -        |
| Facebook Pages    | Y    | Y(multi) | Y       | -        | -     | -    | -    | -       | -        |
| Instagram         | -    | Y        | Y       | Y(2-10)  | Y     | Y    | -    | -       | -        |
| TikTok            | -    | Y(photo) | Y       | -        | -     | -    | -    | -       | -        |
| YouTube           | -    | -        | Y       | -        | -     | -    | -    | -       | -        |
| Pinterest         | -    | Y        | Y       | -        | -     | -    | -    | -       | -        |
| Reddit            | Y    | Y        | -(link) | -        | -     | -    | -    | -       | -        |
| Threads           | Y    | Y        | Y       | Y        | -     | -    | -    | -       | -        |

## Text Limits

| Platform  | Max                    | Notes                                            |
| --------- | ---------------------- | ------------------------------------------------ |
| Twitter/X | 280 / 25K premium      | CJK = 2 chars, `platformSpecific.isPremium` flag |
| LinkedIn  | 3,000                  | LTF escaping for 15 reserved chars               |
| Facebook  | 63,206                 | Effectively unlimited                            |
| Instagram | 2,200                  | No clickable links in caption                    |
| TikTok    | 2,200                  | Title text                                       |
| YouTube   | 5,000 desc / 100 title |                                                  |
| Pinterest | 800                    | (was 500 pre-v4.1 audit)                         |
| Reddit    | 40,000                 | Markdown supported                               |
| Threads   | 500                    |                                                  |

## Media Constraints

| Platform  | Max Images    | Max Video Size | Max Duration | Formats      | Aspect Ratio   |
| --------- | ------------- | -------------- | ------------ | ------------ | -------------- |
| Twitter/X | 4             | 512 MB         | 2m20s        | JPEG,PNG,GIF | Any            |
| LinkedIn  | 9             | 5 GB           | 10 min       | JPEG,PNG     | 1000px resize  |
| Facebook  | 10+           | 10 GB          | 240 min      | JPEG,PNG     | Any            |
| Instagram | 10 (carousel) | 100 MB         | 90s (reel)   | JPEG         | 4:5 to 1.91:1  |
| TikTok    | 35 (photo)    | 4 GB           | 10 min       | JPEG         | 9:16 preferred |
| YouTube   | 0             | 128 GB         | 12h          | N/A          | 16:9 preferred |
| Pinterest | 1             | 2 GB           | 15 min       | JPEG,PNG     | 2:3 optimal    |
| Reddit    | 20            | N/A            | N/A          | JPEG,PNG,GIF | Any            |
| Threads   | 10            | 1 GB           | 5 min        | JPEG,PNG     | Any            |
