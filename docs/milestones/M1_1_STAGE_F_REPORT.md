# M1.1 Stage F — art and responsive finish

Stage F is implemented and revalidated on the existing M1 lineage
(`a160d9d334c59a2796b8c88e8eaca7f49b42c029`), ready for Owner art review.
The new materials and authored parts run in the ordinary Galaxy/System/Colony
views. Owner acceptance of the artistic finish remains open; passing tests do
not establish that the reference images meet the agreed realism/texture target.
Stage G has not begun.

## What changed in the game

Ember's buildings now use concrete/composite shells, metal frames, recessed
panels, roughness variation, bevels, servicing equipment and inhabited dusk
lighting. Ark Hull keeps a spacecraft coating with repaired plates, glazing and
access hardware. Farms, industry, research, power, mining and housing retain their
actual three gameplay tiers and get functional finishing details. All fifteen
M1 building IDs have finished assemblies. Spaceport, civic, market and archive
models have their own equipment rather than a shared color change.

Meridian and Vael have distinct district proportions, surface/trim profiles and
authored entry/service/signal exemplars across the six functions and three tiers.
These are reusable design profiles, not a claim that their full foreign building
libraries are complete or that hidden foreign cities are visible in First Light.
Those libraries, pirate cities and combat assets remain outside this checkpoint.

Three civilian hulls are actual Blender GLBs: probe sensor/bus/solar equipment,
construction cargo/crane/bridge and colony pressure modules/spine/arrays. Each has
three independently exported geometry LODs, selected in System overview/focus.
Outposts retain the existing modular geometry and receive the new PBR assignments;
they are not newly authored standalone outpost GLBs.

Terrain uses tileable soil/rock maps, world-space macro/micro detail and slope
strata. Foliage uses folded, pitched leaf geometry with gaps, veins and shared
wind; it replaces opaque study crowns. Planet materials separate water/land
roughness, specular and normal depth without changing the saved physical maps.
Stellar finish adds photosphere/granule/limb/temperature variation to the seven
supported families. The belt uses textured stone with the same deterministic
rock positions. Unknown intel still uses its neutral marker path. Existing
interactive space background, permitted-body selection and normal inspectors
remain integrated. There is no circular city plate.

## Asset source and runtime conventions

`tools/art/build_finish_v1.py` is the deterministic Blender 4.3.2 source, seed
64133. The retained `.blend` contains the actual high/low recessed-panel/rivet
trim bake scene; the script reconstructs the shared parts and hulls. It is not
a saved full-city Blender composition. No external texture/art downloads are used.

Ten GLBs include the shared 21-mesh part set and nine civilian exports. Geometry
uses metres, +Y up, documented assembly pivots, UV0, normals and tangents; hull role
prefixes map to explicit runtime materials. Shared parts have three resolutions
used by hero assemblies. Hull triangle counts decrease from 3,104/3,952/8,700
near to 584/992/2,516 far. Shared parts total 6,140 triangles across all three LODs.

Twenty PNGs supply six 512×512 albedo/normal/roughness sets and a 1024×1024
high-to-low trim normal/AO pair. Albedo is sampled as sRGB; roughness, OpenGL tangent
normals and AO are linear. AO remains independently adjustable. Material-role and
solar-cell masks are assembly/shader assignments, not separately baked mask PNGs.
Godot mip generation and all GLB/import/checksum/mapping checks pass the 367-check
asset audit. GLBs total 1.77 MB; PNG maps total 6.43 MB before runtime packing.

This review retains lossless texture storage with mips. A high-quality compressed
texture trial stalled software-GL validation; target-GPU compression is carried
to Stage G under the Owner's quality-first instruction. That platform/import
acceptance item is still pending. This is an integrated reference finish for
art review, not a promise that every close-view pixel is photographically realistic.

## Controls and small screens

