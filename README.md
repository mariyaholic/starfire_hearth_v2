# Starfire Hearth

A turn-based space 4X for PC and mobile, built in Godot 4 with GDScript in a clean modern-flat
style. You lead a slowboat colony a hundred years into the Long Silence, the century since the Sol
relay stopped transmitting.

**Status:** milestone M1 (First Light): Scenario 1 plays from the title to the debrief on PC and in
a phone browser. A separate **M2A Exploration Preview** adds civilian interstellar travel,
frontier surveys, an outpost and a new colony. Launch it from Campaign; it does not complete
Scenario 2 or unlock later campaign chapters. Opt a survey probe into automatic exploration
or resolve a one-shot discovery at Halden's dormant gate. Stop a journey at its next system,
or take an optional detour beyond Vesper to The Shroud's derelict and energy/research outpost.
Surveyed outpost sites show projected production and upkeep before a builder arrives.
See `docs/milestones/` for plans, evidence and platform acceptance limits.

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
godot --headless --path . -s tools/expedition_bot.gd -- --seed 1 --trace  # M2A expedition
godot --headless --path . -s tools/expedition_bot.gd -- --seed 1 --route vesper-first --outpost research --trace  # optional Shroud itinerary
godot --headless --path . -s tools/bot_run.gd -- --scenario s1 --policy random-legal --seeds 1-3 --turns 60 --out telemetry/ --check-determinism
godot --headless --path . -s tools/telemetry_report.gd -- --in telemetry/
godot --headless --path . -s tools/palette_report.gd   # contrast and colour-blind separation
xvfb-run -a -s "-screen 0 2560x1600x24" godot --rendering-driver opengl3 --path . -s tools/screenshot_tour.gd -- --out screens/
xvfb-run -a -s "-screen 0 2560x1600x24" godot --rendering-driver opengl3 --path . -s tools/icon_sheet.gd -- --out screens/icon_sheet.png
mkdir -p build && touch build/.gdignore                 # keep exports out of the editor's scan
godot --headless --path . --export-release "Web" build/web/index.html   # also "Windows", "Linux"
node tools/web_smoke.mjs --build build/web --out screens/web   # web build in headless Chromium
godot --path .                                          # run the showcase
```

The screenshot tour and the icon sheet need a renderer: on a machine without a display, run them
under `xvfb-run` as shown. Exports need the 4.7.2 export templates. The web smoke test needs Node
and the `playwright` npm package with its Chromium (`npx playwright install chromium`); set
`PLAYWRIGHT_DIR` to the `node_modules` folder that holds it if it is not installed globally.

Useful test runner flags: `-- --filter rng` runs only test files or methods whose name contains
`rng`.

The expedition harness defaults to the original automated route. Its optional Shroud routes
hold Vesper development until the requested outpost is built so that completion cannot skip
the tested investment. Both optional outpost kinds select research cards with the same policy;
`--research-cards` enables that policy on the default route too. These runs are deterministic
coverage itineraries, not measurements of optimal play or balanced alternatives. Older preview
saves retain their original map; start a new expedition to explore The Shroud.

## Layout

| Path | What lives there |
| --- | --- |
| `sim/` | Pure simulation: state, rules, commands, turn processing, RNG, saves. No nodes, no UI. |
| `data/` | All game content as JSON. |
| `strings/en.csv` | Every player-facing string. |
| `ui/` | Presentation only: theme, components, screens, map renderers. |
| `app/` | Autoloads: `Settings`, `Strings`, `Layout`, `Overlay`, `Game`, `SaveService`. |
| `assets/` | SVG icons, fonts (IBM Plex, OFL), audio. |
| `tests/` | Headless tests: unit, integration, golden, fixtures. |
| `tools/` | Data validation, bot playthroughs, telemetry, screenshot tour, id audit, icon sheet, web smoke test. |
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
