# M1.2 checkpoint progress

Prepared 3 October 2026 from the Owner's M1.1 playtest comments; resumed 4 October.
The [architecture and stage plan](M1_2_PLAN.md) was approved for Stages A–F.
Stages A–G are implemented and locally revalidated. Work remains on the existing
M1 lineage without creating a new branch; no M1.2 release or tag exists yet.

| Stage | Status | Evidence |
| --- | --- | --- |
| A — Baseline and contracts | Complete for progression | Actual archived writer, versioned components, overlay persistence and identity/future-authority checks. [Report](M1_2_STAGE_A_REPORT.md). |
| B — City network | Implemented and locally revalidated | Shared entrance network; save-preserving opt-in upgrade; 28 native checks/five captures and 240-test regression run. [Report](M1_2_STAGE_B_REPORT.md). |
| C — Display and scaling | Implemented and locally revalidated | Root review corrections included production viewport settings, borderless desktop recovery, live countdown and native preview checks; final full suite 242 tests/12,242 assertions, native focused 34 assertions. [Report](M1_2_STAGE_C_REPORT.md). |
| D — Immersive workspace | Implemented and revalidated | Approved compact summary/context windows, tabbed tools, real Matte/Frosted/Glossy settings, version-2 workspace migration; 8 focused tests / 144 checks. [Report](M1_2_STAGE_D_REPORT.md). |
| E — Voice capacity | Implemented and revalidated | Optional cue registry/audio lifecycle and strict voice asset intake; 8 focused tests / 211 checks. [Report](M1_2_STAGE_E_REPORT.md). |
| F — Living orbital map | Implemented and revalidated | Saved deterministic turn-driven orbits, ring-aware render spacing, fitted overview, circular turn motion, paused followers and belt camera tracking; 5 tests / 76 checks. [Report](M1_2_STAGE_F_REPORT.md). |
| G — M1.2 checkpoint | Complete locally | Godot 4.7.2 suite (255 tests / 12,392 checks), data audit, 58 latest desktop/touch browser checks, actual screenshots and refreshed Windows/Web exports. Earlier broad browser campaign: 336 checks. Windows runtime and physical-device acceptance remain open. [Report](M1_2_STAGE_G_REPORT.md). |

Each stage is revalidated before advancing. Quality-first performance debt may be
carried with measurements; gameplay correctness, intel filtering, usable controls
and graphics save compatibility remain required gates. M1.1's outstanding
hardware and acceptance gates remain open until checked with evidence.

4 October owner visual-review follow-up: the [compact Immersive UI and finish
proposal](M1_2_IMMERSIVE_UI_FINISH_PROPOSAL.md) was approved and implemented.
Space-map spacing and overview framing were corrected without changing saved orbital
clocks. Latest D–G tests, actual screenshots and refreshed review artifacts are in the
[follow-up report](M1_2_D_G_REVALIDATION_REPORT.md).

## GitHub checkpoint publication — 7 October 2026

Published the current M1.1 foundation and M1.2 source checkpoint on the existing
`claude/starfire-hearth-build-cs2vb6` branch, retaining the audio handoff and prior
M1.1 download package. No new branch or release tag was created.

Fresh pre-push checks using Godot 4.7.2: **255 tests passed, zero failures,
12,392 checks**; data validation: **20 tables, 328 records, 1,485 strings,
zero errors or skipped checks**; First Light art audit: **367 checks, zero failures**.
Existing browser/export evidence remains in the stage and revalidation reports;
those checks were not repeated for this publication. Windows and physical-device
acceptance remain open.

This source push includes the 3D meshes, textures, Blender source, game code,
tests, authoring tools and milestone documentation. Generated `build/`, `screens/`
and `reports/` artifacts remain excluded by the repository's ignore rules.
The existing downloadable ZIP under `downloads/m1_1/` is the earlier M1.1 build,
not the current M1.2 executable.
