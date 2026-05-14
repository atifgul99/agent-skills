# prunaai/p-image-upscale

> Fast image upscaler. Up to 8 MP output, 4 MP in under one second.

- **Replicate page:** https://replicate.com/prunaai/p-image-upscale
- **Latest version:** `ea74e255330ec5a0a6aa394e7e1451a8cea94fe1edb8266cc4848eab047a74c4`
- **Run count:** 49,828+
- **Pricing:** See https://replicate.com/prunaai/p-image-upscale (per-second billing on Replicate's L40S/A100 hardware; sub-1s typical).
- **Endpoint:** `POST https://api.replicate.com/v1/models/prunaai/p-image-upscale/predictions`

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `image` *(required)* | URI | — | Input image to upscale. |
| `upscale_mode` | enum | `target` | `target` (scale to a fixed MP) or `factor` (multiply each side). |
| `target` | int 1–8 | `4` | Target resolution in megapixels. Used when `upscale_mode=target`. |
| `factor` | number 1–8 | `2` | Per-side multiplier. Used when `upscale_mode=factor`. Output capped at 8 MP. |
| `enhance_details` | bool | `false` | Sharpen fine textures. May increase contrast / introduce minor deviations. |
| `enhance_realism` | bool | `false` | Push toward photorealism. May deviate more from original — recommended for AI-generated images. |
| `output_format` | enum | `jpg` | `webp`, `jpg`, `png`. |
| `output_quality` | int 0–100 | `80` | Encoder quality (irrelevant for `png`). |
| `disable_safety_checker` | bool | `false` | Disable safety checker. |
| `no_op` | bool | `false` | Health-check mode. |

## Output schema

```json
{ "type": "string", "format": "uri" }
```

URL of the upscaled image.

## Default example

```json
{
  "image": "https://replicate.delivery/.../out.jpg",
  "upscale_mode": "target",
  "target": 4,
  "factor": 2,
  "enhance_details": false,
  "enhance_realism": false,
  "output_format": "jpg",
  "output_quality": 80
}
```

## Node example

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const output = await replicate.run('prunaai/p-image-upscale', {
  input: {
    image: 'https://example.com/low-res.jpg',
    upscale_mode: 'target',
    target: 8,
    enhance_realism: true,   // recommended for AI-generated input
    output_format: 'webp',
    output_quality: 90,
  },
});
```

## cURL example

```bash
curl -s https://api.replicate.com/v1/models/prunaai/p-image-upscale/predictions \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d '{
    "input": {
      "image": "https://example.com/source.jpg",
      "upscale_mode": "factor",
      "factor": 4,
      "output_format": "png"
    }
  }'
```

## Notes

- For images coming out of `p-image`, set `enhance_realism: true` — it cleans residual diffusion artifacts without re-generating.
- Hard cap: 8 MP output regardless of `factor`.
