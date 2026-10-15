# Branching campaign art: October 15 sequential run

All 56 requested pictures completed, saved, verified and pushed one picture per commit before the next image request. This run contains 42 scenes/endings and 14 portrait style redos. No images were displayed or previewed in chat.

All 63 manifest assets now have source files: the 56 outputs from this run plus seven unchanged portraits. Earlier missing-file statements in README.md and missing_prior_renders.json describe the October 14 checkpoint and are superseded by this report.

## Results

| ID | Status | Dimensions |
| --- | --- | --- |
| `lead_gardener` | generated | 2048x768 |
| `lead_census` | generated | 2048x768 |
| `lead_choir` | generated | 2048x768 |
| `lead_coil` | generated | 2048x768 |
| `lead_tessel` | generated | 2048x768 |
| `lead_vesper` | generated | 2048x768 |
| `lead_lio` | generated | 2048x768 |
| `lead_census_lander` | generated | 2048x768 |
| `revelation_lamps` | generated | 2048x768 |
| `route_listener_garden` | generated | 2046x768 |
| `route_alone_capital` | generated | 2048x768 |
| `route_fossil_tessel` | generated | 2048x768 |
| `route_fossil_sky` | generated | 2048x768 |
| `route_arm_inspector` | generated | 2048x768 |
| `route_crown_assembly` | generated | 2048x768 |
| `end_hide` | generated | 2048x768 |
| `end_warn` | generated | 2048x768 |
| `end_answer` | generated | 2048x768 |
| `end_answer_unprepared` | generated | 2048x768 |
| `end_shield` | generated | 2048x768 |
| `end_homecoming` | generated | 2048x768 |
| `end_quiet_garden` | generated | 2048x768 |
| `end_seed` | generated | 2048x768 |
| `end_lantern` | generated | 2048x768 |
| `end_mercy` | generated | 2048x768 |
| `end_long_echo` | generated | 2048x768 |
| `end_scatter` | generated | 2048x768 |
| `end_decoy` | generated | 2048x768 |
| `end_bury` | generated | 2048x768 |
| `end_witness` | generated | 2048x768 |
| `end_afternoon` | generated | 2046x768 |
| `end_province` | generated | 2048x768 |
| `end_charter_revolt` | generated | 2048x768 |
| `end_listening_post` | generated | 2048x768 |
| `end_into_the_dark` | generated | 2048x768 |
| `end_annexed` | generated | 2048x768 |
| `end_hale_reform` | generated | 2048x768 |
| `end_ember_league` | generated | 2048x768 |
| `end_coup` | generated | 2048x768 |
| `end_hungry_year` | generated | 2048x768 |
| `end_mutiny` | generated | 2048x768 |
| `end_foreclosure` | generated | 2048x768 |
| `gardener_ilyin` | regenerated_style | 1254x1254 |
| `gardener_ilyin__warm` | regenerated_style | 1254x1254 |
| `gardener_ilyin__worried` | regenerated_style | 1254x1254 |
| `gardener_ilyin__stern` | regenerated_style | 1254x1254 |
| `keeper_banda` | regenerated_style | 1254x1254 |
| `keeper_banda__warm` | regenerated_style | 1254x1254 |
| `keeper_banda__worried` | regenerated_style | 1254x1254 |
| `keeper_banda__stern` | regenerated_style | 1254x1254 |
| `pell_okonkwo_dane` | regenerated_style | 1254x1254 |
| `pell_okonkwo_dane__warm` | regenerated_style | 1254x1254 |
| `pell_okonkwo_dane__worried` | regenerated_style | 1254x1254 |
| `pell_okonkwo_dane__stern` | regenerated_style | 1254x1254 |
| `lio_hale__stern` | regenerated_style | 1254x1254 |
| `inspector_castellane__stern` | regenerated_style | 1254x1254 |

## Verification

- Every PNG opens; dimensions and SHA-256 match the manifest.
- All 56 saved images are byte-identical to native generated PNG payloads. No resizing, cropping or conversion was performed.
- Prompts copy the supplied building blocks and item lines verbatim, with exactly the required reference instructions. Dark scenes retain their dark style and negative blocks.
- Style and face reference hashes match the current repository files. Ilyin, Banda and Pell expressions use their newly restyled neutral references. Lio and Castellane stern redos use their existing neutral references.
- Exactly 56 picture commits were individually pushed and verified. Only the 56 requested image paths and manifest changed during generation; this report and final verification corrections are a separate documentation checkpoint.
- Tesseract sparse-text OCR checked for text and text watermarks without displaying images. A CSV quotation-handling error was found in final audit, corrected by splitting TSV rows directly, and all 56 images were rescanned before final publication.
- OCR is a screening check. Style, facial expression, identity preservation, framing and crop safety were not visually previewed under the Owner instruction. Owner/Ava should review repository files before game import.

