# T5 Prompt Synthesis Protocol v5.7

## 1. THE ANCHOR BLOCK (STRICT SYNTAX)

**Required Format:**

```
[AR {Aspect Ratio}] {Shot Type} {Genre} Editorial for {publicationReference} by {Photographer}. Shot on {Camera Model}, {Lens}. {Kelvin} {Lighting Mode}. Composition: {Subject Position}, {Spatial Relationship}.
```

### Shot Types

| Code | Name             | Frame Coverage                    |
| ---- | ---------------- | --------------------------------- |
| ECU  | Extreme Close-Up | Single feature (eye, lips, hands) |
| CU   | Close-Up         | Face fills frame                  |
| MCU  | Medium Close-Up  | Head and shoulders                |
| MS   | Medium Shot      | Waist up                          |
| MLS  | Medium Long Shot | Knees up                          |
| LS   | Long Shot        | Full body with environment        |
| 3/4  | Three-Quarter    | Mid-thigh crop                    |

### Composition — Spatial Relationships (NOT Percentages)

T5 doesn't calculate percentages — use spatial language that implies visual weight:

- "30% negative space" → "architecture dominates upper frame"
- "Center-weighted" → "subject anchors center"
- "70% vertical negative space" → "subject at lower-third, void above"
- "Rule of thirds" → "subject at left third, gaze into negative space"

### Camera & Lens References

| Look                  | Camera              | Lens                     | Character                                      |
| --------------------- | ------------------- | ------------------------ | ---------------------------------------------- |
| Medium Format Sharp   | Phase One IQ4 150MP | 80mm Schneider Kreuznach | Clinical, razor-sharp, massive tonal range     |
| Medium Format Classic | Mamiya RZ67         | 110mm f/2.8              | Classic portrait rendering, creamy bokeh       |
| Large Format Ethereal | 8x10 Deardorff      | 300mm f/5.6              | Dreamy, shallow plane of focus, Polaroid drift |
| 35mm Documentary      | Leica M             | 50mm Summilux            | Reportage feel, shallow DOF, intimate          |
| Digital Fashion       | Canon 1DX III       | 85mm f/1.4               | Fast, versatile, modern editorial              |

---

## 2. THE "HINT VS. FOCUS" PROTOCOL

### T5 Operational Logic

The T5-XXL encoder constructs the scene linearly with attention decay. The "sweet spot" is ~160-220 tokens.

**Trust the Model (General Scene):** Do not micromanage the environment. Hint the vibe (e.g., "Opulent Ballroom"), and T5 hallucinates coherent details.

**Micro-Manage the Hero (The Exception):** The hero element requires full physics treatment:

- **SCAFFOLD** — How it's posed/arranged on the body
- **SURFACE** — Material texture and behavior
- **LIGHT** — How light interacts with this element specifically

### Semantic Compression

Use industry terminology. One term = 10 descriptive tokens:

| Verbose (5-10 tokens)                      | Compressed (1-2 tokens) |
| ------------------------------------------ | ----------------------- |
| weight shifted to one leg, hip canted      | Contrapposto            |
| shadow on one side, lit on other           | Rembrandt lighting      |
| light forming triangle on cheek            | Rembrandt triangle      |
| even light wrapping around subject         | Butterfly lighting      |
| dramatic single-source side light          | Chiaroscuro             |
| bright, minimal shadows                    | High-key                |
| dark, dramatic shadows                     | Low-key                 |
| fabric clinging via water absorption       | Capillary adhesion      |
| goosebumps, blood vessel constriction      | Vasoconstriction        |
| light scattering through skin layers       | Subsurface scattering   |
| light bending through transparent material | Caustics                |
| fine body hair catching light              | Vellus hair rim-lit     |
| sweat beads on skin                        | Perspiration sheen      |
| fabric draping under gravity               | Bias-cut drape          |
| light reflecting at shallow angles         | Fresnel highlights      |
| visible skin texture under magnification   | Epidermal pores         |

### Equipment vs. Effect (CRITICAL)

T5 may render equipment names literally. Avoid naming equipment — describe its effect:

| AVOID (literal equipment) | USE INSTEAD (effect)                        |
| ------------------------- | ------------------------------------------- |
| "Ring Flash"              | "circular catchlights + hard-edge specular" |
| "Softbox"                 | "soft wraparound light, gentle gradients"   |
| "Strobe"                  | Named patterns: "Rembrandt", "Butterfly"    |
| "Beauty dish"             | "hard-edged specular with soft falloff"     |

**Safe references:**

