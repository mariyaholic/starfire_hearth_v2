# M1.1 Stage E — integrated city

Stage E integrates the anchored 3D city into the normal Colony planner on the existing
M1 lineage (`a160d9d334c59a2796b8c88e8eaca7f49b42c029`). The study-only city button is
retired from ordinary play. Strategic and 3D use the same construction inspector,
queue, command validation, costs and refusal reasons. Stage F's artistic finish and
Stage G's full playthrough/device validation remain pending.

## What the player can use

The planner displays exactly `ColonyRules.slot_count(planet)` canonical hex parcels,
including blocked outcrops, trait adjustments and halved dome-world counts. Mouse or
touch selects those parcels directly. Rendered roof/scaffold bounds map back to the
assembly's parcel; empty ground uses the canonical hex polygon. Numbered selectors provide an alternative;
arrow keys change selection, Home clears the inspector selection and restores the
regional overview, and wheel/pinch zoom and drag orbit the camera. A two-finger pinch
does not select a parcel on release. Jobs, governor, shipyard, tutorial highlights,
turn reports and navigation remain the existing M1 controls.

Actual completed district function and tier determine assemblies. Actual buildings
supply all fifteen building models. Settlement/Colony/City is read from real colony
population; there is no visual development slider. Ark and Archive remain exempt
from slot occupancy and sit outside the actual parcel bounds at every base size.
Catalog, terrain, architecture and development showcases are explicitly labeled
fixtures. Construction tours use a controlled seed-11 fixture with extra resources,
technologies and population, then execute real M1 commands and turns. These test
states are not claimed naturally progressed campaigns.

## Scene and generation architecture

`ColonySpatialView` creates the disposable inspector layout and an empty mount;
`WorldViewController` builds detached, owned-only descriptions and revalidates parcel
intent on fresh state. `WorldViewportHost` keeps `ColonyRenderer` alive across selection,
orders and responsive relayout. Switching views releases active geometry and cache
pins; application-level generation retires asynchronously. The production city has
no private worker, no live GameState reference and no unfinished worker join.

The scene has distinct terrain, completed-site, construction, placement-preview,
access-route, ground-cover, ambient-activity and selection layers. Completed and
queued nodes patch by stable slot/item identity. Upgrades replace the affected
assembly. Demolition follows the immediate command-preview state. Queues and ghost
geometry stay separate from completed structures. Queue, preview, selection,
revision and tier changes cannot change the terrain input key. Completion or removal
of a footprint changes local ground and routes while retaining the macro field.
That change regenerates the bounded tile result; when it arrives, terrain and
associated city roots are replaced together. Retaining those roots through the swap
and uploading smaller tile batches remain optimization debt. Selection, queue and
tier changes patch without that terrain swap.

Sixteen bounded tiles cover the region: four central tiles have detailed geometry;
twelve outer tiles use coarser geometry. Adjacent tiles sample the same global field
and fixed normal offsets. Three-art-unit skirts cover unequal-resolution boundaries.
Native and cooperative browser jobs produce identical arrays. This is a finite
regional scene, not an open-world generator.

Decorative access uses an independent bounded lattice, avoiding blocked plots, built
footprints and landmark envelopes. Line-of-sight simplification removes grid zigzags;
resampling follows the terrain. Even outer plots isolated by blocked interior hex
neighbors can connect around them. Routes add no simulation adjacency or bonuses.
Small cosmetic vehicles animate on them and stop with Pause/Reduce motion.

## Save and graphics-update compatibility

Optional `groundworks/1` records completed, committed parcel footprints. Queued
orders and previews never commit clearings. Cancel/Undo removes temporary vegetation
masks; an already completed clearing retains a prepared-ground finish after demolition
and resave. Old saves reconstruct only their current completed footprints, since
an older save cannot describe clearings that it never recorded. Unknown future
`groundworks` versions are retained and ignored by this renderer.

New games pin **city catalog 2 / architecture kit 2**. It completes the study kit's
missing agriculture, energy and Vael mining tier distinctions. Catalog 1's assembly
implementation is unchanged and remains supported for existing graphics saves.
Planet/stellar materials and generators, civilian catalog, appearance identity,
anchors, game schema, content tables and golden simulation hashes are unchanged.
There is no automatic conversion of existing city catalogs.

The archived, checksum-verified Stage D source was exercised as an actual older
writer. It reads catalog 1 and preserves the new optional clearing history; it uses
its preserving fallback for catalog 2. Reopening both resaved files in Stage E
recovers the same gameplay hash, catalog, physical profiles, anchors and groundworks.
An original compatible view takes priority over an older fallback overlay when a
newer renderer supports it again. Valid additions merge without replacing authoritative
geography; the unknown original envelope remains byte-exact.

Original pinned M1 still loads gameplay but drops graphics metadata on its own resave.
That documented older-executable boundary is unchanged. Browser durability remains
scoped to completed IndexedDB sync at the same origin, rather than power-loss recovery.
See [the maintained compatibility contract](M1_1_GRAPHICS_SAVE_CONTRACT.md).

## Revalidation evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Full gameplay/UI/save/golden suite | **209 tests, 11,676 checks, zero failures** | `evidence/tests.log` |
| Content validation | **20 tables, 328 records, 1,389 strings; zero errors/skips** | `evidence/data.log` |
| Native normal-planner tour | **187 checks, 20 captures, zero failures** | `native/verification.json`, `evidence/native.log` |
| Actual desktop and touch browser exports | **275 checks, 16 captures, zero failures/errors** | `browser/verification.json`, `evidence/web.log` |
| Archived Stage D writer and current restore | **6 older-writer + 12 restore checks, zero failures** | `evidence/compatibility/older_verification.json`, `verify_verification.json` |
| Native/browser gameplay and saved identity comparison | **25 checks, zero failures** | `evidence/cross_platform_continuity.json` |
| Review artifact integrity and mobile gallery | SHA256, ZIP, clean pinned-source patch application, 36 images and 1440/390 px layouts pass | `evidence/artifact_validation.json` |

