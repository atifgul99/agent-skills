# prunaai/p-image-lora

> Run `prunaai/p-image` with a trained LoRA loaded on top — same sub-1s base model, but the LoRA biases output toward a learned style, subject, or concept.

- **Replicate page:** https://replicate.com/prunaai/p-image-lora
- **Latest version:** `077cbe9bf82aaf239c1802ebfd0f7353f2f471cbeca641a7780a141cdaea5701`
- **Run count:** 42,268+
- **Pricing:** Same per-call economics as `p-image` (sub-1s; see model page).
- **Endpoint:** `POST https://api.replicate.com/v1/models/prunaai/p-image-lora/predictions`
- **LoRA gallery:** https://huggingface.co/collections/PrunaAI/p-image-loras
- **Train your own:** [`prunaai/p-image-trainer`](p-image-trainer.md)

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `prompt` *(required)* | string | — | Text prompt. Often includes a trigger word baked into the LoRA. |
| `lora_weights` | string | — | HuggingFace URL: `huggingface.co/<owner>/<model>[/<file>.safetensors]`. |
| `lora_scale` | number -1–3 | `0.5` | LoRA strength. 0 = base model only; 1 = full effect. 0.5 is the safe default. |
| `aspect_ratio` | enum | `16:9` | `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `3:2`, `2:3`, `custom`. |
| `width` / `height` | int 256–1440 | — | Used only when `aspect_ratio=custom`. Multiples of 16. |
| `prompt_upsampling` | bool | `false` | LLM rewrites the prompt before generation. |
| `seed` | int | random | Reproducible generation. |
| `hf_api_token` | string (secret) | — | Required only for gated/private HuggingFace LoRAs. |
| `disable_safety_checker` | bool | `false` | Disable safety checker. |

## Output

```json
{ "type": "string", "format": "uri" }
```

## Default example

```json
{
  "prompt": "pixel art style A cozy cabin in a snowy forest with smoke from the chimney.",
  "lora_weights": "https://huggingface.co/davidberenstein1957/p-image-pixel-art-lora/resolve/main/weights.safetensors",
  "lora_scale": 0.5,
  "aspect_ratio": "1:1",
  "prompt_upsampling": false
}
```

## Node example

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const url = await replicate.run('prunaai/p-image-lora', {
  input: {
    prompt: 'pixel art style, a misty mountain monastery at sunrise',
    lora_weights: 'https://huggingface.co/davidberenstein1957/p-image-pixel-art-lora/resolve/main/weights.safetensors',
    lora_scale: 0.7,
    aspect_ratio: '16:9',
  },
});
```

## Tips

- **Trigger words matter.** Most LoRAs are trained against a specific token (e.g. `pixel art style`, `<my-subject>`). Read the LoRA's README on HuggingFace.
- **`lora_scale` tuning:** start at 0.5. Below 0.3 the LoRA barely shows; above 1.0 you risk artifacts and prompt-bleed.
- **Stack carefully:** this endpoint accepts one main LoRA. Combine effects via prompt engineering instead of multiple LoRAs.
- **Safetensors only.** Point `lora_weights` at a `.safetensors` file URL, not a model card.
