# prunaai/p-image-edit-trainer

> Fast LoRA trainer for `prunaai/p-image-edit`. Train an *edit* LoRA from before/after image pairs — teach the model a custom transformation (e.g. "convert to our brand illustration style") rather than a static subject or look.

- **Replicate page:** https://replicate.com/prunaai/p-image-edit-trainer
- **Latest version:** `5647548ed440801a15bdf5b15f505707e7f064904863b409189e689b4691e1e3`
- **Run count:** 192 (hidden from public search — direct slug only)
- **Pricing:** Per-second training time. ~5–15 min typical.
- **Endpoint:** Replicate **trainings** API.
- **Use the LoRA:** load output URL into [`p-image-edit-lora`](p-image-edit-lora.md).

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `image_data` *(required)* | URI (zip) | — | Zip of **paired** training images. See naming convention below. |
| `steps` | int 100–5000 | `1000` | Training steps. |
| `learning_rate` | number 0.00001–0.01 | `0.0001` | Lower = safer, slower. |
| `default_caption` | string | — | Caption fallback when text files are missing. **Training fails if both per-pair captions and this are absent.** |

> Note: there is no `training_type` enum here (unlike `p-image-trainer`) — edit-LoRAs always train on transformations.

## Output

```json
{ "type": "string", "format": "uri" }
```

A URL to the trained edit-LoRA `.safetensors`. Use as `lora_weights` in `p-image-edit-lora`.

## Training input zip — required pair structure

Each training example is a **before/after pair** (plus optional extra references):

```
my-edit-style.zip
├── img01_start.jpg          # source image
├── img01_end.jpg            # transformed image (the goal)
├── img01.txt                # caption: "convert to dotted illustration"
│
├── img02_start.jpg
├── img02_start2.jpg         # OPTIONAL extra reference for img02
├── img02_start3.jpg         # OPTIONAL — up to N reference images
├── img02_end.jpg            # required final result
├── img02.txt                # caption: "apply our brand poster style"
│
└── ...
```

**Rules:**
- Filename pattern: `<root>_start.<ext>` + `<root>_end.<ext>`. The `<root>` ties them together.
- Multiple references (`<root>_start2`, `<root>_start3`, …) are concatenated as image inputs at training time.
- Optional caption: `<root>.txt` (NOT `<root>_start.txt`) — the instruction the user would give for that transformation.

## Node example — kick off a training job

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const training = await replicate.trainings.create('prunaai', 'p-image-edit-trainer',
  '5647548ed440801a15bdf5b15f505707e7f064904863b409189e689b4691e1e3', {
    destination: 'your-username/your-edit-lora',
    input: {
      image_data: 'https://example.com/my-edit-pairs.zip',
      steps: 1000,
      learning_rate: 0.0001,
      default_caption: 'apply our brand poster style',
    },
  });
```

Poll with `await replicate.trainings.get(training.id)` until `status === 'succeeded'`. Then:

```js
const lora = training.output; // .safetensors URL

const edited = await replicate.run('prunaai/p-image-edit-lora', {
  input: {
    prompt: 'apply our brand poster style',
    images: ['https://example.com/new-photo.jpg'],
    lora_weights: lora,
    lora_scale: 1,
  },
});
```

## When to train your own edit-LoRA

| Use case | Build your own LoRA? |
| --- | --- |
| One-off relight / restyle | ❌ Use `p-image-edit` with `replicate_weights: relight` etc. — already built in. |
| Photo → anime / chibi / caricature | ❌ Built-in via `replicate_weights: to_anime / to_3dchibi / to_caricature`. |
| Brand-specific illustration look from photos | ✅ Train. No built-in mode will match your brand. |
| Product family transformation (sketch → render) | ✅ Train if you have ≥ 20 paired examples. |
| Photo → competitor's exact aesthetic | ✅ Train, but this is the only way; built-ins won't match. |

## Tips

- **20+ pairs minimum** for stable transformations. 50+ for production-quality.
- **Pair quality > pair count.** Bad pairs (mismatched transformations) poison the LoRA.
- **Captions describe the transformation**, not the image — "make this look like a 1970s travel poster", not "a beach scene".
- **Multiple `_start` images** help when the transformation depends on context (style + brand reference + lighting reference all pointing at one `_end`).
