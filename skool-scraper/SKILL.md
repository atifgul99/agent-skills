---
name: skool-scraper
description: Scrape any Skool community (skool.com) the user is logged into — full classroom (courses → modules → lessons with video links), pinned posts, sanitized feed. Three-phase pipeline writes markdown + manifests, then fetches transcripts (downloading video only when no native transcript exists), then images/attachments/external-links. Handles paywalled lessons by extracting titles, sub-section structure, and Loom/Mux video IDs from thumbnail metadata. Depends on the playwright-skill's persistent browser daemon for authenticated sessions.
---

# Skool Community Scraper

Extract complete course content + community data from any Skool community the user has access to. Optimized for transcript-first capture: only downloads video when no native transcript is available.

## When this activates

User says any of:

- "scrape the Skool classroom"
- "extract the course content from skool.com/<community>"
- "get all the lessons and videos from this Skool community"
- "transcribe the lessons in this Skool community"
- "save this Skool course to markdown"

## Prerequisites

**Required tools** (install once via Homebrew):

```bash
brew install yt-dlp ffmpeg
pipx install yt-dlp openai-whisper gdown    # Python tools, isolated envs
# OR: pip install --user openai-whisper gdown
```

**Persistent browser:** the playwright-skill must be installed and its daemon must be running with the user logged into Skool. If not, run the playwright-skill's `launchPersistent()` first and ask the user to log in.

## Skool data model — what we know

Skool is a Next.js app. Every page exposes its data via `<script id="__NEXT_DATA__">`.

| URL | `props.pageProps` payload |
|---|---|
| `/<community>/classroom` | `allCourses[]` — top-level course list. Each course has `id` (UUID), `name` (8-char slug), `metadata.title`, `metadata.desc`, `metadata.coverImage` |
| `/<community>/classroom/<courseSlug>` | `course.course` (the course) + `course.children[]` (modules/lessons). Each child has `unitType: 'module'` (lesson) or `'set'` (folder/section). |
| `/<community>/classroom/<courseSlug>?md=<lessonId>` | Same `course` tree, plus `props.video` with `{ playbackId, playbackToken (JWT), thumbnailToken, storyboardToken, expire (unix sec, ~24h out), duration (ms), aspectRatio, status }`. |
| `/<community>` | `pinnedPosts[]` (sometimes empty), feed renders client-side. |

### Critical structural rules

1. **`course.children` is recursive** — a `set` (folder) contains nested `children`; recurse until `unitType: 'module'`.
2. **Free vs locked content:**
   - Free lesson → `metadata.desc` (TipTap JSON), `metadata.videoLink` (Loom share URL), `metadata.videoLenMs` all populated.
   - Locked lesson → only `metadata.title` and `metadata.videoThumbnail` are present. The DOM shows an "Unlock with Premium" overlay.
3. **Recover video IDs from thumbnails** even when locked:
   - Loom: `https://cdn.loom.com/sessions/thumbnails/<LOOM_ID>-<hash>.gif` → `https://www.loom.com/share/<LOOM_ID>`
   - Mux: visit `?md=<lessonId>`, then `props.video.playbackId` → `https://stream.mux.com/<id>.m3u8`
4. **TipTap descriptions** are stored as `[v2]<JSON>` strings. Strip `[v2]` before parsing.
5. **Mux URLs are JWT-signed.** The unsigned `https://stream.mux.com/<playbackId>.m3u8` returns 403. The classroom scraper captures `props.video.playbackToken` and `expire` into the manifest (`video.muxToken`, `video.muxTokenExpire`); fetch-assets appends `?token=<JWT>` before calling ffmpeg. Tokens have a ~24h TTL — Phase 2 should run inside that window or you must re-run Phase 1 to refresh tokens (manifests with `transcript.reason: mux_token_expired | mux_token_missing` are auto-retried).
6. **Per-lesson probe is timing-sensitive.** `props.video` is populated client-side after the player mounts. The 1500 ms `waitForTimeout` after `domcontentloaded` is usually enough but a small fraction of probes return null `props.video` (the lesson then loses its Mux video for that scrape). Re-run Phase 1 to recover.
7. **"Title-unlock" courses are real but empty.** Skool gamification surfaces locked badges as zero-lesson "courses" in `allCourses[]`. Expect several `(0 lessons, 0 videos, 0 locked)` entries in the README — not a bug.

