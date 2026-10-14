# Branching campaign art checkpoint

The original request contains 63 assets: 15 story scenes, 27 endings, and 21 portraits.

## Available in this repository

[Director Hale — hollow variant](portraits/director_hale__hollow.png) was generated on 14 October 2026 using the original prompt and [existing Hale portrait](../delivered/portrait/director_hale.webp). It is the sole new render from the continuation chat. The PNG is the unmodified native 1254×1254 output; the prompt requested 1024×1024 and a green background. Preserve this source for review and later game import.

[manifest.json](manifest.json) records dimensions, SHA-256, reference, prompts, and per-asset status. [source_prompts.txt](source_prompts.txt) preserves all 63 original prompt blocks.

## Resume the remaining 15 variants

The prior chat completed 47 renders, but those files were absent from the restored workspace and are not included here. Five of those are the neutral portraits required for the remaining warm, worried, and stern expression variants:

- `gardener_ilyin.png`
- `pell_okonkwo_dane.png`
- `lio_hale.png`
- `keeper_banda.png`
- `inspector_castellane.png`

Restore those original references before continuing. Do not recreate the completed neutral portraits or scenes automatically. Quiet Foreclosure completed in the prior chat but was not registered before interruption; recover its existing render as well.

Generate exactly one picture at a time using its original prompt and neutral reference. Wait for completion, save under the supplied asset ID, verify the file, and checkpoint the manifest before starting the next request. No concurrent image calls or multi-picture requests.

These source assets await game import; this checkpoint does not change the runtime asset catalog.
