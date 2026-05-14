# prunaai/p-image-edit-lora

> Run `prunaai/p-image-edit` with a trained edit-LoRA loaded on top — applies a learned editing style or transformation to your input image(s).

- **Replicate page:** https://replicate.com/prunaai/p-image-edit-lora
- **Latest version:** `191152bf662a44024fe326e61595d4f84c0293afdee7ff08d973d5e399973a4e`
- **Run count:** 90,335+
- **Pricing:** Same per-call economics as `p-image-edit` (sub-1s).
- **Endpoint:** `POST https://api.replicate.com/v1/models/prunaai/p-image-edit-lora/predictions`
- **LoRA gallery:** https://huggingface.co/collections/PrunaAI/p-image-edit-loras
- **Train your own:** [`prunaai/p-image-edit-trainer`](p-image-edit-trainer.md)

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `prompt` *(required)* | string | — | Edit instruction. Refer to inputs as `image 1`, `image 2`, etc. |
| `images` | string[] (URIs) | `[]` | Reference images. Main subject must be first. |
| `lora_weights` | string | — | HuggingFace URL to `.safetensors`. |
| `lora_scale` | number -1–3 | `1` | LoRA strength. Default is full strength (1) — edit-LoRAs are often trained to need it. |
| `turbo` | bool | `true` | Speed mode. Disable for complex edits. |
| `aspect_ratio` | enum | `match_input_image` | `match_input_image`, `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `3:2`, `2:3`. |
| `seed` | int | random | Reproducible generation. |
| `hf_api_token` | string (secret) | — | For gated/private HuggingFace LoRAs. |
| `disable_safety_checker` | bool | `false` | Disable safety checker. |

## Output

```json
{ "type": "string", "format": "uri" }
```

## Default example

```json
{
  "prompt": "dotted illustration",
  "images": ["https://replicate.delivery/.../input_002.png"],
  "lora_weights": "https://huggingface.co/davidberenstein1957/p-image-edit-dotted-illustration-lora/resolve/main/weights.safetensors",
  "lora_scale": 1,
  "turbo": true,
  "aspect_ratio": "match_input_image"
}
```

## Node example

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const url = await replicate.run('prunaai/p-image-edit-lora', {
  input: {
    prompt: 'convert to dotted illustration',
    images: ['https://example.com/photo.jpg'],
    lora_weights: 'https://huggingface.co/davidberenstein1957/p-image-edit-dotted-illustration-lora/resolve/main/weights.safetensors',
    lora_scale: 1,
    turbo: true,
  },
});
```

## Tips

- **Compared to `p-image-edit`:** the base `p-image-edit` model has 20 built-in `replicate_weights` task modes (relight, fusion, to_anime, etc.). Use `p-image-edit-lora` only when you need a *custom* style trained on your own image pairs — e.g. brand-specific look, niche illustration, proprietary product family.
- **Pair with the trainer:** if no public LoRA fits, train one in 5–15 min via [`p-image-edit-trainer`](p-image-edit-trainer.md). Output is a HuggingFace-hostable `.safetensors`.
- **Default `lora_scale` is 1, not 0.5.** Edit-LoRAs typically expect full strength to actually transform the image.
