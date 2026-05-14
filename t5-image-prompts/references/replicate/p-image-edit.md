# prunaai/p-image-edit

> A sub-1-second, $0.01 multi-image editing model. Twenty task modes covering edits, relighting, style transfer, and consistency.

- **Replicate page:** https://replicate.com/prunaai/p-image-edit
- **Latest version:** `5804bcec216c5f711321634f3d27aadd94e5ba124900a7af749350ed8e3c5e86`
- **Run count:** 28,434,156+
- **Pricing:** **$0.01 per edit** (sub-1s)
- **Endpoint:** `POST https://api.replicate.com/v1/models/prunaai/p-image-edit/predictions`

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `prompt` *(required)* | string | — | Edit instruction. Refer to inputs as `image 1`, `image 2`, etc. |
| `images` | string[] (URIs) | `[]` | Reference images. The main image to edit must be first. |
| `turbo` | bool | `true` | Enable turbo for speed. Disable for complex tasks where quality matters more. |
| `replicate_weights` | enum | `default` | Task selector — see table below. |
| `aspect_ratio` | enum | `match_input_image` | `match_input_image`, `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `3:2`, `2:3`. |
| `seed` | int | random | Reproducible generation. |
| `disable_safety_checker` | bool | `false` | Disable safety checker. |
| `no_op` | bool | `false` | Health-check mode (returns status without inference). |

### `replicate_weights` task modes

| Value | What it does |
| --- | --- |
| `default` | General-purpose edit driven by `prompt`. |
| `multiple_angles` | Render the same subject from new camera angles. |
| `relight` | Re-light the scene per prompt direction. |
| `light_restoration` | Fix/normalize bad lighting. |
| `white_to_scene` | Place a white-background subject into a described scene. |
| `fusion` | Combine multiple input images into one composite. |
| `add_characters` | Insert additional characters into the scene. |
| `next_scene` | Generate the next narrative beat from the same characters. |
| `style_consistency` | Re-render image in the visual style of another reference. |
| `subject_consistency` | Keep the subject identity across new prompts. |
| `scene_consistency` | Keep the scene/environment across new prompts. |
| `to_anime` | Convert photo → anime style. |
| `to_3dchibi` | Convert to 3D chibi figurine style. |
| `to_caricature` | Convert to caricature. |
| `photous` | Photographic stylization preset. |
| `extract_texture` | Extract material/texture from image 1 as a tileable map. |
| `apply_texture` | Apply a texture (image 2) onto a target (image 1). |
| `upscale` | In-model upscale (use `p-image-upscale` for the dedicated, faster pipeline). |
| `anything_to_real` | Convert stylized/illustrated input to photorealistic. |
| `white_film_to_rendering` | Convert architectural white-model render → finished render. |

## Output schema

```json
{ "type": "string", "format": "uri" }
```

URL of the edited image.

## Default example

```json
{
  "turbo": true,
  "images": ["https://replicate.delivery/.../woman-portrait.jpeg"],
  "prompt": "The woman's dress is changed to black",
  "aspect_ratio": "1:1"
}
```

## Node example

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const output = await replicate.run('prunaai/p-image-edit', {
  input: {
    prompt: 'Replace the background with a sunlit Tuscan vineyard at golden hour',
    images: ['https://example.com/source.jpg'],
    replicate_weights: 'white_to_scene',
    aspect_ratio: 'match_input_image',
    turbo: true,
  },
});
```

## cURL example

```bash
curl -s https://api.replicate.com/v1/models/prunaai/p-image-edit/predictions \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d '{
    "input": {
      "prompt": "Re-light the room with morning sun coming through east window",
      "images": ["https://example.com/room.jpg"],
      "replicate_weights": "relight",
      "turbo": true
    }
  }'
```

## Notes

- For complex edits, set `turbo: false` to trade speed for fidelity.
- The first image in `images` is always the primary subject. Order matters for `fusion`, `apply_texture`, etc.
