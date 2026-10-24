# M1.1 Stage D — saved appearance and shared geography

**Status: validated for progression on the existing M1 lineage.** The Owner authorized
Stage D with save persistence and graphics compatibility as its highest priorities.
The normal Colony planner integration remains Stage E; final artistic finish is Stage F.

## What now persists

Manual saves, turn autosaves and checkpoint saves carry an independently versioned
and checksummed appearance section. Continue, the Load screen and debrief checkpoint
recovery restore it. Planet identity includes the physical seed, generator/material
versions, type and regional parameters. Stellar appearance, architecture identity and
art-catalog versions also have a pinned contract. An owned colony's geographic anchor
stores quantized longitude, latitude convention and heading.

Anchors are created only for actual committed settlements. Hover, queued founding,
Undo, camera, visual quality, population, technologies and buildings cannot reseat
that location. Reading a save list cannot attach or modify the active appearance
session. A new/load session cancels old jobs; cache/result acceptance includes the
complete supported appearance identity and session epoch.

The same frozen sphere_fbm/1 field supplies globe maps and regional elevation,
coastline, color/material identity and relief. The regional view projects through the
saved anchor. Completed sites receive local grading, preserving every legal M1 hex
slot; neighboring blocked outcrops cannot lift a prepared footing. Terrain extends
into the surrounding landscape rather than sitting on a circular display plate.
The colony marker follows its saved location and the planet's rotation, using the
verified Godot sphere UV conversion.

The regional view now uses the shared worker/cooperative scheduler. It is still the
existing inspection study; replacing the ordinary Colony planner and completing all
city controls is Stage E. More detailed terrain artistry, materials and authored
assemblies remain the artistic finish work. These are game verification captures,
not a declaration that the final art is finished.

## Graphics compatibility

| Save/update situation | Stage D behavior |
| --- | --- |
| Original M1 save with no graphics metadata | Loads gameplay and reconstructs the original seeded globe appearance. Its deterministic colony anchor is then saved. |
| Supported saved appearance | Keeps the saved physical profile, generator/material/catalog versions and geographic anchor; current defaults do not reroll it. |
| Older graphics wrapper (v0 fixture) | Migrates names to v1 without changing profiles or anchors. |
| Future graphics with a v1 compatibility view | Displays the supported view, explains compatibility and retains the newer original graphics string exactly. |
| Future graphics with no supported view/version | Explains Strategic fallback and retains the original graphics string exactly through saving and loading. |
| Damaged optional graphics | Valid gameplay still loads; explains deterministic recovery and retains damaged original data separately from recovery metadata. |
| Unsupported future anchor or architecture | Preserves it and declines that 3D view; does not invent a replacement location or civilization. |
| Unknown graphics extensions | Remain in the save, outside the permitted renderer description. |

Gameplay remains **simulation schema 2**, with the same integer-only state,
checksum, RNG streams, balance data and golden hashes. Graphics forward compatibility
is scoped to saves whose gameplay schema M1 can load. A future simulation schema
still gets the existing too-new error.

An independently tested original M1 executable loads both the new supported and
future-graphics envelopes with the same gameplay hash. **Its old writer drops graphics
metadata if it resaves.** Exact graphics continuity through downgrade/resave requires
Stage D or a later build implementing this preservation contract; retain the original
save when using an older executable. That cannot be retrofitted into the old binary.

The [graphics save contract](M1_1_GRAPHICS_SAVE_CONTRACT.md) specifies frozen versions,
future-writer overlay merging, engine-update fixture gates and extension handling.
Future updates must retain supported implementations or perform explicit, tested
migrations. This does not claim arbitrary future engines/executables will behave
identically without maintaining that contract.

## Revalidation evidence

- **204 tests / 10,067 checks**, 38 test files; no failures. This includes the original
  gameplay/UI/golden suite and independent graphics integrity, legacy reconstruction,
  v0 migration, future opaque JSON (including fractional values), all player load
  routes, manual/automatic/checkpoint saves, commit-only anchors, unknown extensions,
  catalog/identity/architecture rejection and monotonic future-overlay merging.
- **20 native rendered checks**, no failures or engine/script errors, six captures:
  globe and anchored region before/after reload, compatible future rendering and
  unsupported-future Strategic fallback.
- **38 exported-browser checks**, no failures or browser/script errors, twelve
  captures: 19 checks each in desktop and touch-sized phone contexts. The test saves
  to an isolated review directory, waits for IndexedDB synchronization, destroys the
  page/WASM instance, opens a new page and restores the save at the same origin.
- Native, desktop browser and phone browser restore the **same appearance fingerprint,
  anchor, sampled geography/materials and gameplay checksum**. The native globe
  before/after reload PNGs match byte for byte; desktop-browser regional before/after
  reload PNGs match byte for byte. Exact CPU identity is the continuity gate; small
  camera/GPU capture differences on other views are not simulation data.
- Frozen pre-Stage-D sphere pixel fixtures remain byte-identical. Longitude seams,
  both poles, shared LOD edge positions/normals, cooperative/worker array parity and
  cancellation are exercised. All five M1 base parcel sizes and their actual trait
  and dome modifiers are tested across six solid-world types.
- **20 data tables / 328 records / 1,388 strings**, no errors or skipped checks.
- Original M1 loader proof: both envelopes return state hash
  `917e4bcb414550612cd05f01849d59d7ea8f76d7c0307d4be4fb673d4c3e8291`.

The reproducible evidence is in `build/stage_d`, `screens/m11_stage_d` and
`screens/m11_stage_d_web`. Only completed verification captures enter the review
package; failed diagnostic runs remain outside it. Test fixture paths and exact
reproduction commands are documented in [cloud setup](../M1_1_CLOUD_SETUP.md).

## Durability and performance limits

Save replacement writes and flushes a `.pending` file before renaming it over the
slot. Incomplete pending files are not offered by Continue. This protects an existing
slot from incomplete application writes; it is not a guarantee against disk failure
or loss of an unfinished browser storage transaction. Godot Web syncs asynchronously.
The browser test verifies completed IndexedDB persistence in the same origin/context;
private browsing, cleared site data and physical power loss are not certified.

Quality remains the Owner's priority. Browser generation now receives a bounded
**6 ms** allowance rather than 1 ms: the shared-field baker cost otherwise left flat
previews visible for minutes under software WebGL. Regional browser rendering uses
half resolution and disables MSAA; geography and assemblies remain the same. Native
captures retain the full-resolution viewport and MSAA. This is recorded performance
debt, not a claim of physical-device frame-rate compliance. The native capture tour
records **959,217,664 bytes (959.2 MB)** peak RSS, above the earlier 400 MB
process-memory target. Its measurement is in
`evidence/native_process.json` in the review package and includes software-GL driver
allocations and PNG readback. Full device profiling/optimization remains Stage G.

## Review delivery and scope

`starfire_3d_proposal/m1_1_stage_d/` contains a mobile-friendly gallery/report,
18 game captures, the playable local web export, verification logs, compatibility
contract and complete local source patch against M1 commit
`a160d9d334c59a2796b8c88e8eaca7f49b42c029`.
Its archive is `starfire_3d_proposal/m1_1_stage_d_review.zip`.

No new branch, commit, push, merge, tag or public deployment was created. Earlier
study and Stages A–C work remain preserved. Stage E has not been started.
