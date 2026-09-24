# Changelog

Newest first. A claim marked **Verified** names the command that proved it, run from the
repository root after `godot --headless --path . --import`. Everything else is **Unverified**.

## 0.1.0-m0: foundation and UI kit (not released)

### Breakdowns at large text sizes

- Breakdown panels widen with the text scale, capped by the screen (DESIGN_LOG 40). At 200% on
  the phone, "Fertile Soil (planet trait)" had wrapped to a word per line beside its value; it
  now fits on one line. **Verified:** the screenshot tour (0 audit issues) and a look at
  `screens/phone_200/02_breakdown_pinned.png` and `screens/pc_200/02_breakdown_pinned.png`.

### Web build: phone and tablet detection, smoke test

- The web build now recognises tablets whose browser reports a desktop system (iPadOS Safari
  says macOS) by their touch pointer (DESIGN_LOG 36), and prints the layout it chose to the
  browser console. Before the fix an iPad got the PC layout with 24-pixel targets.
  **Verified:** `node tools/web_smoke.mjs --build build/web --out screens/web` reports PC
  "wide, pointer", Android phone "compact, touch", iPad "compact, touch".
- New `tools/web_smoke.mjs` opens the exported web build in headless Chromium as a PC, an
  Android phone (873x393 at 2.75x) and an iPad, and fails on a console error, a boot that
  stalls, or the wrong layout class. **Verified:** the command above: 3 of 3 devices passed,
  each engine start under 2 s.

### CI and exports

- GitHub Actions workflow (`.github/workflows/ci.yml`): import, data validation, tests, bot
  smoke test with a determinism replay (2 policies x 3 seeds x 60 turns), telemetry gates,
  palette report, screenshot tour and id audit under xvfb, icon sheet, Web, Windows and Linux
  exports, web size check, web smoke test, artifacts, and a GitHub Pages deploy from `main`.
  **Unverified on GitHub** until its first run; each step was run locally with the same
  command.
- Export presets for Web (single-threaded, so no special server headers), Windows and Linux.
  **Verified:** `godot --headless --path . --export-release "Web" build/web/index.html` (and
  `"Windows"`, `"Linux"`) exit 0. The Linux build ran the showcase for 240 frames with no
  script errors: `xvfb-run -a ./build/linux/StarfireHearth.x86_64 --rendering-driver opengl3
  --quit-after 240`. The Windows build has not been run (**Unverified**).
- Web build size: 40,795,000 bytes on disk, 11,015,704 bytes as a gzip download. **Verified:**
  `du -sb build/web`, and `gzip -9 -c` of each file (the CI step). How the budget is read:
  DESIGN_LOG 37.
- Content folders that hold only a placeholder are optional at run time, so exported builds
  start without "missing folder" errors; the validator still requires them in the repository
  (DESIGN_LOG 35). **Verified:** the Linux run above, and
  `godot --headless --path . -s tools/validate_data.gd` (0 errors).

### Review tools

- `tools/icon_sheet.gd` renders the icon contact sheet: 87 icons, filled and outlined, at 24
  and 16 px, grouped and named. **Verified:** `xvfb-run -a godot --rendering-driver opengl3
  --path . -s tools/icon_sheet.gd -- --out screens/icon_sheet.png` wrote a 1680x2346 PNG, which
  I inspected.
- `tools/palette_report.gd` prints WCAG contrast for text colours on every panel colour, and
  ΔE separation of the colour pairs that carry meaning, for normal vision and under a
  deuteranopia simulation. **Verified:** `godot --headless --path . -s tools/palette_report.gd`:
  every text colour is at least 4.56:1; three pairs are flagged LOW (see the M0 report).

### UI kit, showcase, screenshot tour and id audit

- Theme built at run time from tokens, with text scale 100 to 200%, a compact (phone) class,
  touch sizing and high contrast (DESIGN_LOG 12, 14). IBM Plex Sans and Mono.
- Components: `Explainable` (hover 300 ms, click to pin, tap, long-press; nested breakdowns two
  levels deep), `BreakdownTooltip`, `ResourceChip`, `Card`, `Modal`, `Toast`, `Drawer`,
  `BottomSheet`, `SfTabs`, `HexCell`, button variants, `Meter`, `NoiseWave`, `TopBar`.
