# 24 Audit Rules — T5 Prompt Validation

Run ALL 24 rules against the prompt. Each rule must PASS on the final audit pass.

---

## T5 Compliance (Rules 1-7)

### 1. `prompt_structure_valid`

Prompt follows the 5-paragraph structure: [AR] opener with camera specs, then SUBJECT, LIGHTING, STYLING, DETAILS paragraphs.

### 2. `photographer_camera_early`

Photographer name + camera model + lens specification appear in the first ~40 tokens (Anchor Block).

### 3. `subject_identity_valid`

Subject identity description is in the 2nd paragraph (SUBJECT). If an identityAnchor was provided, it must be copied VERBATIM — never rephrased, summarized, or reconstructed.

### 4. `lighting_before_textures`

LIGHTING section appears before any texture/material descriptions (STYLING). This ensures T5 establishes the light before interpreting surface properties.

### 5. `semantic_bleed_isolated`

Different materials are separated by sentence boundaries (periods). Example: "Metallic gown catches specular highlights. Human skin shows warm subsurface scattering." NOT: "Metallic gown catches specular highlights on warm skin."

### 6. `token_count_valid`

Estimated token count is within ~160-220 range (word_count × 1.3).

**Banned garbage tokens** T5 ignores or misinterprets:

- "photorealistic", "hyper-detailed", "ultra-realistic"
- "beautiful", "stunning", "gorgeous", "amazing"
- "perfect", "flawless", "masterpiece", "best quality"
- "4k", "8k" — always banned. These are garbage tokens that T5 doesn't meaningfully interpret. Use specific descriptors instead (e.g., "sharp render", "visible pore-level detail")
- "highly detailed" (use specific detail references instead)

### 7. `hero_element_micro_detailed`

ONE hero element has complete physics treatment:

- **SCAFFOLD** — How it's positioned/arranged
- **SURFACE** — Material texture, weave, finish
- **LIGHT** — How light specifically interacts with this element

---

## Physics Compliance (Rules 8-14)

### 8. `optical_valid`

Lens focal length enables the stated framing. Optical effects match stated equipment:

- Circular catchlights → ring flash or circular reflector
- Anamorphic flares → anamorphic lens
- Halation → overexposure or halation-prone film stock
- Shallow DOF → wide aperture (f/1.4-2.8) or large format

### 9. `lighting_valid`

**LIGHT-SURFACE COHERENCE:** Every light source MUST produce a visible artifact on the subject.

- Hard flash → circular catchlights + specular highlights + micro-shadows in pores
- Rim light → illuminated vellus hair or silhouette edge glow
- Soft diffused → gentle gradients, no hard shadows
- Window light → directional falloff, warm/cool depending on Kelvin

**Kelvin must be explicit.** If a light is defined but no corresponding artifact appears on the subject, FAIL.

### 10. `material_valid`

Fabric/material behavior matches the lighting physics:

- Wet silk → irregular adhesion, not smooth clinging (that's latex)
- Leather → anisotropic reflections, not diffuse matte
- Sheer fabric → transmissive properties where backlit
- Metal → specular reflections matching light source shape

### 11. `chromatic_valid`

Film stock matches color capabilities:

- B&W film → no color descriptions (translate to tonal values)
- Portra → warm skin tones, muted greens
- Ektar → high saturation, vivid colors
- Tri-X → high contrast, visible grain, rich blacks

### 12. `anatomical_valid`

Pose is physically possible for a human body. Use 2-3 anatomical landmarks maximum. Use visual terms, not medical jargon ("collarbone" not "clavicle", "jawline" not "mandible").

### 13. `temporal_valid`

Motion/stillness matches implied shutter speed:

- Frozen water drop → fast shutter (1/1000+)
- Motion blur → slow shutter (1/30 or slower)
- Sharp throughout → adequate shutter for subject

### 14. `highlight_sovereignty`

Explicit highlight preservation language is present (e.g., "compressed highlights", "highlight detail preserved", "specular controlled"). Highlights should never clip to 255 — texture must be visible in the brightest areas.

---

## Dermal Integrity (Rules 15-17)

### 15. `pores_visible`

Explicit mention of visible pores (e.g., "visible epidermal pores", "skin texture with pore detail").

### 16. `vellus_hair_visible`

Explicit mention of vellus hair or peach fuzz (e.g., "fine vellus hair catching rim light", "peach fuzz illuminated by...").

### 17. `biological_response_present`

Environmental dermal response linking skin state to scene physics. NOT generic — must match the lighting and environment:

- Cold → "vasoconstriction in twilight air"
- Hot → "perspiration sheen under hard 5600K"
- Wet → "evaporative cooling triggers goosebumps beneath wet silk"

---

## Content Requirements (Rules 18-24)

### 18. `affirmative_language_only`

ZERO negations in the entire prompt. Scan for: no, not, without, never, don't, doesn't, -less, un- (as negation).

- "without makeup" → "bare skin, raw complexion"
- "no jewelry" → "bare neck, unadorned wrists"

### 19. `publication_benchmark_met`

Technical choices match the referenced publication's visual language:

- Vogue Italia → high fashion, artistic, boundary-pushing
- i-D Magazine → youth, subculture, experimental
- Harper's Bazaar → elegant, polished, aspirational
- CR Fashion Book → avant-garde, conceptual, provocative

### 20. `the_sting_included`

**Fashion Editorial only.** A specific narrative detail exists in the DETAILS paragraph that creates tension or contradiction. If the sting involves a physical object (water, glass, fracture), it must include light interaction (refraction, caustics, specular reflection).

**Other modes use their own finishing concept instead:**

- Portrait → The Moment (candid micro-detail)
- Hero/Banner → Typography Safe Zone (explicit negative space for text)
- Abstract/Background → Edge Behavior (tileable/bleed/crop-safe)
- Icon/Logo → Scalability Ladder (reads at 16px, 32px, 512px)
- Illustration → Style Anchor (illustrator/movement/medium reference)
- Product → The Reveal (material detail that communicates quality)

### 21. `signal_clear`

All elements reinforce ONE coherent visual/emotional truth. The mood, lighting, pose, styling, and sting should all serve the same narrative.

### 22. `industry_terminology_used`

Standard photography and fashion industry terms are used for semantic compression. Check for verbose descriptions that could be replaced with industry shorthand.

### 23. `detail_discipline_valid`

Focus elements (hero element, subject face) are detailed with physics. Context elements (background, environment) are hinted in 1-5 words. T5 infers the rest.

### 24. `editorial_publishable`

Would a tier-1 fashion editor publish this image? The prompt must read as editorial-ready, not as a technical spec sheet. If it reads like documentation rather than a creative brief, FAIL.

---

## 5-Pass Audit Structure (Fashion Editorial)

The full 24-rule audit runs in 5 sequential passes. Each pass focuses on a specific layer:

| Pass | Name             | Rules Checked | Focus                                              |
| ---- | ---------------- | ------------- | -------------------------------------------------- |
| 1    | T5 Structure     | 1-7           | Prompt structure, token count, anchor block, hero  |
| 2    | Physics          | 8-14          | Optical, lighting, material, chromatic, temporal   |
| 3    | Dermal Integrity | 15-17         | Pores, vellus hair, biological response            |
| 4    | Content          | 18-24         | Affirmative language, sting, signal, terminology   |
| 5    | Final Review     | ALL           | Re-check all rules after any fixes from passes 1-4 |

Each pass returns PASS/FAIL per rule. If any rule FAILs in passes 1-4, fix the prompt and re-run pass 5 to confirm all 24 rules pass.

---

## Portrait Mode — 14-Rule Subset

For Portrait / People prompts (Mode B), apply these 14 rules. Rules marked ~~strikethrough~~ are skipped:

| Rule | Name                        | Applied | Why Skipped                                        |
| ---- | --------------------------- | ------- | -------------------------------------------------- |
| 1    | prompt_structure_valid      | YES     | Structure still matters (3-paragraph for portrait) |
| 2    | photographer_camera_early   | NO      | No photographer/publication required               |
| 3    | subject_identity_valid      | YES     | Subject description required                       |
| 4    | lighting_before_textures    | YES     | Light order still matters                          |
| 5    | semantic_bleed_isolated     | YES     | Material separation still matters                  |
| 6    | token_count_valid           | YES     | Budget: 120-180 tokens for portrait                |
| 7    | hero_element_micro_detailed | NO      | No hero element protocol for casual portraits      |
| 8    | optical_valid               | YES     | If camera/lens specified, must be coherent         |
| 9    | lighting_valid              | YES     | Light-surface coherence always applies             |
| 10   | material_valid              | YES     | Clothing/material physics still matter             |
| 11   | chromatic_valid             | YES     | Film stock consistency if specified                |
| 12   | anatomical_valid            | YES     | Pose must be physically possible                   |
| 13   | temporal_valid              | YES     | Motion/shutter consistency                         |
| 14   | highlight_sovereignty       | NO      | Not required for casual portraits                  |
| 15   | pores_visible               | YES     | Dermal integrity applies to all people             |
| 16   | vellus_hair_visible         | YES     | Dermal integrity applies to all people             |
| 17   | biological_response_present | YES     | Dermal integrity applies to all people             |
| 18   | affirmative_language_only   | YES     | Universal rule                                     |
| 19   | publication_benchmark_met   | NO      | No publication reference required                  |
| 20   | the_sting_included          | NO      | Optional for portraits                             |
| 21   | signal_clear                | YES     | Coherent mood still matters                        |
| 22   | industry_terminology_used   | YES     | Semantic compression still applies                 |
| 23   | detail_discipline_valid     | YES     | Focus/context hierarchy still applies              |
| 24   | editorial_publishable       | NO      | Not editorial context                              |

**Applied rules (14):** 1, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 21, 22, 23

**Note:** This is actually 18 rules, not 14. The "14-rule" label is approximate — the key distinction is that portrait mode skips publication-specific rules (2, 7, 14, 19, 20, 24) while keeping all physics and dermal rules.
