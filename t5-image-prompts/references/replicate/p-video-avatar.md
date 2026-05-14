# prunaai/p-video-avatar

> Generate talking-head videos from a single portrait image plus either a script or an audio clip. The fastest and cheapest avatar/lipsync option on Replicate.

- **Replicate page:** https://replicate.com/prunaai/p-video-avatar
- **Latest version:** `e1043205d97dc73d1fa2f6ef16a5cc66978189188fbfc27afe8475c31ad4b334`
- **Run count:** 6,148+
- **Pricing (per second of output video):**
  - **720p — $0.025/s** (10s clip = $0.25)
  - **1080p — $0.045/s** (10s clip = $0.45)
- **Endpoint:** `POST https://api.replicate.com/v1/models/prunaai/p-video-avatar/predictions`

## How it works

Provide a portrait + ONE of:
- `voice_script` — text the model speaks aloud in one of 30 voices and 10 languages.
- `audio` — your own recording, which the model lip-syncs to.

If both are provided, **`audio` wins**. Output is an MP4 with speech baked into the audio track.

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `image` *(required)* | URI | — | Portrait (first frame). jpg/jpeg/png/webp. |
| `audio` | URI | — | Optional audio to lip-sync against. Wins over `voice_script`. |
| `voice_script` | string | `""` | Text for the avatar to speak (used when no `audio`). |
| `voice` | enum | `Zephyr (Female)` | One of 30 named voices — see table below. |
| `voice_language` | enum | `English (US)` | One of 10 supported languages — see table below. |
| `voice_prompt` | string | `Say the following.` | Speaking-style direction (e.g. "calm and measured", "like a news anchor"). Do **not** put the words to say here. |
| `video_prompt` | string | `The person is talking.` | What's happening in the video itself (e.g. "gesturing with hands"). |
| `resolution` | enum | `720p` | `720p` or `1080p`. |
| `disable_safety_filter` | bool | `true` | Skip safety check on prompt + image. |
| `disable_prompt_upsampling` | bool | `false` | Skip the OpenRouter multimodal prompt upsampler — pass raw user prompt to the video model. |
| `seed` | int | random | Reproducible generation. |
| `no_op` | bool | `false` | Health-check mode. |

### Voices (30)

| Female | Male |
| --- | --- |
| Zephyr, Kore, Leda, Aoede, Callirrhoe, Autonoe, Despina, Erinome, Laomedeia, Achernar, Gacrux, Pulcherrima, Vindemiatrix, Sulafat | Puck, Charon, Fenrir, Orus, Enceladus, Iapetus, Umbriel, Algenib, Algieba, Schedar, Achird, Zubenelgenubi, Sadachbia, Sadaltager, Alnilam, Rasalgethi |

### Languages (10)

`English (US)`, `English (UK)`, `Spanish`, `French`, `German`, `Italian`, `Portuguese (Brazil)`, `Japanese`, `Korean`, `Hindi`

## Output schema

```json
{ "type": "string", "format": "uri" }
```

URL of the rendered MP4 with baked-in audio.

## Default example

```json
{
  "image": "https://replicate.delivery/.../portrait.webp",
  "voice": "Zephyr (Female)",
  "voice_language": "English (US)",
  "voice_script": "p-video is the fastest video model on earth!",
  "voice_prompt": "Say the following.",
  "video_prompt": "The person is talking.",
  "resolution": "720p",
  "disable_safety_filter": true,
  "disable_prompt_upsampling": false
}
```

## Node example — script mode

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const output = await replicate.run('prunaai/p-video-avatar', {
  input: {
    image: 'https://example.com/founder.jpg',
    voice_script: 'Welcome to OpenMontage. Today we shipped avatar lipsync at one fortieth the cost of HeyGen.',
    voice: 'Charon (Male)',
    voice_language: 'English (US)',
    voice_prompt: 'calm, confident, low-key',
    video_prompt: 'The person makes occasional small hand gestures and warm eye contact',
    resolution: '720p',
  },
});
```

## Node example — audio (BYO voice) mode

```js
const output = await replicate.run('prunaai/p-video-avatar', {
  input: {
    image: 'https://example.com/host.jpg',
    audio: 'https://example.com/recorded-voiceover.mp3',
    video_prompt: 'Subject seated at desk, gentle nodding',
    resolution: '1080p',
  },
});
```

## cURL example

```bash
curl -s https://api.replicate.com/v1/models/prunaai/p-video-avatar/predictions \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d '{
    "input": {
      "image": "https://example.com/portrait.jpg",
      "voice_script": "Hello, world.",
      "voice": "Aoede (Female)",
      "voice_language": "English (US)",
      "resolution": "720p"
    }
  }'
```

## Tips for good results

- **Portrait quality matters.** Front-facing, well-lit, no heavy occlusion.
- **Clean audio = tight lipsync.** Strip background noise before passing `audio`.
- **Use `voice_prompt` for performance, not content.** Words go in `voice_script`.
- **720p is half the price of 1080p** and works for most use cases.
- For multi-language content from one portrait: keep `image` constant, vary `voice_language` + `voice_script`.

## When to use p-video-avatar vs p-video

`p-video` (the sibling model) also supports lipsync — pass `image` + `audio` and it returns a video matched to audio length. The two models complement each other; pick by shot type, not by feature parity.

| Shot type | Use |
|---|---|
| Tight talking-head close-up (head + shoulders, static framing) | **`p-video-avatar`** — purpose-built, snappier phoneme alignment, cheaper for portrait-only use, 30 built-in voices in 10 languages. |
| Wide / cinematic shot WITH dialogue (full body, gestures, camera moves) | **`p-video`** — only model in the family that handles wide framing + body motion + lipsync. Pair with externally-generated audio (e.g. Kokoro). |
| Same character speaking in many languages | **`p-video-avatar`** — keep `image` constant, vary `voice_language` + `voice_script`. |
| Brand-controlled voices (specific tone/cadence not in the 30 built-ins) | Either model with `audio` parameter — feed externally-generated audio. |

See [p-video.md](p-video.md) "Field notes" section for the full empirical guide on the wide-shot path.

## Hybrid character-production strategy

For a multi-character animated video where some shots are tight talking-heads and others are wide dialogue scenes:

1. **Lock character → voice mapping early** (in script/asset-manifest metadata) so it stays consistent across both models.
2. **Tight portrait shots → `p-video-avatar`** with a chosen built-in voice per character (e.g. Charon for Bo, Zephyr for June). Often cheapest.
3. **Cinematic shots with dialogue → `p-video`** with externally-generated audio matching the same character voice (use Kokoro or another TTS that gives you the same tonal direction as the chosen p-video-avatar voice).
4. **Silent b-roll → `p-video`** with `image` only, `duration` field controlling length.

This is the standard hybrid pattern used by OpenMontage's animation pipeline asset-director when the user pins production to the prunaai p-* family.