Normal city controls expose Dusk and Parcel outlines alongside Pause, reset,
Strategic and quality. Hiding parcel outlines retains visible blocked outcrops
and their canonical hit bounds. Adaptive overview fits actual elevated parcels
and landmarks; the ice-region framing no longer leaves the city near the top
edge. Standard city quality is full resolution with 2× MSAA, including Web.
Low and conservative Auto web/compact profiles use half resolution without MSAA.
Quality changes do not change physical profiles, anchors, slot legality or hashes.

City and System support keyboard selection/reset/zoom and touch orbit/pinch.
System arrow keys follow the sorted permitted-body set and Home returns to
overview. Pinch release does not select a body/parcel. Shared water, leaves,
steam, routes and space motion respect Pause, reduced motion and modal blocking.
High contrast refreshes the active selection outline immediately.

Resource strips show only complete chips that fit, on wide and compact layouts.
More always exposes every resource, Noise and date. At 200% text on narrow portrait
there may be no chip that fits; the complete values remain in the accessible
drawer. Portrait navigation retains the current icon, navigation drawer, Undo and
End Turn. The drawer includes views removed from the tab bar. Colony statistics
cap their minimum width and wrap instead of widening the screen. PC, landscape
touch and 390-dp portrait structural checks pass at 100% and 200% text.

## Saves and graphics updates

New games pin planet/stellar/civilian finish 2 and city/architecture kit 3. The
two previous catalogs remain implemented. Opening an old supported save retains
its saved look. **Use new visual finish** upgrades it explicitly and retains
profiles, seeds, anchors, committed clearings, identity and unknown extensions.
Unsupported opaque envelopes cannot be upgraded by that action. Physical field,
map/profile schema and groundworks remain version 1; M1 gameplay stays schema 2.
Content and golden simulation hashes were not rebaselined.

Catalog 3 saves use graphics wrapper version 2 with an independently checked
version-1 Stage E compatibility view. E renders its known kit 2, preserves the
entire original F wrapper byte-for-byte and writes valid new presentation history
to its overlay. F merges those additions even when it directly understands the
original payload. Authoritative profiles and anchors win collisions.

The checksum-verified actual archived E source read/resaved catalogs 1, 2 and 3.
For catalog 3 it completed and then demolished a previously free parcel: final
GameState returned to its original hash, while the clearing existed only in
graphics history. F recovered that new clearing, the saved finish and exact
physical identity. This is stronger than reconstructing completed buildings from
the final state. The roundtrip passed 27 checks. Compatibility is scoped to the
tested writers/representations, not an unlimited promise for every future update.

Original pinned M1 still drops graphics metadata when it resaves. Existing D
fallback behavior preserves future originals; the new-play clearing test here
uses the latest prior E writer and its supported compatibility view. Keep the
original save when using a writer outside this contract. IndexedDB tests cover
completed sync and same-origin page replacement, not power-loss durability.
See the maintained [graphics save contract](M1_1_GRAPHICS_SAVE_CONTRACT.md).

## Revalidation evidence

| Check | Result | Review evidence |
| --- | --- | --- |
| Full gameplay/UI/save/golden suite | **216 tests / 11,918 checks, zero failures** | `evidence/tests.log` |
| Content | **20 tables / 328 records / 1,393 strings, zero errors/skips** | `evidence/data.log` |
| Asset/import/provenance audit | **367 checks, zero failures** | `evidence/asset_audit.json` |
| Native art, planner, layout and persistence tour | **290 checks / 55 captures, zero failures** | `native/verification.json`, `evidence/native.log` |
| Material bindings, spaceport/outpost, Pause/high contrast and portrait controls | **119 checks / 5 captures, zero failures** | `details/verification.json`, `evidence/details.log` |
| Actual non-threaded desktop/touch Web export | **336 checks / 20 captures, zero errors/failures** | `browser/verification.json`, `evidence/web.log` |
| Full-resolution Web Standard quality | **7 checks / 1 capture, zero errors/failures** | `browser/quality_verification.json`, `evidence/web_quality.log` |
| Actual older E writer and F restoration | **9 + 18 checks, zero failures** | `evidence/compatibility/` |
| Native/Web identity and gameplay comparison | **25 checks, zero failures** | `evidence/cross_platform_continuity.json` |
| Mobile gallery, original PNGs, ZIP/SHA and clean source patch | Verified separately | `evidence/artifact_validation.json` |

