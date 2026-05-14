# prunaai/p-image-trainer

> Fast LoRA trainer for `prunaai/p-image`. Feed it 10+ images of a consistent subject or style → get a `.safetensors` LoRA that biases `p-image` toward your reference.

- **Replicate page:** https://replicate.com/prunaai/p-image-trainer
- **Latest version:** `4db88013a63930daab0cd7007a0c9683cd58cfac6768e3ca244de99b30921010`
- **Run count:** 199 (small audience — most users discover via the inference model)
- **Pricing:** Per-second training time on Replicate hardware. ~5–15 min typical run depending on `steps`.
- **Endpoint:** Replicate **trainings** API (not predictions) — see usage below.
- **Use the LoRA:** load the output URL into [`p-image-lora`](p-image-lora.md).

## Input schema

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `image_data` *(required)* | URI (zip) | — | Zip archive of 10+ training images. Optional `<name>.txt` caption per image (e.g. `photo01.txt` next to `photo01.jpg`). |
| `steps` | int 100–5000 | `1000` | Training steps. More = better fit but more risk of overfitting. Default example uses `100`. |
| `learning_rate` | number 0.00001–0.01 | `0.0001` | Lower = safer, slower convergence. The default works for almost everything. |
| `training_type` | enum | `balanced` | `content` (memorize subjects/objects), `style` (capture aesthetic), `balanced` (between). |
| `default_caption` | string | — | Used when caption files are missing. **If unset and captions are missing, training fails.** |

## Output

```json
{ "type": "string", "format": "uri" }
```

A URL to the trained LoRA `.safetensors` file. Pass this as `lora_weights` to `p-image-lora`.

## Default example

```json
{
  "image_data": "https://replicate.delivery/.../input.zip",
  "steps": 100,
  "learning_rate": 0.0001,
  "training_type": "style"
}
```

## Training input zip — recommended structure

```
my-style.zip
├── img01.jpg            # ≥ 10 images, consistent subject or style
├── img01.txt            # caption: "a sunlit Tuscan piazza at golden hour"
├── img02.jpg
├── img02.txt            # caption: "a misty alpine lake at dawn"
└── ...
```

If you don't have per-image captions, set `default_caption: "a photo in <my-style> style"`.

### Picking `training_type`

| Goal | Pick | Why |
| --- | --- | --- |
| Memorize a specific person, product, or character | `content` | Forces the model to encode the subject identity, not the surroundings. |
| Reproduce a visual aesthetic across any subject | `style` | Encodes color, light, composition, texture — agnostic to content. |
| Bit of both (e.g. brand mascot in branded scenes) | `balanced` | Default — splits capacity between identity and style cues. |

## Node example — kick off a training job

```js
import Replicate from '/opt/homebrew/lib/node_modules/replicate/index.js';
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

const training = await replicate.trainings.create('prunaai', 'p-image-trainer',
  '4db88013a63930daab0cd7007a0c9683cd58cfac6768e3ca244de99b30921010', {
    destination: 'your-username/your-lora-name',   // creates a Replicate model to host the result
    input: {
      image_data: 'https://example.com/my-images.zip',
      steps: 1000,
      learning_rate: 0.0001,
      training_type: 'style',
      default_caption: 'in <my-style> aesthetic',
    },
  });

console.log(training.id, training.status);
// poll: await replicate.trainings.get(training.id)
```

When `status === 'succeeded'`, `training.output` is the LoRA `.safetensors` URL. Either:
- Use directly via `lora_weights: training.output` in `p-image-lora`, **or**
- Upload to HuggingFace under [PrunaAI/p-image-loras](https://huggingface.co/collections/PrunaAI/p-image-loras) collection so others can use it.

## cURL example

```bash
curl -s https://api.replicate.com/v1/models/prunaai/p-image-trainer/versions/4db88013.../trainings \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "destination": "your-username/your-lora-name",
    "input": {
      "image_data": "https://example.com/my-images.zip",
      "steps": 1000,
      "training_type": "style"
    }
  }'
```

## Tips

- **10–30 images is the sweet spot.** More isn't always better — quality > quantity.
- **Caption everything.** Specific captions ("a vintage 1960s Polaroid of …") teach the model what to associate with your trigger token.
- **Hold out a test prompt** that's NOT in the training set — use it to detect overfitting after the run.
- **Iterate `steps`.** Start at 1000. If under-fit (LoRA barely shows), retrain at 1500. If over-fit (every output looks identical), retrain at 500.
