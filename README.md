# Starfire Hearth

A turn-based space 4X for PC and mobile, built in Godot 4 with GDScript in a clean modern-flat
style. You lead a slowboat colony a hundred years into the Long Silence, the century since the Sol
relay stopped transmitting.

**Status:** milestone M0 (foundation and UI kit). There is no playable game yet. The current build
opens the UI kit showcase. See `docs/milestones/` for plans and reports.

## Requirements

- Godot **4.7.2-stable** (the exact version is pinned in `.godot-version`), standard build.
- Export templates for 4.7.2 if you want to export builds.
- Linux with `xvfb-run` for the screenshot tour when no display is available.

## Common commands

Run from the repository root. The first command builds Godot's import cache and class list; run
it once after cloning and after adding new scripts or assets.

```sh
godot --headless --path . --import                      # import assets, register class names
godot --headless --path . -s tools/validate_data.gd     # data schema and cross-reference checks
godot --headless --path . -s tests/run_tests.gd         # full headless test suite
godot --headless --path . -s tools/bot_run.gd -- --scenario skeleton --policy random-legal --seeds 1-3 --turns 60 --out telemetry/
godot --headless --path . -s tools/telemetry_report.gd -- --in telemetry/
xvfb-run -a -s "-screen 0 2560x1600x24" godot --rendering-driver opengl3 --path . -s tools/screenshot_tour.gd -- --out screens/
godot --path .                                          # run the showcase
```

Useful test runner flags: `-- --filter rng` runs only test files or methods whose name contains
`rng`.

## Layout

| Path | What lives there |
| --- | --- |
| `sim/` | Pure simulation: state, rules, commands, turn processing, RNG, saves. No nodes, no UI. |
| `data/` | All game content as JSON. |
| `strings/en.csv` | Every player-facing string. |
| `ui/` | Presentation only: theme, components, screens, map renderers. |
| `app/` | Autoloads: `Game`, `Settings`, `Strings`, `Layout`, `SaveService`. |
| `assets/` | SVG icons, fonts (IBM Plex, OFL), audio. |
| `tests/` | Headless tests: unit, integration, golden, fixtures. |
| `tools/` | Data validation, bot playthroughs, telemetry, screenshot tour, id audit, icon sheet. |
| `docs/` | Design log and milestone plans and reports. |

## Rules of the codebase

- `sim/` never touches `Node`, `SceneTree`, `Input` or `ui/`; a test scans for it.
- Simulation state is integers only: resources in hundredths, percentages in basis points.
- The UI never recomputes game math. It shows the `Breakdown` and `ReportItem` objects the
  simulation emits.
- No raw ids in the UI. All text comes from `strings/en.csv`.

## Licence

All rights reserved until the Owner chooses otherwise; see `LICENSE`. Third-party assets are listed
in `CREDITS.md`.