The construction tours use controlled resources/technology/population and then
invoke real Build, Move Up, Rush, Cancel, Undo, Upgrade and Demolish commands.
Strategic and 3D reach the same simulation result and anchor; each actual turn
matches pure M1 replay. The explicit finish button preserves gameplay/geography
in native and Web. Browser tests use real canvas clicks/taps, keyboard and two-finger
touch emulation, then destroy the page/WASM instance and restore the manual save.
The main browser tour uses Low; the separate Standard check renders full resolution
and retains gameplay, graphics identity, anchor and prepared sites after quality switch.
Final native logs have no engine/script errors; the unsupported Xvfb V-Sync warning
remains. These checks do not replace the full First Light campaign or real devices.

## Measured cost and optimization debt

The export is **54.70 MB gzip**, **7.44 MB** above
pinned M1 and **6.58 MB** above E. It stays below the 150 MB total
and 25 MB incremental-art targets. Native full-tour peak RSS is **1176.8 MB**,
including software GL and image readback, exceeding the 400 MB target.

| Functional-tour window | Wall interval p95 | Retained cooperative slice p95 | Largest retained layer patch |
| --- | --- | --- | --- |
| Native saved city | 830.314 ms | — ms | 269.57 ms |
| desktop saved city | 2109.6 ms | 24.9 ms | 392.5 ms |
| desktop restored city | 183.7 ms | 33.4 ms | 393.1 ms |
| phone saved city | 177.8 ms | 25.4 ms | 386.0 ms |
| phone restored city | 209.7 ms | 30.2 ms | 399.7 ms |
| Phone Standard quality | 147.2 ms | 30.5 ms | 359.5 ms |

These wall intervals are last-512-frame mixed tour windows including capture,
generation, layout and telemetry, not steady-state GPU FPS. Engine deltas are
recorded separately and may be smoothed/clamped. Native measurements use Mesa
software GL; Web uses software Chromium/touch emulation. Neither certifies physical
Android/iOS GPU performance. Regional CPU arrays/water estimates exclude driver
and GPU allocations. The regional cooperative allowance remains 18 ms against
the planned 2 ms target; space retains 6 ms. Temporary overruns remain authorized.

Stage G must address target-GPU texture compression, rendering/memory/job profiling,
retained terrain/root swaps and upload bursts, the 100-switch lifecycle run,
actual Android/iOS devices, Windows/Linux/Web release matrix and full campaign
playthroughs. No balance changes were used to compensate for rendering cost.
Owner art/playtest acceptance remains open. The modular silhouettes, ground/foliage
density and close-view material/weathering balance are visible in the reference set
for that review; technical counts do not settle those artistic decisions.

## Review package

`starfire_3d_proposal/m1_1_stage_f/index.html` is a phone-readable report/gallery with
**81 fresh current-game captures**, including labeled tiers, civilizations,
all surface/star families, day/dusk, normal controls and portrait/resource views.
One freshly captured retained-E look is separated as an optional comparison.
Every image opens at original PNG size. The smaller `m1_1_stage_f_images.zip`
contains **20 current 1920×1080 art images** and excludes the retained old look.
The full `m1_1_stage_f_review.zip` also includes the playable HTTP-served Web build,
complete local study/A–F binary source patch, Blender source, setup/reproduction
instructions, evidence, archived E source delta/helper and SHA256 inventory.

No new branch, commit, push, merge, tag or public deployment was created.
All work remains local and uncommitted on the existing M1 checkout. Stage F's
implementation/revalidation is ready for review; Stage G awaits the next instruction.
