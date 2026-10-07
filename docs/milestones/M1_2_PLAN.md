# M1.2 — Cities, immersive controls and living orbits

Status: Stages A–G implemented and locally revalidated. No M1.2 checkpoint
release or tag exists.
Prepared 3 October 2026 from the Owner's M1.1 desktop review; resumed 4 October.

M1.2 improves city access, keeps management available over the Immersive map,
adds desktop display controls, prepares optional character voice support, and
introduces turn-driven planetary orbits. It builds on the current M1.1 production
renderer and newer art. It does not replace that renderer with offline concepts.

Work stays on the existing M1 lineage, `claude/starfire-hearth-build-cs2vb6`.
No new branch is required. This document names a planned checkpoint, not an
already validated build, tag or release. M1.1 source changes in the working copy
must be preserved and identified separately from the desktop artifact already
uploaded to GitHub.

## Review findings and resulting scope

| Owner feedback | Current implementation | M1.2 result |
| --- | --- | --- |
| Roads look inefficient | Independent searches from one fixed hub; no shared-road or terrain cost; access ends at plot centers | A coherent shared access network with entrances, terrain-aware routing and readable junctions |
| Immersive hides too many options | Compact toolbar plus one context panel, opened on demand | Persistent essential controls and several management windows/docks over the map |
| More display and scaling choices | UI/text scales exist, but settings expose coarse steps; no desktop mode/size controls | Windowed, borderless and supported fullscreen modes; window size, monitor and clearer independent scaling controls |
| Future character voices | General sound/music playback and some character-related effects; no dialogue voice lifecycle | Optional voice cues and a dedicated playback service; dialogue works fully without clips |
| Visible orbits and movement each turn | System planets occupy fixed staggered positions; wall-clock spin is decorative | Subtle orbit paths and calendar-based orbital positions, reconstructed correctly after screen changes and loads |

Quality remains the priority. Record performance costs and temporary overruns;
correctness, usable controls, intel filtering and save continuity remain gates.

## Architectural boundaries

Keep game rules, integer simulation RNG, planet IDs, orbit-slot ordering,
construction legality, adjacency bonuses and order submission unchanged.
Roads and planetary motion are presentation in this checkpoint. They do not
create a traffic simulation, alter travel times or introduce orbital combat rules.

Continue using `WorldViewController` and its persistent renderer host. Both
Command and Immersive layouts submit the same existing orders. The renderer sees
only filtered visual snapshots, never the raw campaign state. Display/window
preferences and workspace layouts are device-local; appearance recipes belong
to the campaign's presentation envelope. Voice availability belongs to assets.

Proposed new services below are implementation locations, not existing files.
Public APIs and exact filenames will be finalized in Stage A.

## 1. City roads: plan a network rather than separate trails

Primary integration points:
`ui/world/terrain/regional_access_routes.gd`,
`ui/world/terrain/region_terrain_generator.gd`, and
`ui/world/colony_renderer.gd`.

Replace the fixed-hub, independent-path approach with a deterministic network
planner. Its input includes committed building footprints, entrance positions,
landmark gateways, prepared groundworks, terrain samples and a versioned road
recipe. Faction/building kits supply entrance metadata; a stable geometric
fallback handles older models without entrance sockets.

1. Define valid street corridors and access points outside building footprints.
   Use the actual supported surface on island/platform worlds rather than
   treating underlying ocean as an automatic rejection of a valid platform.
2. Select a coherent trunk and connect required entrances to it. Prefer shared
   segments using an A* terrain cost and existing-network reuse discount;
   choose a deterministic connection order and tie-breaking rules. A spanning
   network heuristic is sufficient; do not claim global optimality.
3. Penalize unnecessary length, sharp turns and steep grades. Reject building
   intersections, unsupported water crossings and cliffs. Initially use roads
   on supported ground/platforms; decorative bridges need an explicit supported
   recipe rather than silently crossing any obstacle.
4. Merge shared edges, snap junctions, smooth within the original clearance and
   grade limits, and stop at entrances. Render one coherent network with road
   shoulders/junctions instead of overlapping strips.
5. Cache by terrain/anchor, recipe, committed footprints and entrance revision.
   Replan on relevant construction/demolition changes, not every frame. Stable
   tie-breaking and reuse should limit unnecessary changes as the city grows.

