# prunaai/p-video

> Fast video generation with built-in draft mode for rapid creative iteration. Text-to-video, image-to-video, and audio-to-video in a single endpoint.

- **Replicate page:** https://replicate.com/prunaai/p-video
- **Latest version:** `68b33d8ba1189a1a997abf2c09edc5bbb90d6cfa239befbf9c903bcfee7f9a59`
- **Run count:** 737,624+
- **Pricing:** See https://replicate.com/prunaai/p-video (per-second video billing on Replicate hardware; varies by resolution and duration).
- **Endpoint:** `POST https://api.replicate.com/v1/models/prunaai/p-video/predictions`

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `prompt` *(required)* | string | — | Text prompt for video generation. |
| `image` | URI | — | Optional first-frame image (image-to-video). jpg/jpeg/png/webp. |
| `last_frame_image` | URI | — | Optional last-frame reference. |
| `audio` | URI | — | Optional audio (flac/mp3/wav). When provided, `duration` is ignored — video matches audio length. |
| `duration` | int 1–20 | `5` | Video duration in seconds. Ignored when `audio` is set. |
| `aspect_ratio` | enum | `16:9` | `16:9`, `9:16`, `4:3`, `3:4`, `3:2`, `2:3`, `1:1`. Ignored when `image` is provided. |
| `resolution` | enum | `720p` | `720p` or `1080p`. |
| `fps` | enum (24, 48) | `24` | Frames per second. |
| `draft` | bool | `false` | Lower-quality preview for rapid iteration. |
| `prompt_upsampling` | bool | `true` | Upsample/enhance the prompt with an LLM. |
| `save_audio` | bool | `true` | Mux audio into output video. |
| `disable_safety_filter` | bool | `true` | Disable safety filter on prompt + image. |
| `seed` | int | random | Reproducible generation. |
| `no_op` | bool | `false` | Health-check mode. |

## Output schema

```json
{ "type": "string", "format": "uri" }
```

URL of the rendered MP4.

## Default example

```json
{
  "prompt": "The prune says \"And this, kids, is how you generate a video in less than 10 seconds\".",
  "image": "https://replicate.delivery/.../9.png",
  "duration": 5,
  "aspect_ratio": "16:9",
  "resolution": "720p",
  "fps": 24,
  "save_audio": true,
  "draft": false,
  "prompt_upsampling": false,
  "disable_safety_filter": true
}
```

## Node example — text-to-video

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const output = await replicate.run('prunaai/p-video', {
  input: {
    prompt: 'A snow leopard padding silently across a moonlit Himalayan ridge, breath visible in the cold air',
    duration: 6,
    aspect_ratio: '16:9',
    resolution: '1080p',
    fps: 24,
    draft: true,            // fast preview
  },
});
```

## Node example — image-to-video

```js
const output = await replicate.run('prunaai/p-video', {
  input: {
    prompt: 'The character slowly turns toward camera and smiles',
    image: 'https://example.com/portrait.png',
    duration: 4,
    resolution: '720p',
  },
});
```

## Node example — audio-to-video (lipsync via prompt)

```js
const output = await replicate.run('prunaai/p-video', {
  input: {
    prompt: 'Studio interview shot, subject seated, gentle hand gestures',
    image: 'https://example.com/host.png',
    audio: 'https://example.com/script.mp3',
    save_audio: true,
  },
});
```

## Iteration workflow

1. **Draft pass** — `draft: true`, `resolution: "720p"`, `fps: 24` to scout the shot quickly.
2. **Lock the seed** — once the composition is right, copy the seed from the prediction.
3. **Final pass** — set `draft: false`, bump to `1080p` / `fps: 48` if motion fidelity matters.

## Notes

- Setting `image` overrides `aspect_ratio` — output matches input image.
- Setting `audio` overrides `duration` — output matches audio length.
- For talking-head lipsync from a single portrait, prefer **`p-video-avatar`** (cheaper, faster, purpose-built).

## Field notes (May 2026 capability test, OpenMontage)

Empirical findings from running p-video with image+audio→video for Pixar-styled character lipsync. Validated against a 1344×768 p-image keyframe + Kokoro-generated WAV files (am_michael at 6.46s, bf_emma at 7.83s).

### Confirmed capabilities

- ✅ **Image+audio→video lipsync works.** Mouth movements track phonemes, identity from keyframe is preserved across the clip, output duration matches audio length to the millisecond.
- ✅ **Style preservation.** Subsurface scattering, soft GI, copper-plating textures, dust motes — all cleanly retained from the keyframe through animation.
- ✅ **Render speed.** ~10s wall-time for a 6-8s clip in `draft: true`, 720p, 24fps.
- ✅ **Gestural motion + in-shot camera moves.** Hand gestures, head turns, body sway, slight dolly/push-in all generated cleanly when prompted.

### Confirmed limits — must plan around

- ❌ **No character locomotion.** Prompting "walks across the floor" produced gestures-in-place + camera dolly, NOT character translation across the scene. If a beat needs walking, use multiple keyframes at different positions and crossfade in compose.
- ⚠️ **Lipsync is gentle, not snappy.** Mouth tracks phonemes but with subtle articulation. For tight talking-head shots where lipsync precision matters, `p-video-avatar` snaps tighter — use it instead.
- ⚠️ **Output dimensions drift.** A 1344×768 input keyframe produced **1280×704** output (slightly cropped, not 1280×720). For HD final delivery, plan an upscale via `p-image-upscale` or lock the entire pipeline at 1280×704.
- ⚠️ **Draft mode is visibly lower fidelity** — only for capability testing and rough timing. Switch to `draft: false`, `1080p`, optionally `fps: 48` for production deliverables.

### Replicate rate limit — production critical

- **< $5 account credit:** 6 RPM with burst of 1. You cannot fire two calls in the same second. A batch of 30 p-video clips takes ~6 minutes of pure wait time on top of generation.
- **≥ $5 credit:** standard rate limits, parallel-friendly.

Use this `runWithBackoff` pattern when generating in batch:

```js
async function runWithBackoff(model, input, label) {
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      return await replicate.run(model, { input });
    } catch (e) {
      const msg = String(e?.message || e);
      const m = msg.match(/retry_after"?\s*:\s*(\d+)/);
      const wait = m ? parseInt(m[1], 10) + 2 : 12;
      if (msg.includes("429") || msg.includes("Too Many Requests")) {
        await new Promise((r) => setTimeout(r, wait * 1000));
        continue;
      }
      throw e;
    }
  }
  throw new Error(`${label}: exhausted retries`);
}
```

Pre-emptively `sleep(12_000)` between consecutive calls under throttle — don't rely on retry alone.

### Output normalization

`replicate.run()` may return a string URL, an array, or an object with a `.url()` method. Always normalize:

```js
async function urlOf(output) {
  if (typeof output === "string") return output;
  if (Array.isArray(output)) return output[0];
  if (output && typeof output.url === "function") return await output.url();
  if (output && output.toString) return output.toString();
  throw new Error(`Unexpected output: ${JSON.stringify(output)}`);
}
```

### Prompt anchor that works

Always include a render anchor at the end of the prompt — without it, output drifts toward generic AI-video aesthetic:

> "Pixar / SparkShort 3D-render aesthetic, soft global illumination, premium feature-film quality."

Replace with the appropriate style anchor for non-Pixar work (cel-shaded, painterly, photoreal, etc.).
