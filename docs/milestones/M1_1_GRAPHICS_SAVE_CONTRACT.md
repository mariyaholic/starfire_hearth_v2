# M1.1 graphics save compatibility contract

Stage D separates authoritative gameplay from persistent appearance. Future graphics
updates must implement this contract, retain the versioned implementations they claim
to support and pass the frozen fixtures before accepting old saves.

## Save boundary

Gameplay remains `starfire-hearth-save`, simulation schema **2**. Its state dictionary,
integer-only validation, RNG streams and SHA-256 checksum are unchanged. Two optional
**strings**, `presentation` and `presentation_overlay`, live beside that dictionary.
A graphics string contains this independently checked wrapper:

```json
{"format":"starfire-hearth-appearance","version":1,"payload":"{...}","checksum":"sha256 of exact payload UTF-8"}
```

The version-1 payload is canonical integer-only JSON containing:

- Session identity: scenario, game seed and viewer ID.
- Per-permitted-world profiles: stable ID, source/physical seed, generator name and
  version, material version, kind, sea level and regional projection/relief parameters.
- Per-committed-owned-colony anchors: planet ID, version, longitude/colatitude in
  millionths, heading in thousandths of a degree, and land/island/platform/dome mode.
- Stellar spectral appearance, architecture identity and independently pinned
  planet/stellar/civilian/city catalog versions.

Meshes, textures, camera positions, visual-clock phase and quality settings are not
stored in GameState. GPU resources are rebuilt from supported saved profiles. Camera
and animation reset are allowed; changing saved geography is not.

Unknown wrapper extensions may have future numeric types because the whole wrapper
is a string. Unknown version-1 payload extensions remain integer-only. Introducing
an incompatible payload representation requires a new wrapper version. A future
wrapper may carry arbitrary JSON, including fractional values, inside its payload
string without weakening simulation validation.

## Read and write policy

| Input graphics | Read policy | Resave policy |
| --- | --- | --- |
| Missing original M1 metadata | Reconstruct the existing seed-based sphere_fbm/1 appearance; choose an anchor deterministically | Write complete version-1 metadata |
| Supported version 1 | Render its saved profile and anchor | Keep physical values, unknown extensions and supported wrapper extensions |
| Supported version 2 (Stage F) | Render the pinned finish; merge valid older-writer additions | Retain authoritative profiles/anchors and include an independently checked version-1 view |
| Version 0 | Rename worlds/regions to profiles/anchors | Write version 1; retain physical values and anchors |
| Bad graphics checksum or malformed optional field | Load valid gameplay, explain deterministic fallback | Retain the original damaged graphics string; save recovery data separately |
| Future wrapper with valid version-1 compatibility view | Render that view and explain compatibility | Preserve the entire newer original string byte for byte; write understood additions into an overlay |
| Future wrapper without compatible view | Explain Strategic fallback | Preserve original string byte for byte; retain the fallback flag so reload cannot reroll the world |
| Unsupported generator, material, catalog or anchor version | Use explained fallback for the affected view | Preserve the unsupported values; never call version 1 to imitate an unknown generator |
| Future simulation schema | Existing M1 too-new error | No load/resave; graphics support does not grant simulation compatibility |

All Continue, Load and debrief-checkpoint paths carry both strings. Reading a save
list does not attach it to the active session. A new game/load resets the session epoch
and cancels old generation; late results also require the full appearance identity.
Manual, automatic and checkpoint saves use the same appearance snapshot. Save writes
flush a `.pending` file before renaming it over the slot; pending files are not offered
by Continue. This protects the previous slot from incomplete writes, not disk failure
or browser power loss.

Godot Web commits its filesystem to IndexedDB asynchronously. The browser test waits
for that transaction before destroying the page/WASM instance and opening a new page.
Clearing site data, private browsing, an unavailable persistent filesystem, closing
a tab before the transaction finishes or changing the hosting origin may lose/access
different local saves. Browser durability is scoped to the same origin and storage.

## Versioned generation and updates

The frozen sphere_fbm/1 field now supplies both globe pixels and regional terrain.
Original M1 saves retain their existing source seed; new games use a separate
appearance namespace with stable world IDs, so repeated/zero source seeds produce
unique new profiles. The initial anchor samples a fixed bounded candidate set and
is committed only after actual colony founding. Population, technology, districts,
queues, quality, camera and hover cannot move it. Original duplicate-seed worlds
retain their original coincident texture; importing an old save is not a reroll.

Regional terrain projects the shared field through a stable tangent basis, including
poles and longitude seams. Local grading supports completed sites without changing
M1 parcel legality. Shared edge positions/normals are sampled independently of mesh
resolution. Godot SphereMesh uses a different UV axis convention; the colony marker
uses the tested conversion and follows globe rotation.