- `Layout` and `Overlay` autoloads (DESIGN_LOG 15).
- 87 SVG icons with filled and outlined variants, procedural star and planet renderers.
- Showcase scene (the M0 main scene) with every component on sample data.
- `tools/screenshot_tour.gd` renders 17 showcase states as a PC (1920x1080) and a phone
  (2400x1080, 440 dpi, touch), each at 100% and 200% text, plus deuteranopia copies;
  `tools/id_audit.gd` checks raw ids, overlap, clipping, broken words, 48 dp targets and numbers
  outside an `Explainable`. **Verified:** `xvfb-run -a -s "-screen 0 2560x1600x24" godot
  --rendering-driver opengl3 --path . -s tools/screenshot_tour.gd -- --out screens/`: 68
  screenshots, 0 audit issues, 102 exemptions (the three text-size buttons in each of the 34 PC
  renders). I looked at every PNG.
- **Verified:** `godot --headless --path . -s tests/run_tests.gd -- --filter ui_audit` (the same
  audit on the headless showcase, 5 cases) and `--filter tokens` (WCAG AA for every text token)
  pass.

### Data, validator, strings, bot runner and telemetry

- `data/` holds every file of §9.2. Resources, jobs, districts, planet types, planet sizes,
  traits, factions and origins are real; buildings, techs, hulls, modules, edicts, treaties,
  personalities, difficulty, vignettes and portraits are empty stubs until M1 (DESIGN_LOG 28).
  Scenario 1 is a stub start state (Ember, Aster's colony and fogged neighbours).
- `tools/validate_data.gd`: shape, cross-references, string keys both ways, two sinks per
  resource, closed effect keys, colour tokens, icon names. Reachability reports SKIP until a
  scenario is playable. **Verified:** `godot --headless --path . -s tools/validate_data.gd`: 18
  tables, 47 records, 415 strings, 0 errors, 1 skipped check. `tests/fixtures/bad_data/` proves
  each check fires (`--filter data`, 6 tests pass).
- `strings/en.csv` with 415 keys, loaded at run time into a Translation (DESIGN_LOG 11).
- `tools/bot_run.gd` (balanced and random-legal policies, per-turn telemetry, determinism
  replay) and `tools/telemetry_report.gd` (PASS, FAIL or SKIP per gate). **Verified:**
  `godot --headless --path . -s tools/bot_run.gd -- --scenario s1 --policy balanced --seeds 1-3
  --turns 60 --out telemetry --check-determinism` (and `--policy random-legal`), then
  `godot --headless --path . -s tools/telemetry_report.gd -- --in telemetry`: invariants PASS,
  determinism PASS (6 of 6), end-turn p95 1.48 ms PASS (budget 300 ms); the five balance gates
  SKIP until M1 (DESIGN_LOG 29).

### Simulation skeleton

- Integer-only `GameState` with canonical JSON and a SHA-256 state hash; saves with a versioned
  envelope, checksum and migration chain; `Rng` (xoshiro128**, stateless seeded streams);
  `Command`, `Result`, command queue with undo; `TurnProcessor` with the 14 phases in order;
  `Breakdown`, `ReportItem`, `WhyLog`; invariants; calendar. **Verified:**
  `godot --headless --path . -s tests/run_tests.gd`: 85 passed, 0 failed, 390 checks, 17 files.
- RNG test vectors come from an independent reference implementation, including the published
  xoshiro128** output for state {1, 2, 3, 4}. **Verified:** `--filter rng` (12 tests pass).
- Boundary scan: `sim/` names no nodes, input, UI or engine randomness. **Verified:**
  `--filter boundary` (2 tests pass).
- **Golden baseline created:** `tests/golden/tiny_hashes.json` (seed 20970401, 12 turns), made
  with `tools/regen_golden.gd`. Reason: "M0: first baseline of the phase skeleton".
  **Verified:** `--filter golden` (2 tests pass, including a save and load at every turn).