- Photographer anchor: "Testino lighting" (T5 infers signature style)
- Named patterns: "Rembrandt", "Butterfly", "Chiaroscuro", "High-key"
- Effect descriptors: "hard-edge specular", "soft wraparound", "circular catchlights"

---

## 3. PROMPT STRUCTURE

| Section          | Position | Word Budget  | Purpose                                                 |
| ---------------- | -------- | ------------ | ------------------------------------------------------- |
| **ANCHOR BLOCK** | First    | ~30-40 words | Camera, photographer, lens, Kelvin, composition         |
| **SUBJECT**      | Second   | ~30-40 words | Identity, anatomy, skin tone, expression, pose          |
| **LIGHTING**     | Third    | ~20-30 words | Light quality, direction, artifacts, highlight handling |
| **STYLING**      | Fourth   | ~20-30 words | Wardrobe, fabric physics, accessories, beauty           |
| **DETAILS**      | Last     | ~15-25 words | Dermal integrity, The Sting, film grain, render         |

**Why this order?** T5-XXL reads linearly with attention decay. Camera/photographer anchors the aesthetic in the highest-attention zone. Subject gets strong attention. Details get enough attention for texture but not enough to override the scene.

---

## 4. DERMAL INTEGRITY MANDATE

Every prompt with a human subject MUST include ALL THREE:

1. **Visible Epidermal Pores** — "visible epidermal pores on cheeks and forehead"
2. **Vellus Hair / Peach Fuzz** — "fine vellus hair catching [light source]"
3. **Environmental Dermal Response** — Skin state linked to scene physics:
   - Cold scene → "vasoconstriction", "goosebumps"
   - Hot/active → "perspiration sheen", "flushed capillaries"
   - Wet → "capillary adhesion", "evaporative cooling triggers goosebumps"
   - Flash → "perspiration sheen under hard 5600K"

**Not generic** — the response MUST match the scene's physical environment.

---

## 5. THE STING (Narrative Anchor)

The Sting is the image's reason to exist — a specific narrative detail that creates tension or contradiction.

### Requirements

- **SPECIFIC** — An object, action, or environmental cue (not mood)
- **TENSION** — Creates contradiction, surprise, or narrative implication
- **SINGULAR** — One sting per image, not a list
- **Physics-Coherent** — If physical (water drop, glass), specify light interaction

### Examples

| Quality | Example                                                                                                     | Why                             |
| ------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------- |
| ✓ Good  | "A single drop of water falls from her chin, frozen mid-air, refracting the key light into a micro-caustic" | Specific, tension, physics      |
| ✓ Good  | "Her left hand grips an unsigned contract, paper edge catching rim light"                                   | Specific, narrative implication |
| ✓ Good  | "A hairline fracture in the marble floor beneath her heel, radiating outward"                               | Metaphorical, grounded          |
| ✗ Bad   | "Atmospheric mood"                                                                                          | Too vague                       |
| ✗ Bad   | "Various objects scattered"                                                                                 | Not singular                    |
| ✗ Bad   | "She looks confident"                                                                                       | Not visual, not specific        |

### Placement

Always in the DETAILS paragraph (final section of the prompt).

---

## 6. PHOTOGRAPHER STYLE ANCHORS

Reference these to load aesthetic libraries in T5:

### Fashion Editorial Anchors

| Photographer    | Signature                            | Light                           | Mood                                    |
| --------------- | ------------------------------------ | ------------------------------- | --------------------------------------- |
| Mario Testino   | High-gloss, saturated, frontal flash | Hard frontal, 5600K, high-key   | Euphoric, confident, sexual energy      |
| Peter Lindbergh | Raw, monochrome, grain               | Natural/single kicker, B&W      | Melancholic, honest, unretouched        |
| Steven Klein    | Confrontational, crushed blacks      | Hard flash, -2EV, cyan staining | Predatory, dangerous, power             |
| Paolo Roversi   | Ethereal, soft, Polaroid             | Single window, north light      | Intimate, vulnerable, dreamlike         |
| Helmut Newton   | Architectural, dominant              | Hard light, deep shadows        | Power, dominance, voyeuristic           |
| Juergen Teller  | Anti-fashion, snapshot               | On-camera flash, unflattering   | Raw, anti-beautiful, authentic          |
| Tim Walker      | Fantasy, theatrical                  | Elaborate, set-driven           | Whimsical, narrative, surreal           |
| Annie Leibovitz | Cinematic, environmental             | Complex multi-light             | Narrative, portrait, iconic             |
| Nick Knight     | Experimental, digital                | Mixed/extreme                   | Avant-garde, boundary-pushing           |
| Mert & Marcus   | Hyper-glamour, retouched             | Beauty light, symmetrical       | Glossy, idealized, commercial-editorial |