## Output folder structure

```
<OUT>/
  README.md                          # TOC of all courses
  index.json                         # all courses + lessons + asset URLs
  courses/
    01-start-here/
      course.md                      # human-readable, all lessons in one file
      manifest.json                  # machine-readable, every lesson + asset URL
      lessons/
        01-start-here/
          transcript.txt             # plain-text transcript (always saved when obtainable)
          transcript.vtt             # subtitle/timestamp form
          thumbnail.jpg
          images/<n>.<ext>
          attachments/<filename>
          external-links.txt
          video.mp4                  # ONLY if no native transcript and Whisper had to run
        02-how-to-level-up/
          ...
  feed/
    feed.md
```

## Three-phase pipeline

Each phase is independent and idempotent. Run them in order, or re-run any phase later.

### Phase 1: Scrape (~7 min for 100 lessons; per-lesson probe is ~1.5–3 s)

Walks classroom, writes markdown + manifests. No network downloads of media. Captures Mux JWT tokens — Phase 2 must run within the token's TTL (~24h).

```bash
SKOOL_COMMUNITY=launchfree \
SKOOL_OUT_DIR=./research/skool-launchfree \
  cd ~/.agent-skills/playwright-skill && \
  node run.js ~/.agent-skills/skool-scraper/scripts/classroom-scraper.js
```

### Phase 2: Fetch assets + transcripts (variable; transcript-first is fast)

Reads each course's `manifest.json`. For each lesson:

1. Save thumbnail (small, always).
2. Try **native transcript** via `yt-dlp --skip-download --write-sub --write-auto-sub --sub-lang en` (works for Loom, YouTube, Vimeo).
3. If no native transcript → download video, run Whisper, then **delete video** unless `--keep-video` is set.
4. If video is also un-fetchable (signed Mux, 403) → URL-only, mark `transcript: none`.
5. Download inline images (`assets.skool.com/...`) and PDF attachments.
6. Save other external URLs to `external-links.txt`.

```bash
node ~/.agent-skills/skool-scraper/scripts/fetch-assets.js \
  --root ./research/skool-launchfree \
  [--keep-video]              # default: delete video after Whisper
  [--whisper-model base]      # tiny|base|small|medium|large; default base
  [--only-course 01]          # restrict to one course folder
  [--skip-whisper]            # transcript-only mode; no Whisper fallback
```

### Phase 3 (optional): Sanitized feed

```bash
SKOOL_COMMUNITY=launchfree \
SKOOL_FEED_OUT=./research/skool-launchfree/feed/feed.md \
  cd ~/.agent-skills/playwright-skill && \
  node run.js ~/.agent-skills/skool-scraper/scripts/feed-scraper.js
```

## Manifest format

Each `courses/<NN>-<slug>/manifest.json`:

```json
{
  "community": "launchfree",
  "course": {
    "id": "0ab6501b...",
    "name": "6ff5a121",
    "title": "Start Here!",
    "url": "https://www.skool.com/launchfree/classroom/6ff5a121",
    "coverImage": "https://assets.skool.com/...",
    "scrapedAt": "2026-05-01T..."
  },
  "lessons": [
    {
      "ordinal": 1,
      "id": "<lesson-uuid>",
      "slug": "01-start-here",
      "title": "Start Here!",
      "section": null,
      "locked": false,
      "video": {
        "url": "https://www.loom.com/share/...",
        "source": "loom",
        "thumbnail": "https://cdn.loom.com/...",
        "lengthMs": 853639,
        "muxToken": null,
        "muxTokenExpire": null
      },
      "images": [{"url": "https://assets.skool.com/..."}],
      "attachments": [{"label": "Workbook.pdf", "url": "https://..."}],
      "externalLinks": [{"text": "Activate trial", "url": "https://..."}],
      "fetched": {
        "thumbnail": "thumbnail.jpg",
        "transcript": { "source": "native", "path": "transcript.txt" },
        "video": { "downloaded": false, "reason": "transcript_available" }
      }
    }
  ]
}
```

