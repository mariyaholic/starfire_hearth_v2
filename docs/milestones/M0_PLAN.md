# M0 Plan: Foundation and UI kit

## Goal

A repository where the simulation skeleton, the data pipeline, the test harness and CI all run, and a
UI kit that sets the modern-flat look for the whole game. The Owner judges the look from a showcase
scene and an icon contact sheet, on a PC and on a phone browser.

Gate (from §12): CI green, and the Owner approves the look of the showcase and the icon sheet.

## Pinned toolchain

- Godot **4.7.2-stable** (latest stable on 2026-09-24; 4.8 is not released). Linux editor binary and
  export templates from `github.com/godotengine/godot/releases`, cached in CI.
- Renderer: Compatibility (OpenGL 3 / WebGL 2).
- Fonts: IBM Plex Sans 1.1.0 and IBM Plex Mono 2.5.0 from the official IBM Plex release zips, OFL
  licence files vendored alongside.

## Tasks

1. **Bootstrap.** Layout of §9.2, `.gitignore`, `.gitattributes`, `LICENSE` (All rights reserved until
   the Owner chooses), `.godot-version`, `project.godot`, `README.md`, `CHANGELOG.md`, `CREDITS.md`,
   `docs/DESIGN_LOG.md`, vendored fonts.
2. **Simulation skeleton (`sim/`).**
   - `GameState` tree (empires, systems, lanes, planets, colonies, fleets, ships, designs) with
     `to_dict()` / `from_dict()`.
   - Canonical JSON writer (sorted keys, integers only; floats are rejected) and SHA-256 state hash.
   - Save serializer with the versioned envelope of §9.6 and an empty migration chain.
   - `Rng`: xoshiro128** with `mul32`, splitmix32 seeding over (seed, turn, stream, salt), the stream
     constants of §9.5, and test vectors cross-checked against an independent reference implementation.
   - `Command` / `Result`, a command registry, the within-turn `CommandQueue` with undo, and two real
     commands (rename colony, reorder job priorities).
   - `TurnProcessor` with the 14 phases of §9.4 in order (empty bodies), `TurnResult`,
     `ReportBuilder` (top-3 selection), `Breakdown`, `ReportItem`, `WhyLog`, calendar.
3. **Tests.** Headless runner (`tests/run_tests.gd`) that discovers `test_*.gd`, with a `T` assertion
   helper and an engine `Logger` hook so script errors fail the test that raised them. Suites: unit,
   golden (RNG vectors, per-turn hashes), saves (round-trip, fixture), boundary scan of `sim/`,
   data validation, integration (50 skeleton turns with a bot policy and the invariants of §9.8).
4. **Data and strings.** Every file in `data/` from §9.2 exists with the §13.1 shape. Records that the
   UI kit needs are real (resources, jobs, districts, planet types, traits, techs); the rest are
   stubs. `validate_data.gd`: shape, cross-references, string keys both ways, two sinks per resource,
   closed effect keys, and scenario reachability (reported as SKIP until a scenario is playable).
   `strings/en.csv` loaded as a Godot `Translation`; `Strings.fmt(key, args)`.
5. **UI kit (`ui/`).**
   - Tokens (§8.2) in `ui/theme/tokens.gd`; a Theme built from tokens with text scale (100–200%) and
     a high-contrast variant.
   - Components: `Explainable` (hover 300 ms / click pins / tap / long-press, nested to 2 levels),
     `BreakdownTooltip`, `ResourceChip`, `Card`, `Modal`, `Toast`, `Drawer`, `BottomSheet`, `Tabs`,
     `HexCell`, button variants (primary, secondary, ghost, danger, icon).
   - Responsive layout helper: automatic UI scale (1080p-relative on PC, dp-based on touch), wide and
     compact layout classes, safe-area margins, user multiplier.