The planner returns connectivity, total length/cost and explicit unreachable
entrances. It must not silently omit a failed route. A bounded fallback and
diagnostic identify the gap while leaving legal gameplay construction usable.
Road grading must not overwrite saved geographic anchors or committed clearings.
Citizen/vehicle decoration follows the merged network, not duplicate hub routes.

Validation uses representative sparse/dense cities, blocked plots, landmarks,
slopes, platforms, demolition and each architecture kit. Check that required
entrances connect where a feasible corridor exists, meshes do not cross
footprints, junctions do not overlap and the result is deterministic after load.
Compare route length, duplicate segments and screenshots against M1.1 fixtures;
do not enforce an arbitrary percentage reduction on every constrained map.

## 2. Immersive: the map with management windows

Primary integration points: `ui/world/immersive_world_view.gd`,
`ui/screens/game/game_screen.gd`, the existing colony/system controls and a
proposed `ui/world/immersive_workspace.gd`.

Keep the Command/Immersive toggle. Immersive starts with a slim resource/turn
HUD, navigation/management toolbar, current selection inspector and a compact
queue/status dock. Management remains immediately discoverable while most of
the scene stays visible.

Introduce reusable modeless windows/docks for construction, jobs, governor,
shipyard/fleet, research, market, ordinances and objectives as applicable to the
current screen and intel. Reuse their existing models and command handlers.
Several useful windows can coexist on desktop. Provide move, resize, minimize,
pin/dock, close and Reset workspace controls. Selection can update a pinned
inspector without closing the queue or management window.

Persist workspace geometry per device, mode and viewport class. Clamp windows
to reachable bounds after display or scale changes. Reserve essential HUD and
turn controls; pointer input over a window must not issue map commands beneath
it. Keyboard focus, controller navigation where supported, and Esc closing the
topmost relevant window need explicit handling. Actual confirmation/story
decisions can remain modal.

At small widths, use compact docks/tabbed bottom sheets with the same actions;
do not attempt to fit unlimited floating desktop windows on a phone. Validate
every action's availability in both layouts, including long translated text and
large text scaling. The map remains visible whenever a management panel can
reasonably coexist with it.

## 3. Display, graphics and scaling

Primary integration points: `app/settings.gd`, `app/layout.gd`,
`ui/screens/flow/settings_screen.gd`, `project.godot`, and a proposed
`app/display_settings.gd` that owns native window operations.

Desktop controls:

- Windowed/resizable, borderless desktop, and fullscreen modes supported by the
  export/backend. Expose exclusive fullscreen only when actually supported.
- Monitor selection, sensible window-size presets, optional width/height,
  maximize/restore and remembered last valid window rectangle.
- Apply / Keep / Revert with a short countdown for mode/monitor/size changes.
  Recover safe defaults after a crash, missing monitor or offscreen rectangle.
- Separate UI scale and text scale with current values, fine 5% steps and reset
  controls. Preserve the existing supported ranges initially; increase them
  only after layout validation. Scaling must not clip management or turn controls.
- Clear quality controls for render resolution scale, VSync/frame cap and
  anti-aliasing where supported, alongside the existing appearance/quality and
  reduced-motion choices. Label render scale independently of window size.
- Orbit visibility/opacity, with selected-orbit emphasis and reduced-motion
  behavior consistent across quality levels.

Capability detection governs which controls appear. Browser fullscreen needs
a user gesture and browser support; browser tabs do not offer native monitor
selection or arbitrary desktop window modes. Validate native Windows behavior
on Windows: a Linux run or successful export is not evidence of that behavior.

Keep settings in `user://settings.cfg` (and existing browser persistence where
needed), outside game saves. Add versioned sections with defaults for old files,
sanitization and retention of unknown settings on resave. Avoid the current
pattern of rebuilding a configuration that discards future fields. Reflow the
workspace when scale, DPI or viewport changes without rebuilding campaign state.

## 4. Optional character voice support

Primary integration points: `app/audio.gd`, `app/asset_ids.gd`,
`ui/screens/game/event_overlay.gd`, asset intake validation, and proposed
`app/voice_service.gd` plus a presentation-side voice-cue registry.

Create stable utterance IDs mapped to speaker, localized text key, story
chain/step or presentation event, locale, optional audio entry and delivery
status. Existing character IDs include `archivist_sola`, `steward_varga`,
`captain_brandt`, `director_hale`, `speaker_of_seven` and `mother_rook`.
Do not use text itself as an unstable audio ID, and do not modify simulation
event data/checksums just to attach optional voice.