## Issues for review

- route_listener_garden and end_afternoon are native 2046x768, slightly different from exact 8:3. All other scenes are 2048x768. The native files were preserved.
- Scene outputs are below the requested 3200x1200. All portraits are native 1254x1254 rather than requested 1024x1024. No scaling was applied.
- All 14 portrait redos have top-corner pixel samples close to #00FF00. Uniformity of the entire exposed background and edge cleanup still need review before import.
- OCR candidates in `route_fossil_tessel`: LMP (72.928474% confidence). These may be false positives from scene geometry; inspect the original repository file for text or watermark. No image was displayed to assess them.
- OCR candidates in `route_crown_assembly`: ill (78.183151% confidence). These may be false positives from scene geometry; inspect the original repository file for text or watermark. No image was displayed to assess them.
- OCR candidates in `end_hide`: off (71.139587% confidence). These may be false positives from scene geometry; inspect the original repository file for text or watermark. No image was displayed to assess them.

## Failures

No generation or push failures. No generation retries were required. The OCR parsing issue was corrected in final audit.

## Picture checkpoints

| Item | ID | Commit |
| --- | --- | --- |
| 1 | `lead_gardener` | `d7edeaa` |
| 2 | `lead_census` | `0352f46` |
| 3 | `lead_choir` | `b09659b` |
| 4 | `lead_coil` | `8c8b62f` |
| 5 | `lead_tessel` | `2873f45` |
| 6 | `lead_vesper` | `0d7f633` |
| 7 | `lead_lio` | `b83b394` |
| 8 | `lead_census_lander` | `914bb8c` |
| 9 | `revelation_lamps` | `08a3ea5` |
| 10 | `route_listener_garden` | `dabfad2` |
| 11 | `route_alone_capital` | `9cb28f4` |
| 12 | `route_fossil_tessel` | `81960bb` |
| 13 | `route_fossil_sky` | `7b1e2e8` |
| 14 | `route_arm_inspector` | `4ee5a7e` |
| 15 | `route_crown_assembly` | `3fe81e7` |
| 16 | `end_hide` | `7304cd6` |
| 17 | `end_warn` | `6948783` |
| 18 | `end_answer` | `31fbaff` |
| 19 | `end_answer_unprepared` | `ea2a122` |
| 20 | `end_shield` | `ed5f014` |
| 21 | `end_homecoming` | `ca52e1e` |
| 22 | `end_quiet_garden` | `e0c4a03` |
| 23 | `end_seed` | `b38d197` |
| 24 | `end_lantern` | `900b485` |
| 25 | `end_mercy` | `e29378b` |
| 26 | `end_long_echo` | `3f74331` |
| 27 | `end_scatter` | `a7cf757` |
| 28 | `end_decoy` | `b973539` |
| 29 | `end_bury` | `9c6a371` |
| 30 | `end_witness` | `085198a` |
| 31 | `end_afternoon` | `8a2295b` |
| 32 | `end_province` | `c307cc1` |
| 33 | `end_charter_revolt` | `e4c1730` |
| 34 | `end_listening_post` | `0a5c105` |
| 35 | `end_into_the_dark` | `c3bfbb3` |
| 36 | `end_annexed` | `ac0ca1e` |
| 37 | `end_hale_reform` | `d58010b` |
| 38 | `end_ember_league` | `c1b7021` |
| 39 | `end_coup` | `55c9473` |
| 40 | `end_hungry_year` | `2b0ced1` |
| 41 | `end_mutiny` | `b0a7b2d` |
| 42 | `end_foreclosure` | `b753b8d` |
| 43 | `gardener_ilyin` | `c75fd67` |
| 44 | `gardener_ilyin__warm` | `5624d97` |
| 45 | `gardener_ilyin__worried` | `1b8430a` |
| 46 | `gardener_ilyin__stern` | `23e6221` |
| 47 | `keeper_banda` | `7bcd86c` |
| 48 | `keeper_banda__warm` | `9d2ff3a` |
| 49 | `keeper_banda__worried` | `c17c37e` |
| 50 | `keeper_banda__stern` | `3db531b` |
| 51 | `pell_okonkwo_dane` | `607c59c` |
| 52 | `pell_okonkwo_dane__warm` | `bd87899` |
| 53 | `pell_okonkwo_dane__worried` | `288802e` |
| 54 | `pell_okonkwo_dane__stern` | `1359389` |
| 55 | `lio_hale__stern` | `c712f08` |
| 56 | `inspector_castellane__stern` | `6f5a3b0` |
