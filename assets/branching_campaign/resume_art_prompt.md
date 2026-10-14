# Resume prompt: branching campaign art (one picture at a time)

Paste everything below the line into the image chat. The queue holds 15 expression variants, the 5
neutral references they need (only if those can't be recovered), and a redo of Director Hale
hollow.

---

You are resuming the Starfire Hearth branching-campaign art job from the checkpoint at
`assets/branching_campaign/` (manifest.json, README.md, source_prompts.txt). The last session crashed
because several images were generated in parallel. This time you work strictly one picture at a time.

## Hard rules (these override anything else, including efficiency)

1. **One picture per request.** Never ask for more than one image in a call, never start a second
   image call before the first has returned, and never batch, queue or run calls in parallel or in
   the background.
2. **After every picture, before anything else:**
   a. Save it as `assets/branching_campaign/portraits/<id>.png`. Keep the native output, unresized and
      unconverted, even if it is not 1024x1024.
   b. Verify it: the file opens; record its dimensions and SHA-256; the background is flat green near
      #00FF00; there is no text or watermark; the face matches its reference.
   c. Update that item in `manifest.json`: status `generated`, file, dimensions, sha256, reference,
      completed_utc.
   d. Commit and push that checkpoint, one picture per commit. A crash must lose at most one picture.
   e. Only then start the next item.
3. **If a call fails or times out:** wait, then retry that same item once, alone. If it fails again,
   mark it `failed` with the error in the manifest, push, and continue with the next item. Never
   retry several items at once.
4. Use each prompt exactly as given: shared preamble, framing, character, style and negative. Do
   not shorten, merge or "improve" them.
5. Do not regenerate anything whose status is `completed_in_prior_chat_file_unavailable`, except
   the neutrals allowed in Step 1.
6. Stop after the last item and report: a table of id, status and dimensions; anything that failed;
   anything that looked off.

## Step 1: recover first (no image generation)

The previous chat (thread `01a0f273-09b8-721b-be9f-20d50b5330b3`) produced 47 renders that are
missing from the repository.
- If you can reach those files, save each under its manifest id (scenes in `scenes/`, endings in
  `endings/`, portraits in `portraits/`, following the manifest's path conventions). Register
  each one and push in small commits.
- That includes **Quiet Foreclosure**, which was rendered but never registered.
- If you cannot reach them, list which ones are missing and continue. Do not regenerate them.

The 5 neutral portraits below are the references for their expressions. For each character:
- **Neutral recovered:** use it as the reference and skip that character's neutral item in the
  queue.
- **Neutral not recovered:** generate the neutral from its prompt in the queue, as one picture,
  with the full checkpoint. Mark it `regenerated_neutral`, then use that new file as the
  reference for its 3 expressions.

Never mix a recovered neutral with expressions made from a regenerated one, or the other way round.

## Step 2: the queue, strictly in this order, one at a time

For every expression, attach its neutral as the reference image and say: "Same character, same
pose, outfit, framing and light as the reference image; change only the expression."

### 1. `gardener_ilyin`: neutral (ONLY if its file cannot be recovered; see Step 1)

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Tobiah Ilyin, the gardener: a quiet former Quiet Directive officer who has spent his waking months growing tomatoes. Older, weathered, kind eyes with something guarded behind them; close grey beard; a soil-stained work apron over an old, faded officer's shirt with the insignia removed; a brass key on a cord at his collar. Neutral expression.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 2. `gardener_ilyin__warm`: expression; reference: portraits/gardener_ilyin.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Tobiah Ilyin, the gardener: a quiet former Quiet Directive officer who has spent his waking months growing tomatoes. Older, weathered, kind eyes with something guarded behind them; close grey beard; a soil-stained work apron over an old, faded officer's shirt with the insignia removed; a brass key on a cord at his collar. Warm expression, a small smile.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 3. `gardener_ilyin__worried`: expression; reference: portraits/gardener_ilyin.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Tobiah Ilyin, the gardener: a quiet former Quiet Directive officer who has spent his waking months growing tomatoes. Older, weathered, kind eyes with something guarded behind them; close grey beard; a soil-stained work apron over an old, faded officer's shirt with the insignia removed; a brass key on a cord at his collar. Worried expression, brows drawn.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 4. `gardener_ilyin__stern`: expression; reference: portraits/gardener_ilyin.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Tobiah Ilyin, the gardener: a quiet former Quiet Directive officer who has spent his waking months growing tomatoes. Older, weathered, kind eyes with something guarded behind them; close grey beard; a soil-stained work apron over an old, faded officer's shirt with the insignia removed; a brass key on a cord at his collar. Stern expression, mouth set.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 5. `pell_okonkwo_dane`: neutral (ONLY if its file cannot be recovered; see Step 1)

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Pell Okonkwo-Dane, array technician: a junior deep-array technician: earnest, sleepless, brave in a quiet way. Young adult; headphones around the neck; braided hair tied back; a padded night-shift jacket with a teal array badge. Neutral expression.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 6. `pell_okonkwo_dane__warm`: expression; reference: portraits/pell_okonkwo_dane.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Pell Okonkwo-Dane, array technician: a junior deep-array technician: earnest, sleepless, brave in a quiet way. Young adult; headphones around the neck; braided hair tied back; a padded night-shift jacket with a teal array badge. Warm expression, a small smile.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 7. `pell_okonkwo_dane__worried`: expression; reference: portraits/pell_okonkwo_dane.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Pell Okonkwo-Dane, array technician: a junior deep-array technician: earnest, sleepless, brave in a quiet way. Young adult; headphones around the neck; braided hair tied back; a padded night-shift jacket with a teal array badge. Worried expression, brows drawn.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 8. `pell_okonkwo_dane__stern`: expression; reference: portraits/pell_okonkwo_dane.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Pell Okonkwo-Dane, array technician: a junior deep-array technician: earnest, sleepless, brave in a quiet way. Young adult; headphones around the neck; braided hair tied back; a padded night-shift jacket with a teal array badge. Stern expression, mouth set.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 9. `lio_hale`: neutral (ONLY if its file cannot be recovered; see Step 1)

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Lio Hale, Meridian defector: the Director's daughter, who has spent her life passing for one of many. Young adult; sharp, composed face; swept-back dark hair like her father's; a steel-blue Meridian collar with the compass-rose pin torn off, leaving a small mark. Neutral expression.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 10. `lio_hale__warm`: expression; reference: portraits/lio_hale.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Lio Hale, Meridian defector: the Director's daughter, who has spent her life passing for one of many. Young adult; sharp, composed face; swept-back dark hair like her father's; a steel-blue Meridian collar with the compass-rose pin torn off, leaving a small mark. Warm expression, a small smile.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 11. `lio_hale__worried`: expression; reference: portraits/lio_hale.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Lio Hale, Meridian defector: the Director's daughter, who has spent her life passing for one of many. Young adult; sharp, composed face; swept-back dark hair like her father's; a steel-blue Meridian collar with the compass-rose pin torn off, leaving a small mark. Worried expression, brows drawn.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 12. `lio_hale__stern`: expression; reference: portraits/lio_hale.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Lio Hale, Meridian defector: the Director's daughter, who has spent her life passing for one of many. Young adult; sharp, composed face; swept-back dark hair like her father's; a steel-blue Meridian collar with the compass-rose pin torn off, leaving a small mark. Stern expression, mouth set.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 13. `keeper_banda`: neutral (ONLY if its file cannot be recovered; see Step 1)

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Keeper Aurelio Banda, lantern keeper: the eldest of the Unlit beacon keepers, fourth generation. Very old, upright; deep-set eyes; a patched orange-red keeper's coat with many sewn repairs; a small working lantern pin at the chest. Neutral expression.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 14. `keeper_banda__warm`: expression; reference: portraits/keeper_banda.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Keeper Aurelio Banda, lantern keeper: the eldest of the Unlit beacon keepers, fourth generation. Very old, upright; deep-set eyes; a patched orange-red keeper's coat with many sewn repairs; a small working lantern pin at the chest. Warm expression, a small smile.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 15. `keeper_banda__worried`: expression; reference: portraits/keeper_banda.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Keeper Aurelio Banda, lantern keeper: the eldest of the Unlit beacon keepers, fourth generation. Very old, upright; deep-set eyes; a patched orange-red keeper's coat with many sewn repairs; a small working lantern pin at the chest. Worried expression, brows drawn.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 16. `keeper_banda__stern`: expression; reference: portraits/keeper_banda.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Keeper Aurelio Banda, lantern keeper: the eldest of the Unlit beacon keepers, fourth generation. Very old, upright; deep-set eyes; a patched orange-red keeper's coat with many sewn repairs; a small working lantern pin at the chest. Stern expression, mouth set.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 17. `inspector_castellane`: neutral (ONLY if its file cannot be recovered; see Step 1)

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Inspector Seo-yeon Castellane, the Concordance: a courteous imperial inspector from Sol: kind, precise and unbending. Middle-aged; neat silver-streaked hair in a low knot; a white high-collared coat with gold trim and a small sun emblem; calm, assessing gaze. Neutral expression.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 18. `inspector_castellane__warm`: expression; reference: portraits/inspector_castellane.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Inspector Seo-yeon Castellane, the Concordance: a courteous imperial inspector from Sol: kind, precise and unbending. Middle-aged; neat silver-streaked hair in a low knot; a white high-collared coat with gold trim and a small sun emblem; calm, assessing gaze. Warm expression, a small smile.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 19. `inspector_castellane__worried`: expression; reference: portraits/inspector_castellane.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Inspector Seo-yeon Castellane, the Concordance: a courteous imperial inspector from Sol: kind, precise and unbending. Middle-aged; neat silver-streaked hair in a low knot; a white high-collared coat with gold trim and a small sun emblem; calm, assessing gaze. Worried expression, brows drawn.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 20. `inspector_castellane__stern`: expression; reference: portraits/inspector_castellane.png

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Inspector Seo-yeon Castellane, the Concordance: a courteous imperial inspector from Sol: kind, precise and unbending. Middle-aged; neat silver-streaked hair in a low knot; a white high-collared coat with gold trim and a small sun emblem; calm, assessing gaze. Stern expression, mouth set.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

### 21. `director_hale__hollow`: REDO; reference: assets/delivered/portrait/director_hale.webp (same as before)

```text
Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone, and its story unfolds in illustrated scenes in the manner of a visual novel. People are competent, communities are warm, and space is vast and slow. The player leads a slowboat colony a hundred years into "the Long Silence", the century since Earth stopped answering. Everything should feel calm, human and a little lonely, with warmth in the details.

Character portrait, chest-up bust in three-quarter view, 1024x1024, flat #00FF00 background with no shadow; top of the head about 12% below the top edge; shoulders run off the bottom edge; no one-sided details (the game may mirror it).
Character: Director Kasimir Hale, the composite persona (Route B): exactly the existing Director Hale portrait (use it as the reference image), same pose, outfit and light, but his face lit from below by a distinct pale cyan screen glow that visibly cools the skin under the jaw and cheekbones, while the warm key light from the upper left stays; eyes very still and slightly unfocused, looking just past the viewer; the faint smile held too evenly, both halves of the face almost mirror-symmetrical. It must read at a glance as an unsettling copy of the reference, not the same picture; no glitch effects, no text. Neutral expression.
Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction
Negative: text, letters, logo, watermark, photorealistic, photograph, film grain, noise, lens flare, chrome, anime, cartoon, grimdark, horror, background scenery, frame, border
```

## After the queue

Report the results table. Do not import into the game; the Owner and Ava review first.