After Phase 2 runs, the `fetched` object is filled in for each lesson.

## File-type handling

| URL pattern | Tool | Action |
|---|---|---|
| `loom.com/share/...` | `yt-dlp` | transcript first; download mp4 only if no transcript |
| `youtube.com/watch?v=...` / `youtu.be/...` | `yt-dlp` | auto-subs (always available) — never download mp4 |
| `vimeo.com/...` | `yt-dlp` | transcript first |
| `stream.mux.com/<id>.m3u8` | `ffmpeg` | uses `?token=<JWT>` from manifest (`video.muxToken`); succeeds while token is fresh, returns `mux_token_expired` after ~24h |
| `drive.google.com/file/d/...` | `gdown` | download file directly |
| `drive.google.com/drive/folders/...` | none | save link only (folders need OAuth) |
| `docs.google.com/document|spreadsheet|presentation/...` | none | save link only |
| `assets.skool.com/...` | `curl` | download (cover images, attachments) |
| `cdn.loom.com/.../thumbnails/...` | `curl` | download thumbnail |
| Direct `*.pdf` / `*.zip` / `*.docx` | `curl` | download |
| Anything else | none | append to `external-links.txt` |

## Tips

- **Always run from the user's existing browser session** — Skool auth lives in `~/.playwright-profile`.
- **Don't use `networkidle`** in Playwright — Skool keeps a websocket open. Use `domcontentloaded` + small `waitForTimeout(1500)`.
- **Probing is slow** — the classroom scraper visits each lesson individually for Mux IDs and full descriptions: ~1.5s per lesson.
- **Prefer native transcripts** — they're free, fast, and timestamped. Only invoke Whisper as a fallback.
- **Delete video after transcription** unless the user wants the mp4. Saves disk hugely.
- **Idempotent re-runs**: every script checks for existing files and skips them. Safe to re-run after a failure.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `No Skool tab` error | Daemon browser doesn't have a Skool page open | User navigates to the community first |
| `allCourses` is null | URL was redirected to `/login` or `/signup` | User isn't logged in or isn't a member |
| All lessons empty | Walker isn't recursing into `set` containers | Verify the walker descends into `child.children` for `unitType: 'set'` |
| `yt-dlp: command not found` | Tool not installed | `brew install yt-dlp` |
| Whisper crashes on M-series Mac | Default model needs adjustment | Use `--whisper-model base` (smaller) or `whisper-cpp` instead |
| Mux video `mux_token_missing` | Manifest scraped before the token-capture patch, or `props.video.playbackToken` was absent | Re-run Phase 1 to refresh tokens, then re-run Phase 2 (auto-retries on this reason) |
| Mux video `mux_token_expired` | Phase 2 ran > 24h after Phase 1 | Re-run Phase 1 (~3-7 min), then re-run Phase 2 (auto-retries) |
| Mux video `mux_fetch_failed` (403 with token present) | Token was valid but Mux still rejected — usually transient or wrong Referer | Re-run Phase 2 (refreshes token via Phase 1 first if expired) |
| Whisper "FP16 is not supported on CPU; using FP32 instead" | Apple Silicon has no GPU passthrough for Whisper yet | Expected, harmless. Transcription still works. |
| Lesson lost its Mux video on re-scrape | `props.video` populated client-side after `domcontentloaded`; 1500 ms wait was too short | Re-run Phase 1 once more — the second probe usually succeeds |
| Feed scraper plateaus at ~30 posts | Skool feed is virtualized; scrolling stops yielding new items after a few attempts | Expected. Phase 3 grabs the most recent ~30; for full archive, click each post manually. |
| Browser closes mid-scrape | Script using `chromium.launch()` instead of `helpers.launchPersistent()` | Always use the daemon |
