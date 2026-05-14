# Replicate `prunaai/p-*` Models — Local Reference

This folder contains offline reference docs for every Pruna AI **`p-*` native** model on Replicate so the skill never needs a websearch at runtime. Each file includes: description, endpoint, full input schema (with enums), output schema, pricing, default example, and Node + cURL invocation examples.

> Pruna also publishes ~20 *optimised* versions of third-party models (Flux, Z-Image, HiDream, SDXL, Wan 2.2, etc.). Those are intentionally **not** documented here — this skill focuses on Pruna's first-party `p-*` family.

## Inference models (5)

| Model | Purpose | Runs | Pricing | Doc |
| --- | --- | --- | --- | --- |
| `prunaai/p-image` | Sub-1s text-to-image | 10,009,773+ | **$0.01 / image** | [p-image.md](p-image.md) |
| `prunaai/p-image-edit` | Sub-1s multi-image editing (20 task modes) | 28,435,302+ | **$0.01 / edit** | [p-image-edit.md](p-image-edit.md) |
| `prunaai/p-image-upscale` | Fast upscaler, up to 8 MP in <1s | 49,840+ | See model page | [p-image-upscale.md](p-image-upscale.md) |
| `prunaai/p-video` | Text/image/audio → video, draft mode | 737,767+ | See model page | [p-video.md](p-video.md) |
| `prunaai/p-video-avatar` | Cheapest avatar lipsync on the market | 6,151+ | **720p $0.025/s · 1080p $0.045/s** | [p-video-avatar.md](p-video-avatar.md) |

## LoRA ecosystem (4 — 2 trainers + 2 inference)

| Model | Purpose | Runs | Doc |
| --- | --- | --- | --- |
| `prunaai/p-image-trainer` | Train a style/content LoRA for `p-image` | 199 | [p-image-trainer.md](p-image-trainer.md) |
| `prunaai/p-image-lora` | Inference: run `p-image` with a trained LoRA | 42,268+ | [p-image-lora.md](p-image-lora.md) |
| `prunaai/p-image-edit-trainer` | Train an edit-transformation LoRA *(hidden from search)* | 192 | [p-image-edit-trainer.md](p-image-edit-trainer.md) |
| `prunaai/p-image-edit-lora` | Inference: run `p-image-edit` with a trained edit-LoRA | 90,335+ | [p-image-edit-lora.md](p-image-edit-lora.md) |

### LoRA workflow

```
images.zip ──▶ p-image-trainer       ──▶ .safetensors ──▶ p-image-lora
pairs.zip  ──▶ p-image-edit-trainer  ──▶ .safetensors ──▶ p-image-edit-lora
                                          │
                                          └──▶ (optionally) HuggingFace
                                               PrunaAI/p-image-loras
                                               PrunaAI/p-image-edit-loras
```

Public LoRA collections (find existing ones before training your own):
- https://huggingface.co/collections/PrunaAI/p-image-loras
- https://huggingface.co/collections/PrunaAI/p-image-edit-loras

## Auth

All models require `REPLICATE_API_TOKEN`. The skill resolves it from (in order):
1. `--api-key` flag passed to a script
2. `REPLICATE_API_TOKEN` env var (set in shell or `~/.claude/settings.json`)
3. `.env` / `.env.local` in the current project

## Default model selection

| Task | Model |
| --- | --- |
| Generic text-to-image (skill default) | `prunaai/p-image` |
| Text-to-image with custom style/subject LoRA | `prunaai/p-image-lora` |
| Edit / restyle / multi-image composite | `prunaai/p-image-edit` |
| Edit with custom transformation LoRA | `prunaai/p-image-edit-lora` |
| Train a new style/content LoRA | `prunaai/p-image-trainer` |
| Train a new edit-transformation LoRA | `prunaai/p-image-edit-trainer` |
| Upscale existing image | `prunaai/p-image-upscale` |
| Generate video from text/image/audio | `prunaai/p-video` |
| Talking-head / lipsync avatar | `prunaai/p-video-avatar` |

## Node client (preferred — globally installed)

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const output = await replicate.run('prunaai/p-image', { input: { prompt: '...' } });
// output is a URL (string) or a ReadableStream depending on the model
```

For trainers, use `replicate.trainings.create(...)` instead — see the trainer docs.

## cURL pattern

```bash
curl -s https://api.replicate.com/v1/models/prunaai/p-image/predictions \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d '{"input":{"prompt":"...","aspect_ratio":"16:9"}}'
```

Use `Prefer: wait` for synchronous response (up to 60s), otherwise poll the prediction URL.
