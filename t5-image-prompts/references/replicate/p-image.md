# prunaai/p-image

> A sub-1-second text-to-image model built for production use cases.

- **Replicate page:** https://replicate.com/prunaai/p-image
- **Latest version:** `8527975e894984ac13c83a6ba96533dbe666cd1093b0dc4ba3632c0baa5f3ca2`
- **Run count:** 10,009,130+
- **Pricing:** **$0.01 per image** (sub-1s generation)
- **Endpoint:** `POST https://api.replicate.com/v1/models/prunaai/p-image/predictions`

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `prompt` *(required)* | string | — | Text prompt for image generation. |
| `aspect_ratio` | enum | `16:9` | One of `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `3:2`, `2:3`, `custom`. |
| `width` | int 256–1440 | — | Used only when `aspect_ratio=custom`. Must be a multiple of 16. |
| `height` | int 256–1440 | — | Used only when `aspect_ratio=custom`. Must be a multiple of 16. |
| `prompt_upsampling` | bool | `false` | Upsample the prompt with an LLM. |
| `seed` | int | random | Set for reproducible generation. |
| `disable_safety_checker` | bool | `false` | Disable safety checker. |
| `lora_weights` | string | — | HuggingFace LoRA URL: `huggingface.co/<owner>/<model>[/<file>.safetensors]`. |
| `lora_scale` | number -1–3 | `0.5` | LoRA strength. |
| `hf_api_token` | string (secret) | — | HuggingFace token if LoRA requires auth. |

## Output schema

```json
{ "type": "string", "format": "uri" }
```

A single URL pointing at the generated image (PNG/WebP).

## Default example

```json
{
  "prompt": "A photo of a plant nursery entrance features a chalkboard sign reading \"SOTA Efficiency 0.5 cent per image,\" with a purple neon light beside it displaying \"Pruna AI\". Next to it hangs a poster showing a beautiful golden \"P\", and beneath the poster is written \"P-Image made this\". There is a basket with prunes in front of the store. There is a small cute knitted purple prune next to the basket.",
  "aspect_ratio": "16:9"
}
```

## Node example

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const output = await replicate.run('prunaai/p-image', {
  input: {
    prompt: '...your T5 prompt...',
    aspect_ratio: '16:9',
  },
});
// output: string URL
```

## cURL example

```bash
curl -s https://api.replicate.com/v1/models/prunaai/p-image/predictions \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d '{
    "input": {
      "prompt": "...your T5 prompt...",
      "aspect_ratio": "16:9"
    }
  }'
```

## Notes

- Best default for the `t5-image-prompts` skill: prefers natural-language T5 prose. No weighting syntax, no negative prompts.
- Custom dimensions: pick `aspect_ratio: "custom"` and supply `width`/`height` (both 256–1440, multiples of 16).
- LoRAs: any HuggingFace LoRA can be loaded at runtime via `lora_weights` + optional `hf_api_token`.
