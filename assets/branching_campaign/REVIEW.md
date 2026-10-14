# Sequential campaign portrait review

14 October 2026. All 21 requested pictures completed, each saved at native size and committed and pushed before the next request. No concurrent image calls, generation failures, retries, resizing, conversions or game import.

All PNGs reopen successfully; SHA-256 and neutral-reference hashes match the manifest. All backgrounds sampled near #00FF00, and visual inspection found no text or watermark. These checks verify source integrity; the observations below still need Owner and Ava review.

| ID | Status | Dimensions |
| --- | --- | --- |
| `gardener_ilyin` | regenerated_neutral | 1254×1254 |
| `gardener_ilyin__warm` | generated | 1254×1254 |
| `gardener_ilyin__worried` | generated | 1254×1254 |
| `gardener_ilyin__stern` | generated | 1254×1254 |
| `pell_okonkwo_dane` | regenerated_neutral | 1254×1254 |
| `pell_okonkwo_dane__warm` | generated | 1254×1254 |
| `pell_okonkwo_dane__worried` | generated | 1254×1254 |
| `pell_okonkwo_dane__stern` | generated | 1254×1254 |
| `lio_hale` | regenerated_neutral | 1254×1254 |
| `lio_hale__warm` | generated | 1254×1254 |
| `lio_hale__worried` | generated | 1254×1254 |
| `lio_hale__stern` | generated | 1254×1254 |
| `keeper_banda` | regenerated_neutral | 1254×1254 |
| `keeper_banda__warm` | generated | 1254×1254 |
| `keeper_banda__worried` | generated | 1254×1254 |
| `keeper_banda__stern` | generated | 1254×1254 |
| `inspector_castellane` | regenerated_neutral | 1254×1254 |
| `inspector_castellane__warm` | generated | 1254×1254 |
| `inspector_castellane__worried` | generated | 1254×1254 |
| `inspector_castellane__stern` | generated | 1254×1254 |
| `director_hale__hollow` | generated | 1254×1254 |

## Issues for review

- All five regenerated neutrals and their expressions have about 4–6% headroom rather than the requested 12%. Hale has about 10%. Native files were preserved unresized as requested.
- Every stern expression is weak or close to neutral. Pell and Castellane retain slightly upturned mouths.
- Ilyin and Banda worried variants also change their neutral expressions only slightly. Pell, Lio and Castellane have clearer worried brow changes.
- Ilyin warm is particularly subtle; other warm variants show a clearer small smile.
- Several pins, badges and clothing details are one-sided despite the mirroring instruction. Banda’s lantern pin and Castellane’s sun emblem are fairly large. Lio’s torn-pin mark looks emblem-like.
- The portraits lean toward detailed painted realism rather than strongly simplified chunky miniature forms. Review style fit alongside the game’s existing portraits.
- Hale’s cyan underlighting is visibly stronger. The uncanny expression and symmetry remain subtle; review whether the intended composite persona reads strongly enough.

## Missing earlier renders

The five earlier neutral renders were not recovered; newly regenerated neutrals were used consistently for all expressions. The original 42 story and ending renders remain unavailable and were not regenerated. Quiet Foreclosure is included below.

- `lead_gardener`
- `lead_census`
- `lead_choir`
- `lead_coil`
- `lead_tessel`
- `lead_vesper`
- `lead_lio`
- `lead_census_lander`
- `revelation_lamps`
- `route_listener_garden`
- `route_alone_capital`
- `route_fossil_tessel`
- `route_fossil_sky`
- `route_arm_inspector`
- `route_crown_assembly`
- `end_hide`
- `end_warn`
- `end_answer`
- `end_answer_unprepared`
- `end_shield`
- `end_homecoming`
- `end_quiet_garden`
- `end_seed`
- `end_lantern`
- `end_mercy`
- `end_long_echo`
- `end_scatter`
- `end_decoy`
- `end_bury`
- `end_witness`
- `end_afternoon`
- `end_province`
- `end_charter_revolt`
- `end_listening_post`
- `end_into_the_dark`
- `end_annexed`
- `end_hale_reform`
- `end_ember_league`
- `end_coup`
- `end_hungry_year`
- `end_mutiny`
- `end_foreclosure`

## Checkpoint history

The 21 picture commits, newest first:

- 1eeebba art: checkpoint director_hale__hollow
- 07d6421 art: checkpoint inspector_castellane__stern
- 6212522 art: checkpoint inspector_castellane__worried
- b09f1c4 art: checkpoint inspector_castellane__warm
- 4cbb574 art: checkpoint inspector_castellane
- d35c00e art: checkpoint keeper_banda__stern
- 8094ec5 art: checkpoint keeper_banda__worried
- 425ed8c art: checkpoint keeper_banda__warm
- c23aabe art: checkpoint keeper_banda
- a74ac65 art: checkpoint lio_hale__stern
- c3dc17e art: checkpoint lio_hale__worried
- a50ae77 art: checkpoint lio_hale__warm
- ebc5384 art: checkpoint lio_hale
- 0e61446 art: checkpoint pell_okonkwo_dane__stern
- 64b538a art: checkpoint pell_okonkwo_dane__worried
- 4bf6323 art: checkpoint pell_okonkwo_dane__warm
- 99a0c28 art: checkpoint pell_okonkwo_dane
- 914a01b art: checkpoint gardener_ilyin__stern
- 705afa2 art: checkpoint gardener_ilyin__worried
- 87e1b5d art: checkpoint gardener_ilyin__warm
- 1554b89 art: checkpoint gardener_ilyin
