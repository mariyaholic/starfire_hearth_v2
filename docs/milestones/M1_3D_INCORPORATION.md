# M1 3D incorporation study

Based on the existing `claude/starfire-hearth-build-cs2vb6` branch at `a160d9d`.
The study runs its Godot 4.7.2 application, data, commands and turn processor.
No branch was created. The checkout at `/workspace/starfire_hearth_m1` is detached
at that M1 commit, preserving the earlier studies in their original workspace.
Changes are local and uncommitted; the remote branch and deployment are untouched.

## Concrete incorporation

Begin First Light. The existing **Colony → Planner → Inspect city in 3D** and
**System → Inspect system in 3D** controls open an optional inspection overlay.
The overlay keeps its renderer alive while M1's normal screen rebuilds after orders.
Its inspector reuses M1's own controls, explanations, validation and command bus.
Closing it returns to the current game. The standard views remain available.

| M1 component | Study behavior | Proposed production placement |
| --- | --- | --- |
| System view | Select real planets and owned ships; focus seeded surfaces; issue the existing survey order | Persistent 3D system viewport beside the existing planet inspector |
| Colony planner | Select M1's actual slots; choose districts/buildings; preview, build, cancel, upgrade or demolish through existing controls | 3D terrain viewport as an alternative to the planner's hex illustration |
| Construction | Blue queued geometry, green permitted placement preview, red refused preview; completed geometry follows `Game.view()` | Keep construction and completed content as separate presentation layers |
| Development | Each actual district tier controls its assembly; buildings come from the actual catalog | Add richer authored tier/building variants without changing rules |
| Civilization | Owned colony's faction selects Ember/Meridian/Vael kit proportions and shapes | Expand faction-specific building libraries; no appearance-only ownership swaps |
| Intel | Unknown systems have no render description; unsurveyed planets omit traits/sites; foreign cities and ships are excluded | Feed future foreign views from an explicit permitted snapshot, not live state |

The city uses **HexGrid.coords** at the actual slot count. This fixes the earlier
concept's incompatible parcel numbering and preserves M1 adjacency. The initial
colony contains six districts, the spaceport on its real site, and the landed Ark
as a landmark outside the hex slots. All fifteen M1 buildings have initial kit
assemblies. The capture of later growth comes from thirty turns of actual bot play,
rather than an artificial development selector.

## Data and renderer boundary

`M1VisualSnapshot` produces detached dictionaries from the state after pending orders.
The renderers receive those descriptions, rather than mutable simulation objects.
Pure visual interactions leave the state hash unchanged. Build and survey actions
change state through M1's existing command queue; real turns resolve completion.

Only built sites affect permanent terrain grading. Preview/queued sites temporarily
hide obstructing vegetation, and canceling restores it. The terrain seed and canonical
parcel coordinates survive growth. Natural outcrops remain blocked. Planning outlines
are optional; there is no circular display plinth. Roads are an appearance layer and
never imply an adjacency bonus. Routing isolated outer parcels around blocked terrain
still needs a production pass.

Blender supplies beveled/curved parts and nine tileable albedo/normal/roughness bakes.
The new GLB and texture sources total under 1 MB. Rebuild them with
`blender --background --threads 3 --python tools/art/build_city_kit.py`.
Regional materials cover solid planet types: barren hides water and its atmospheric
sky; ice freezes water; ocean favors vegetation; toxic uses tinted liquid. These are
appearance presets, not climate simulation.

One cancellable worker prepares terrain. Two bounded workers prepare spherical
surface maps. Nodes, GPU uploads and instanced mesh assembly stay on the main thread.
New descriptions cancel obsolete terrain jobs. Overview/focus refine the same planet
surface seed; regional terrain still needs a geographic anchor on that global surface.

## Verification

Commands run from this M1 checkout, with the activated setup PATH and an imported project:

- Baseline M1: **165 tests / 3,129 checks**, zero failures.
- With the study: `godot --headless --path . -s tests/run_tests.gd`:
  **170 tests / 3,236 checks**, zero failures. New cases cover hidden information,
  snapshot immutability, real tiers/queues, every building and canonical slot coordinates.
- `godot --headless --path . -s tools/validate_data.gd`: zero errors and zero skips.
- `xvfb-run -a -s '-screen 0 2560x1600x24' godot --rendering-driver opengl3
  --audio-driver Dummy --path . -s tools/m1_3d_smoke.gd`:
  **78 checks**, including explanation/layout audits on seventeen renderer captures.
  A real pointer selects a planner slot; the existing Build and Cancel controls work;
  three actual turns complete a farm; two actual turns complete a survey. Camera,
  pause/reduced motion and PC/phone layouts at 100% and 200% text are exercised.
- `godot --headless --path . -s tools/bot_run.gd -- --scenario s1 --policy balanced
  --seeds 1,11 --turns 105 --out telemetry/m1_3d --check-determinism`: deterministic
  playthroughs with no invariant problems. This is a regression check, not a new balance pass.

Desktop rendering uses software OpenGL. The verified renderer run reports no script
or shader errors. Real phone hardware, browser game export, frame rates and GPU memory
remain unverified.

## Recommendation

Incorporate the system viewport first, then the city viewport with a stable lifetime
across planner updates. Keep the existing inspectors and command logic. Before making
either the default, benchmark a web export and representative phones, add touch zoom,
set texture/geometry budgets and add terrain chunks/LOD and a persistent cache policy.

The next artistic finish should add geological structure, layered ground cover,
better plant species, construction details, weathering, deeper windows and distinctive
building families. The repeated parts and procedural materials remain prototypes.
Bind regional terrain to a saved planetary location so globe and city geography agree.
Foreign Surveyed/Observed colony memory is future integration; M1's known/survey flags
alone do not supply an intel-safe historical city snapshot.