Add a Voice audio bus, volume/mute and a scoped playback lifecycle. A dialogue
overlay can request a cue; missing, unsupported, malformed or unavailable clips
return immediately and silently. Do not substitute synthesized effect blips for
missing speech. Written dialogue/subtitles remain available and choices are
never gated by audio completion or successful loading.

Stop obsolete speech when the overlay closes, a new cue replaces it, a game
loads or the session changes. Avoid replay on ordinary UI refresh; restore any
music ducking reliably. Browser autoplay restrictions must leave text and
controls functional. Use a separate cue registry or explicitly extend the
strict asset schema and intake tooling; arbitrary voice fields currently fail
manifest validation.

This checkpoint supplies hooks and a small test fixture, not final performances,
casting, generated character voices or lip synchronization. Verify absent
assets, invalid files, mute, replacement, load/close cancellation and localization
fallback with the same functional dialogue outcomes.

## 5. Space: subtle orbit paths and turn-driven motion

Primary integration points: `ui/visual3d/m1_system_renderer.gd`,
`ui/visual3d/m1_visual_snapshot.gd`, the world snapshot builder,
`ui/world/appearance_profile_store.gd`, and a proposed pure orbital-layout service.

The campaign calendar defines one turn as one month. Planet `orbit` is currently
an integer ordering slot, not a distance in AU; stars do not currently supply a
physical mass. Generate a stable, versioned presentation recipe from system/body
identity, appearance seed and orbit rank. Include quantized semi-major distance,
effective stellar mass, initial phase, epoch turn and period in integer units
accepted by the canonical presentation format. Use authored values when available.
Do not reroll phase on each screen entry.

Proposed first version: circular, mostly coplanar orbits around the system's
star/effective barycenter. Stellar-family mass estimates are illustrative;
binary systems use a documented effective-mass approximation. Full n-body
physics, accurate binary stability and eccentric Kepler solvers are later work.

Use a Kepler-inspired period with solar units:

```text
period_years = sqrt(distance_AU^3 / stellar_mass_solar)
period_turns = 12 * period_years
phase(T) = phase_at_epoch + 2*pi*(T - epoch_turn)/period_turns
```

For a solar-mass star, 1 AU takes about 12 turns and 4 AU about 96 turns: roughly
30 degrees versus 3.75 degrees per turn. These are illustrative examples, not
promises that existing orbit slot 1 represents 1 AU. Compress display distances
to fit the scene while retaining period ratios based on physical recipe distances.
Start with the actual one-month calendar; test very short and long periods and
sampling aliases. If art review requires a different visual time multiplier,
version one coherent system-wide multiplier explicitly; do not independently
force a minimum angular step on each planet or change the campaign calendar.

The resolved campaign turn is the authoritative clock. The filtered snapshot
includes the permitted turn/orbital recipe for disclosed bodies. Calculate final
positions as a pure function of that clock even when the system was not rendered
for many turns. No offscreen renderer or accumulated wall-clock ticker is needed.

On End Turn while viewing a system, interpolate the previously displayed phase
to the new resolved phase briefly and visibly. Use unwrapped angular travel;
avoid wrapping a full revolution into zero travel or incorrectly choosing the
shortest arc. If another turn resolves during animation, retarget from the
displayed position and settle to the authoritative result. Reduced motion snaps
to that result. Load, undo and screen re-entry reconstruct the correct position
without replaying every missed turn. Decorative surface rotation remains separate.

Draw thin, low-contrast orbit curves, stronger for the selected body, with
appropriate distance fading and suppression in close-up. They must not obscure
planet textures or intercept clicks. Follow moving bodies with their colony
markers, associated ship/outpost presentation offsets and focused camera target.
Keep gameplay destinations and selection IDs stable. Validate the Strategic
fallback against the same orbital recipe or a clearly documented static schematic.

Intel filtering remains mandatory: undisclosed systems/bodies do not gain orbit
lines or identifying data through this feature. New snapshot revisions must
change on relevant turn changes even if another screen was open.

## Compatibility contract and migration

Extend the [M1.1 graphics save contract](M1_1_GRAPHICS_SAVE_CONTRACT.md), including
real older-writer roundtrips. Do not advertise arbitrary future binaries as
understood. The guarantee is supported older looks, safe fallback for unsupported
future recipes, retention of their authority and restoration on return to a
supporting build.

