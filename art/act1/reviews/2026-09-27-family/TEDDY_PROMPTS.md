# Teddy mood1 / mood2 — 27 September 2026

Tool: built-in image_gen, transparent_background=true. Edit target in both calls:
`art/act1/family/family_mood3_teddy.png`. Second reference: original mood1 or mood2.
Finals: `art/act1/family/family_mood1_teddy.png`, `family_mood2_teddy.png`.
Postprocessing: uniform ffmpeg scale to width700, transparent pad to700×1120.

## Mood1 prompt

Precise-object-edit for existing Vita cartoon mobile game sprite. Image 1 is the edit target: full-length mother and small daughter holding one teddy bear. Image 2 is facial-expression reference ONLY (mood1, quiet hope). Produce a single transparent RGBA full-body sprite of exactly the same mother and daughter as image 1, same clean cartoon linework, palette, patched dresses, shawl, bag, shoes, blue hair bow, one golden teddy with red bow, same handholding and teddy-cradling pose, identical head and body proportions, spacing, scale, framing and feet baseline. ONLY change facial expressions: mother has a small gentle CLOSED-mouth hopeful smile, daughter looks up at mother with a quiet relieved CLOSED-mouth smile, like image2. Not exuberantly happy, no open mouths. Do not copy image2's empty-handed pose. Keep teddy precisely in daughter's free arm as in image1. Full figures and all shoes visible with transparent padding. No background, no floor, no shadow, no text. Target framing 700x1120 portrait, preserve original sprite composition.

## Mood2 prompt

Precise-object-edit for Vita cartoon mobile game sprite. Image1 is the edit target, mother and small daughter with a teddy. Image2 is facial-expression reference ONLY for mood2: mother has a warm CLOSED-mouth smile looking down at her daughter; daughter looks up at mother with a small joyful open smile. Less exuberant than image1. Make exactly the same full-body transparent sprite as image1, changing ONLY expressions to match image2. Preserve character identity, head size, body proportions, patched clothing, burgundy shawl, green bag, blue bow, shoes, linework and palette. Preserve mother's hand held by daughter's near hand and ONE golden teddy with red bow cradled in daughter's free arm. Do not copy empty-handed pose of image2. Whole bodies and all shoes visible, same spacing and feet baseline, keep transparent padding. No scenery, no floor, no shadow, no text. Single portrait RGBA sprite with target framing 700x1120, uniform proportions.