The five new city incorporation tests contribute 1,606 assertions. Frozen v1 appearance
fixtures and existing simulation goldens were not rebaselined.

The native and browser tours invoke the existing Build, Move Up, Rush, Cancel, Undo,
Upgrade and Demolish controls, then compare each actual resolved turn with pure M1
simulation replay. The same order sequence produces the same final hash in Strategic
and 3D. Queue changes preserve completed node identities; upgrades preserve terrain
and unaffected assemblies. Native checks additionally cover parcel ray picking,
cover-mask restoration with a single synthetic candidate removed before captures,
all building IDs, real base sizes, terrain families, stages,
landmark fit and four PC/phone 100–200% layout audits. Browser uses actual canvas
clicks/taps, keyboard and a real two-finger emulated pinch.

Manual city saves are restored natively and after destroying/reopening the browser
page/WASM process. Saved graphics fingerprints, anchor, clearing history and gameplay
hash must match. This supplements the existing automatic/checkpoint/load-route tests;
it does not replace Stage D's compatibility evidence.

## Quality, performance and remaining limits

The non-threaded browser export is **48.12 MB gzip**, up **0.86 MB** from pinned M1,
within the 150 MB export target. Native process peak RSS was **809.3 MB**, including
software OpenGL and capture readback; the <400 MB memory target is exceeded.

| Software Chromium profile | Last functional window process-delta p95 | Retained regional refinement-slice p95 | Largest retained layer patch |
| --- | --- | --- | --- |
| Desktop | 142.57 ms | 22.70 ms | 379.20 ms |
| Phone | 146.50 ms | 26.70 ms | 371.30 ms |

These samples exceed the 33.3 ms browser frame and 2 ms cooperative-slice targets.
Web regional arrays/water estimate is 0.45 MB. The slice and initial layer patch
costs are carried forward for optimization; the existing scene remains selectable
while refinement runs. They do not establish physical Android/iOS performance.

Native saved-city process-delta p95 was **143.10 ms**; the last fixture window was
**140.51 ms**, exceeding the 16.7 ms desktop frame target in this software-rendered test. Native
regional CPU arrays/water estimate was **1.59 MB**. The saved-city initial layer patch
was **230.19 ms**; subsequent last-fixture small patches were **0.35–0.42 ms**.
These are specific functional-tour samples, not a complete patch latency distribution.

`evidence/performance.json` contains bounded last-512-frame Godot `_process(delta)`
windows and available scheduler/layer samples. Engine deltas can be smoothed/clamped,
so these do not certify wall-clock stalls or actual FPS. The tours include generation,
relayout and captures; actual GPU/device profiling remains pending.

Web uses a temporary 18 ms regional cooperative allowance (space retains 6 ms), a half-resolution city viewport and
no MSAA. The 18 ms allowance exceeds the planned 2 ms cooperative target. Native Standard uses full resolution and 2× MSAA. Quality targets remain
tracked, and temporary budget overruns are permitted under the Owner's quality-first
instruction. Cache estimates include regional arrays/water maps; they exclude driver
allocation overhead. Linux native RSS includes software graphics and PNG readback.
Browser timing telemetry comes from Chromium software WebGL, not a physical GPU.

Materials, foliage silhouettes, route detailing and the full Ember finish remain
provisional. Ice-terrain overview framing places the small city high in the frame;
adaptive framing and terrain/material readability need the Stage F finish. The
200% phone resource strip also truncates a trailing value despite passing the
existing structural layout audit; Stage F must finish overflow handling. Direct
image inspection is recorded in `evidence/visual_review.json`. Accessibility and
complete responsive polish remain Stage F; real
Android/iOS hardware performance, long navigation sessions and full First Light
playthroughs remain Stage G. This stage establishes playable incorporation and
compatibility, rather than completion of M1.1.

## Review and reproduce

The portable review directory is `starfire_3d_proposal/m1_1_stage_e/`; open `index.html`
for the full report and **36 current game captures**, including labeled development,
architecture, terrain and building-catalog fixtures. Each image opens at original size.
The ZIP is `starfire_3d_proposal/m1_1_stage_e_review.zip`.

`reports/` contains this report, progress, the approved plan and maintained save contract.
`web/` is the playable export; `evidence/` holds logs, telemetry and compatibility saves.
`source/M1_working_delta.patch` contains the complete local study/A–E source delta
against the pinned M1 commit, with binary assets and a recorded base commit. It applies
to a clean archive with whitespace checking. `SHA256SUMS.json` covers every packaged file.

Activate `/workspace/.starfire-setup/activate.sh`, then run:

```sh
godot --headless --editor --path . --import
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tools/validate_data.gd
python tools/m11_stage_a_profile.py native --script tools/m11_stage_e_smoke.gd --timeout 720 --log build/stage_e/native.log --out build/stage_e/native_process.json
godot --headless --path . --export-release Web build/web/index.html
python tools/m11_stage_e_web_smoke.py
```

`?smoke=m11-stage-e` is an explicit test route using only `user://stage_e_review`.
It supplies named resource/technology/population fixtures and telemetry; ordinary
entry never creates those fixtures or review saves. Serve the included browser
export over HTTP. No new branch, commit, push, merge, tag or public deployment was
created. All work remains local and uncommitted on the existing M1 lineage.