The current appearance store accepts exact known catalog dictionaries. Simply
adding road/orbit keys to that dictionary would invalidate older readers.
Use separately versioned presentation components for road and orbital recipes,
with a supported compatibility view and opaque preservation where required.
Stage A must prove the chosen envelope/component design using an archived M1.1
writer before feature implementation relies on it. Extend component merging for
bodies/colonies created while playing an older build; unknown authority must not
be overwritten by a legacy fallback. Avoid a gameplay schema bump for this work.

Fresh M1.2 games use the new road/orbit recipes. Existing saves initially retain
their supported appearance and offer an explicit presentation update for roads
and the orbital layout. That update preserves geography, terrain seed, surface
textures, anchors, building identities and clearing history. Renderer-generated
meshes/caches are rebuildable and are not serialized as campaign authority.

The compatibility matrix must include:

- Original M1 save into M1.2; M1.1 save into M1.2 with and without visual upgrade.
- M1.2 save/load and browser restart; same orbit phase at the same resolved turn.
- M1.2 to archived M1.1, play/build/demolish/end turns and resave, then return to
  M1.2: preserved newer recipes, merged additions and current-turn positions.
- Unsupported future component version, unknown fields, invalid/truncated data,
  legacy missing metadata and session changes: safe fallback and preserved valid
  opaque authority, without contaminating the next campaign.
- Different quality, reduced motion and Command/Immersive choices: unchanged
  campaign checksums and appearance identity.

Original pre-Stage-D M1 executables drop presentation metadata on resave. M1.2
cannot retroactively repair that writer; exact downgrade/resave continuity is
bounded by the existing graphics transport contract. Document that limit.

## Delivery stages and revalidation

Each stage ends with its relevant checks, fresh game captures and a concise
phone-readable report here. Report completed behavior, evidence, measured costs
and remaining issues before advancing. Keep comparisons on the current/newer
M1.1 art. Do not represent exports as tested on physical target hardware.

| Stage | Work | Exit evidence |
| --- | --- | --- |
| A — Baseline and contracts | Preserve/identify reviewed M1.1 source and artifact; capture road/UI fixtures; define settings, voice and presentation APIs; prove compatibility approach | Repeatable baseline, frozen older writer, proposed component roundtrip and no simulation changes |
| B — City network | Shared terrain-aware routes, entrances, junctions, growth/demolition integration and versioned recipe | Connectivity/clearance/grade/determinism checks; old/new save evidence; fresh representative city comparisons |
| C — Display and scaling | Native mode/size/monitor service, apply/revert, settings retention, fine UI/text scaling and supported graphics choices | Invalid-setting recovery, monitor/size/scale matrix; browser capability checks; Windows runtime gate explicitly recorded |
| D — Immersive workspace | Persistent HUD, reusable simultaneous windows/docks, action parity, focus/input and responsive layout | Real construction/management/space orders; no click-through; resize/scale/load workspace recovery; desktop and phone captures |
| E — Voice capacity | Optional registry, Voice bus, overlay hooks, lifecycle and missing-asset behavior | Dialogue completes identically without clips; fixture playback/cancellation/mute/localization and asset intake checks |
| F — Living orbital map | Saved orbital recipes, filtered turn clock, orbit paths, interpolation, moving attachments/camera and old-save upgrade | Period/turn/offscreen/load/undo checks; intel tests; older-writer roundtrip with new bodies; visible motion captures |
| G — M1.2 checkpoint | Integrated campaign, complete graphics compatibility matrix, platform smoke, art review package and exports | Production-screen regression evidence, measured performance, known limitations, source/build provenance and downloadable review artifact |

Display work precedes workspace finishing so dock/window behavior can be checked
against actual mode, size and scaling controls. Orbital work comes after the
compatibility design and UI/settings foundation. Save continuity is revalidated
at the feature stages, not postponed until Stage G.

## Completion and open gates

M1.2 acceptance requires a sensible city network, management usable over the
Immersive scene, reliable display recovery, dialogue that never depends on voice
assets, and orbit positions that survive turns, navigation, updates and saves.
Capture performance by subsystem and retain quality-first optimization debt.
Automatic WebGL recovery, hosted CI and physical-device/Windows playtest gaps
already recorded in M1.1 remain explicit unless this checkpoint closes them
with evidence. Final art/playtest acceptance belongs to the Owner.

This architecture document creates no executable or release. Implementation
approval and stage evidence are tracked separately. Stage G evidence and remaining
acceptance gates are tracked in [M1.2 progress](M1_2_PROGRESS.md) and the
[integrated checkpoint report](M1_2_STAGE_G_REPORT.md).
