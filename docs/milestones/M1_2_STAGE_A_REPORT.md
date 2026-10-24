# M1.2 Stage A — baseline and presentation contracts

**Status: validated for the next stage on the existing M1 lineage.** This
stage records the preserved M1.1 source baseline, freezes a compatibility
fixture, and proves a transport for road and orbital presentation recipes.
It does not implement city routing, display controls, voice playback or orbit
motion.

## Preserved baseline

- Pinned gameplay baseline: `a160d9d334c59a2796b8c88e8eaca7f49b42c029`.
- The archived M1.1 writer source is the checksum-verified Stage F patch
  `M1_working_delta.patch` (SHA-256
  `bd28a72d781b0294cfad5415e832af448adacc86a11c2d4c8b315472106c1872`),
  reconstructed in a separate temporary checkout and copied with provenance
  into `tests/fixtures/visual/m12_stage_a_archived_m11/`.
- The checkout remains detached with the authorized M1.1 working delta dirty;
  no branch, commit, tag, push, release or reset was created.
- The M1.1 graphics contract remains authoritative: gameplay is simulation
  schema 2, integer-only, and appearance travels in optional strings beside
  the state checksum. The pinned original executable can read graphics but
  drops metadata when it resaves; that boundary is retained in the fixture.
- Existing `tests/fixtures/visual/appearance_v1.json` remains the frozen
  physical profile/anchor reference. M1.2 adds
  `tests/fixtures/visual/m12_stage_a_components_v1.json`, tied to the pinned
  baseline and containing deterministic road/orbit component wrappers. The
  archived-writer fixture additionally contains supported and future saves,
  exact opaque-wrapper bytes, the old `PresentationEnvelope` and
  `AppearanceProfileStore`, and the separate-checkout driver.
- The copied archived `.gd` sources are under the fixture directory's
  `.gdignore`; they remain provenance for the old writer and are excluded from
  project runtime imports and exports.

## Transport decision

Road and orbital recipes are optional entries in the appearance wrapper's
`components` map. Each entry is a separate
`starfire-hearth-presentation-component` string with its own integer version,
canonical payload and checksum. The known appearance payload and exact catalog
dictionary remain unchanged; a legacy reader never has to accept `road` or
`orbit` as catalog keys.

`PresentationEnvelope` now provides `pack_component`, `inspect_component`,
`component_raws` and `with_components`. Unknown component versions remain raw;
a component may include its own independently checked `compatibility` view.
`AppearanceProfileStore` exposes `component_status`, `component_supported`,
`component_view`, `component_raw` and `set_component`, plus filtered
`road_recipe_for(colony_id)` and `orbital_recipe_for(system_id, body_ids)`
accessors. It validates session identity before disclosure, merges only missing
collection identities from a valid overlay, and keeps authoritative records on
collisions. `upgrade_roads(recipe)` is explicit and requires a generated recipe;
it cannot silently reroll a saved city. The renderer snapshot builder was
intentionally not changed in Stage A; later stages can request these filtered
views after applying gameplay intel.

## Revalidation evidence

The Stage A transport tests pass **8 tests / 60 checks / zero failures**:

```text
godot --headless --audio-driver Dummy --path . -s tests/run_tests.gd -- --filter test_m12_stage_a_transport
8 passed, 0 failed, 60 checks, 43 files
```

The checks cover the frozen M1.1 fixture, supported road/orbit roundtrip,
known catalog isolation, gameplay checksum preservation, archived-writer
repack, no-extension metadata dropping, future component preservation,
future-component compatibility views, and identity mismatch fallback.
Existing M1.1 persistence and finish tests were also rerun:

```text
test_appearance_persistence: 13 passed, 0 failed, 77 checks
test_visual_finish:         7 passed, 0 failed, 242 checks
```

The complete repository suite then passed **233 tests / 12,210 checks / zero
failures** across 43 files. Root's standalone Stage B planner files were not
used to produce or alter the frozen Stage A writer fixture.

The archived writer was exercised by reconstructing a clean `a160d9d` checkout,
applying the verified Stage F patch, importing it with Godot 4.6.3, and running
the archived driver. That driver used the old writer's actual `bind` and
`save_fields` across an end turn, completed build/demolition, and added profile
and anchor identities. The current reader then loaded the frozen save and
verified the gameplay hash, clearing history, component wrappers and unknown
fractional wrapper extension. A second future-wrapper save verifies exact
opaque presentation bytes through the current resave path.

Project import completed with Godot 4.6.3 headless. No physical Windows or
browser gate is claimed by this stage.

## Handoff

Stage B/C/F may consume the component APIs without changing the appearance
catalog or gameplay schema. The road and orbit payload shapes in the fixture
are transport examples only; feature stages own their versioned recipe fields,
deterministic generation and filtered snapshot projection. New body/colony
identities should be added through `set_component`/overlay merging so older
authoritative profiles and anchors remain unchanged.