6. **Art generators.** At least 40 icons on a 24×24 grid, each with a filled and an outlined variant,
   authored as SVG text and rasterised at the exact pixel size needed; `tools/icon_sheet.gd` contact
   sheet; procedural star (spectral class, magnitude) and planet (type, seed) renderers.
7. **Showcase.** One scene with every component on fake data, including overlay states (pinned
   nested tooltip, modal, drawer, bottom sheet, toasts), an icon sheet page and a star/planet page.
   It is the main scene of the M0 web build.
8. **Screenshot tour and id audit.** `tools/screenshot_tour.gd` renders every showcase state at
   1920×1080 (PC) and 2400×1080 (phone, 440 dpi, touch) at 100% and 200% text scale, plus
   deuteranopia-simulated copies. `tools/id_audit.gd` fails on raw-id text, overlapping or clipped
   labels, touch targets under 48 dp at phone size, and numeric labels outside an `Explainable`.
9. **Bot and telemetry skeleton.** `tools/bot_run.gd` (balanced and random-legal policies over the
   phase skeleton) writes per-turn telemetry JSON; `tools/telemetry_report.gd` aggregates it and prints
   PASS / FAIL / SKIP per gate. Real balance gates start in M1.
10. **CI.** `.github/workflows/ci.yml`: cached Godot and templates, validate data, tests, bot smoke
    (3 seeds × 60 turns), screenshot tour + audit, exports (Web, Windows, Linux), artifacts, and a
    GitHub Pages deploy from `main`.
11. **Report.** `docs/milestones/M0_REPORT.md`, then stop for the Owner's verdict.

## Files expected to touch

`project.godot`, `export_presets.cfg`, `.godot-version`, `.gitignore`, `.gitattributes`, `LICENSE`,
`README.md`, `CHANGELOG.md`, `CREDITS.md`, `docs/**`, `sim/**`, `data/**`, `strings/en.csv`, `app/*.gd`,
`ui/**`, `assets/icons/*.svg`, `assets/fonts/**`, `tests/**`, `tools/*.gd`, `.github/workflows/ci.yml`.

## Risks

| Risk | Mitigation |
| --- | --- |
| The repository is private and Pages is not enabled. Pages on a private repository needs a paid GitHub plan. | The deploy job is separate from the checks, so "CI green" does not depend on it. The web build is also uploaded as an artifact. The report asks the Owner to enable Pages (Source: GitHub Actions) or to choose another host. |
| Private-repo Actions minutes and artifact storage are limited. | Godot and templates cached; concurrency cancels superseded runs; short artifact retention. |
| Phone layout: a 6-inch 2400×1080 screen is only about 873×393 dp. | The layout helper exposes a compact class; every component is built to reflow in it; the audit checks 48 dp targets and overlap at that size. |
| Headless rendering in CI (no GPU). | Verified locally: `xvfb-run` + `--rendering-driver opengl3` renders through llvmpipe. |
| Godot 4.7 API differences from older docs. | API reference dumped with `godot --doctool` and consulted; everything is exercised by tests. |
| JSON numbers parse as floats in Godot. | `from_dict` converts explicitly; the canonical writer rejects floats, so a float in state fails the hash. |

## How each gate item is verified

| Gate item | Command / evidence |
| --- | --- |
| Data valid | `godot --headless --path . -s tools/validate_data.gd` |
| Tests green | `godot --headless --path . -s tests/run_tests.gd` |
| Bot smoke | `godot --headless --path . -s tools/bot_run.gd -- --scenario skeleton --policy random-legal --seeds 1-3 --turns 60 --out telemetry/` then `tools/telemetry_report.gd` |
| Screens + audit | `xvfb-run -a godot --rendering-driver opengl3 --path . -s tools/screenshot_tour.gd -- --out screens/`, then I look at every PNG |
| Exports | `godot --headless --path . --export-release "Web" build/web/index.html` (and Windows, Linux) |
| CI green | GitHub Actions run on the pushed branch |
| Look approved | Owner playtest of the web build on PC and phone (not something I can verify) |