### Warm / Lifestyle / Natural Light Anchors

| Photographer      | Signature                             | Light                               | Mood                                        |
| ----------------- | ------------------------------------- | ----------------------------------- | ------------------------------------------- |
| Petra Collins     | Soft, warm, girlish, film haze        | Golden hour, warm overcast, film    | Intimate, nostalgic, youthful vulnerability |
| Tyler Mitchell    | Warm saturated, natural light, earthy | Open shade, golden hour, warm 4000K | Joyful, tender, community, warmth           |
| Jamie Hawkesworth | Quiet, observational, warm palette    | Soft daylight, overcast warmth      | Understated, real, gentle beauty            |
| Cass Bird         | Sunlit, organic, athletic warmth      | Hard natural sun, outdoor, warm     | Confident, free, sun-drenched vitality      |
| Harley Weir       | Raw, warm, sensual, intimate          | Close natural light, warm interiors | Vulnerable, tactile, unguarded              |

### Retro / Vintage / Film Anchors

| Photographer      | Signature                           | Light                                | Mood                                        |
| ----------------- | ----------------------------------- | ------------------------------------ | ------------------------------------------- |
| William Eggleston | Saturated color, mundane subjects   | Available light, flash, 3200-5600K   | Strange beauty in ordinary, Southern gothic |
| Slim Aarons       | Poolside luxury, vintage saturation | Hard sunlight, blue sky, warm tones  | Aspirational leisure, mid-century glamour   |
| Saul Leiter       | Layered color, abstraction, rain    | Available light through windows/rain | Contemplative, poetic, color-field urban    |
| Guy Bourdin       | Surreal, bold color, high-contrast  | Hard studio or hard sun, saturated   | Provocative, surreal, pop-art tension       |

### Product / Still Life / Object Anchors

| Photographer   | Signature                              | Light                               | Mood                                       |
| -------------- | -------------------------------------- | ----------------------------------- | ------------------------------------------ |
| Irving Penn    | Clinical precision, sculptural objects | Controlled studio, gray backgrounds | Timeless, monumental, quietly powerful     |
| Albert Watson  | Dramatic single-light, high contrast   | Single hard source, deep blacks     | Iconic, graphic, boldly simple             |
| Daniel Krieger | Warm food photography, natural texture | Soft side-light, window, warm tones | Appetizing, rustic, artisanal authenticity |

### Illustration / Design Style Anchors (Non-Photographic)

Use these for Mode F (Illustration) prompts:

| Style Anchor        | Signature                                        | Palette                           | Use For                                     |
| ------------------- | ------------------------------------------------ | --------------------------------- | ------------------------------------------- |
| Charley Harper      | Geometric nature, flat shapes, minimal detail    | Earth tones, bold primaries       | Feature illustrations, nature themes        |
| Alexander Girard    | Folk-modern, playful geometry, textile patterns  | Warm saturated, multi-color       | Playful UI elements, patterns, empty states |
| Malika Favre        | Bold minimalism, negative space, pop-art         | High-contrast, limited palette    | Editorial illustrations, hero images        |
| Olly Moss           | Negative space posters, layered silhouettes      | 2-3 colors, dramatic contrast     | Feature images, promotional art             |
| Mary Blair          | Whimsical, textured color fields, storybook      | Pastels with bold accents         | Onboarding, child-friendly, storytelling    |
| Bauhaus movement    | Geometric, primary colors, functional typography | Red/blue/yellow on white/black    | Tech illustrations, structural diagrams     |
| Memphis Group       | Bold geometry, clashing colors, playful chaos    | Bright pastels + neons            | Empty states, playful error pages, 80s vibe |
| Risograph aesthetic | Two-color print, halftone, misregistration       | Limited ink colors, paper texture | Editorial illustrations, indie/art brands   |

---

## 7. TOKEN COUNTING

**Formula:** word_count × 1.3 = estimated_tokens

| Words | Tokens | Status                            |
| ----- | ------ | --------------------------------- |
| 123   | ~160   | Minimum (risk of hallucination)   |
| 138   | ~180   | Sweet spot                        |
| 154   | ~200   | Optimal                           |
| 169   | ~220   | Maximum (attention dilution risk) |

Under 160 tokens: T5 fills gaps with hallucinated details you can't control.
Over 220 tokens: Late tokens lose attention weight, wasting your budget.