For a future update:

1. Add a new generator/material/catalog implementation with a distinct version.
   Keep old supported implementations and dispatch from saved versions. New defaults
   affect newly created profiles, never silently overwrite existing identities.
2. Run `surface_v1.json` pixel fixtures, `appearance_v1.json` profile/anchor fixtures,
   all save/migration/forward-payload tests and native/browser continuity checks.
   The current field uses Godot FastNoiseLite; changing the engine/noise library must
   pass those fixtures or preserve a compatible implementation. This is a maintained
   compatibility guarantee, not a promise that arbitrary future engines are identical.
3. When an older build adds identities through a compatible view, the newer writer
   consumes the overlay using `AppearanceProfileStore.merge_additions`: the newer
   authoritative profile/anchor wins on collisions; only missing valid identities
   are added. Identity mismatch prevents cross-session contamination. Rendering-only
   compatibility representations never replace newer authoritative geography.
4. Preserve extensions on disk; pass only the supported public physical fields to
   renderers. Unknown extensions are not a source of intel or geometry requests.
5. Any intentional conversion of an existing world must be an explicit, tested
   graphics migration, with stable geographic identity or a clearly reviewed change.

## Older executable boundary

The pinned original M1 executable at `a160d9d...` successfully loads both supported
and future graphics strings and returns the same gameplay hash. Its existing writer
has no preservation behavior and **drops graphics metadata if it resaves**. Stage D
cannot retrofit that executable. Exact appearance continuity through downgrade and
resave requires a build implementing this transport contract; keep the original save
when using an older M1 executable. Stage D and subsequent conforming builds preserve
unknown future graphics payloads rather than discarding them.


## Stage E additions: city catalog and groundworks

Stage E made city catalog 2 and architecture kit 2 the default for new games. Catalog 1 and
kit 1 remain implemented; existing saves retain them. Version 2 completes district
tier variants and does not change planet/stellar generation, physical profiles,
anchors, civilian catalog or gameplay schemas. There is no automatic city-kit
conversion. Future art migrations must remain explicit and tested.

Optional `groundworks: {version: 1, sites: {colony_id: [slot, ...]}}` stores sorted,
committed completed footprints. It is presentation data, not slot legality or a
simulation road/production rule. It survives demolition and saves. Preview and
queued footprints are temporary masks only. Missing history reconstructs current
completed sites; prior demolitions cannot be reconstructed from original M1 saves.
Unknown future groundworks versions are preserved but not interpreted. Groundworks
additions merge monotonically only between understood versions; newer unknown
representations retain authority. Renderer snapshots receive only bounded canonical
indices for the owned colony, never arbitrary extensions.

An understood original compatibility view takes precedence over an older fallback
overlay when a newer renderer can display it again. Only valid additions merge into
that authoritative view. Stage E was tested against the checksum-verified archived
Stage D writer: catalog 1 keeps optional clearing data, catalog 2 gets preserving
fallback, and both return to the same saved geography/history in Stage E. This does
not alter the original M1 writer boundary above.

## Stage F: finished catalogs and downgrade play

New games pin `{planet_material: 2, stellar_material: 2, civilian_kit: 2, city_kit: 3}`
and architecture kit 3. Old catalog 1 and Stage E catalog 2 remain implemented.
The planet field, map schema, profiles, quantized anchors and groundworks remain
version 1. GPU material catalogs describe the finish separately from physical maps.
The **Use new visual finish** action updates supported old catalogs explicitly;
it does not reroll geography, change gameplay or discard extensions. Unsupported
opaque envelopes cannot be converted by that action.

Catalog 3 saves use graphics transport version 2. Its canonical payload retains
the same physical representation and adds a separately checked version-1
`compatibility` string in the wrapper. That view pins the Stage E catalog and kit
2 with the identical profiles, anchors and clearing history. Stage E's existing
reader recognizes version 2 as future, displays this supported view and preserves
the entire original version-2 string when resaving. New understood presentation
history is written to its version-1 overlay. F's reader merges that overlay even
when it understands the original version-2 payload directly. Older fallback
identities never replace newer authoritative profiles or anchors.

The actual archived Stage E source was tested with catalogs 1, 2 and 3. The catalog
3 case additionally completes and demolishes a new parcel in a named old-writer
fixture. The final gameplay state returns to its original hash; only the clearing
history remains. That clearing survives E's resave and F's return alongside the
exact authoritative profiles and anchors. This exercises a history item that
cannot be reconstructed from the final gameplay state.

Version-0/1 fixtures and writes of old supported catalogs stay version 1. Unknown
wrappers above version 2, unknown generators and future groundworks still follow
the preserving-fallback policy. The original M1 writer boundary remains unchanged.
