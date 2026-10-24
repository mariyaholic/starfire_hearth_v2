# Changelog

Newest first. A claim marked **Verified** names the command that proved it, run from the
repository root after `godot --headless --path . --import`. Everything else is **Unverified**.

## Unreleased: M1, First Light (in progress)

- Branching-campaign art is in: all 42 scenes and endings (vignette batches 2 and
  3) and 22 portraits (portrait batches 2 and 3): Lio Hale, Inspector Castellane,
  Keeper Banda, Tobiah Ilyin and Pell Okonkwo-Dane with their expressions, and
  Director Hale's hollow look. The ids are in the manifest ahead of the campaign
  itself, so nothing draws them yet. `tools/art/prep_branching_art.py` upscales the
  scenes from their native 2048x768 to the brief's 3200x1200 (the game shows
  2400x900), keys and despills the portraits from #00FF00, and moves each character
  down so the head sits 10% below the top, like the shipped set. Batch 3 is the
  October 24 redo: `end_annexed` (its first flag read as NATO's), Ilyin's
  expressions and all of Pell. **Verified:** `python3 tools/import_assets.py` on
  the four zips: 41 + 14 + 1 + 7 pass; painted art 16.4 of 40 MB;
  `tests/run_tests.gd`: 255 tests / 12,644 checks; `tools/validate_data.gd`: zero
  errors.

- Audio revision 3 is installed: all 28 music cues (music batch 2), rewritten
  harmony-first by `tools/art/audio_rework/compose.py` and rendered from VSCO 2 CE
  (CC0) and the Salamander Grand Piano V3 (CC BY 3.0, credited in `CREDITS.md`).
  The intake now accepts CC BY with attribution. Music encodes at Vorbis quality 5
  to fit the 70 MB budget (59.9 MB). Loops restart after the 0.3 s lead-in.
  **Verified:** `python3 tools/import_assets.py --zip incoming/sfh_music_batch2.zip
  --replace`: 28 pass, loudness -18 LUFS ±0.2, true peak ≤ -1.27 dBTP;
  `tests/run_tests.gd`: 255 tests / 12,392 checks; `tools/validate_data.gd`: zero
  errors. **Unverified:** the Owner has heard 3 of the 28 cues.
  See `docs/milestones/AUDIO_REWORK_R3_PILOT_REPORT.md`.

- M1.2 owner UI review incorporates compact Immersive summary/context windows,
  tabbed Manage/Research and device-local Matte/Frosted/Glossy finishes. Workspace
  v2 migrates untouched oversized defaults while retaining custom arrangements.
  System overview adds ring-aware display spacing without changing saved clocks,
  fits the actual viewport, and follows circular turn motion. Paused attachments
  and focused asteroid belts retain their parent/target positions. **Verified:**
  `tests/run_tests.gd`: 255 tests / 12,392 checks; `tools/validate_data.gd`: zero
  errors/skips; `tools/m12_review_web_smoke.py`: 58 desktop/touch checks, zero
  failures/browser errors. Windows/Web exports refreshed. Physical-device review
  remains open. See `docs/milestones/M1_2_D_G_REVALIDATION_REPORT.md`.

- M1.1 F.1 adds independent Command / Immersive view layouts: existing city and
  space renderers become the main screen with contextual M1 inspectors/management.
  The view button/F10 retains camera, selection and orders; Escape dismisses context.
  Device preferences survive native reload and Web page closure, without changing
  gameplay/graphics save schemas. Compact controls and side/bottom docks support
  100–200% text. Close-camera quality changes tolerate asynchronous terrain.
  **Verified:** `godot --headless --path . -s tests/run_tests.gd`: 219 tests /
  12,015 checks; `tools/m11_immersive_smoke.gd`: 319 native checks;
  `python3 tools/m11_immersive_web_smoke.py`: 127 desktop/touch Web checks.
  42 fresh review captures. Owner art review and Stage G remain open.
  See `docs/milestones/M1_1_IMMERSIVE_VIEW_REPORT.md`.

- M1.1 Stage F adds authored PBR material detail, three mesh LODs for civilian hulls,
  finished Ember buildings/district equipment, civilization exemplars, foliage and
  versioned planet/star finish. Supported old looks stay pinned; explicit upgrade
  retains geography. Graphics wrapper 2 includes an independently checked E view;
  the actual E writer preserves F and adds a demolished clearing that F restores.
  Resource overflow and portrait navigation/stat widths are finished at 100–200%.
  **Verified:** `tests/run_tests.gd`: 216 tests / 11,918 checks;
  `tools/m11_stage_f_smoke.gd`: 290 checks;
  `tools/m11_stage_f_details.gd`: 119 checks;
  `tools/m11_stage_f_web_smoke.py`: 343 desktop/touch checks;
  `tools/art/audit_finish_v1.py`: 367 asset checks; 27 archived-E roundtrip checks.
  Owner art acceptance and Stage G platform/campaign profiling remain open. Temporary
  performance debt is recorded in `docs/milestones/M1_1_STAGE_F_REPORT.md`.

- M1.1 Stage E integrates the anchored 3D city into the normal Colony planner with
  canonical parcel picking, actual tiers/buildings and existing construction controls.
  Persistent completed, queue, preview and terrain layers patch independently; decorative
  routes follow the terrain around blocked plots. Optional committed clearing history
  survives demolition/resaving, new games pin city kit 2 and existing kit 1 stays
  supported. An actual archived Stage D writer preserves both catalogs through supported
  or fallback views. Gameplay schema, content and golden hashes are unchanged. **Verified:**
  `godot --headless --path . -s tests/run_tests.gd`: 209 tests / 11,676 checks;
  `tools/m11_stage_e_smoke.gd`: 187 native checks; `tools/m11_stage_e_web_smoke.py`:
  275 desktop/touch browser checks. Final art/device validation remains
  Stages F/G; performance debt is measured in `docs/milestones/M1_1_STAGE_E_REPORT.md`.

- M1.1 Stage D persists versioned graphics profiles and geographic anchors through
  manual, automatic and checkpoint saves. Globe and regional terrain share the pinned
  appearance field. Old M1 saves reconstruct their seeded look; unsupported future
  graphics survive resaving with a compatible-view or Strategic fallback. Gameplay
  schema/checksums remain unchanged. The original M1 writer still drops new metadata
  on resave; the compatibility contract documents that older-executable boundary. **Verified:** 204 tests / 10,067 checks,
  20 native checks and 38 browser checks; see `docs/milestones/M1_1_STAGE_D_REPORT.md`.

- M1.1 Stages B/C add a persistent viewport/controller, filtered snapshots, shared
  native/cooperative generation and pinned texture cache. Normal Galaxy/System now
  default to 3D with actual permitted stars/planets/ships/outposts, existing command
  inspectors and a persisted Strategic alternative. The Colony planner and finished art remain later stages. **Verified:**
  `godot --headless --path . -s tests/run_tests.gd`: 185 tests / 3,576 checks;
  `tools/m11_stage_c_smoke.gd`: 117 rendered checks and four clean layout profiles.
  Browser command evidence and measured performance debt are in
  `docs/milestones/M1_1_STAGE_C_REPORT.md`. No balance/golden/save-schema changes.
- Optional 3D incorporation study against this M1 build: actual planets and owned ships,
  canonical planner coordinates, actual district tiers/buildings, construction previews,
  and the existing Build/Cancel/Survey controls. See
  `docs/milestones/M1_3D_INCORPORATION.md` for scope, launch points and production work.
  **Verified:** 170 tests / 3,236 checks; 78 rendered interaction/layout checks.
  The material finish and browser/mobile hardware performance remain provisional.

### The balance gates pass (DESIGN_LOG 95, 96)

- **What changed in Scenario 1:** the Ark Hull opens the market from the first turn, and the Market
  Exchange and the Foundry are locked there (a scenario can now list `locked_buildings`, like
  `locked_ordinances`); the Research Institute is one per empire, costs 120 minerals and adds 2.00
  research to each branch (`output_add:research` now counts in the research report, the effect text
  and the advisor); the Storehouse, the Fusion Plant and the Civic Hall are cheaper and the Civic
  Hall gives 1.50 influence. The balanced bot keeps the larger of seven turns of income and the
  next Colony Ship's price, not both.
- **What changed only in what a gate counts:** "winnable" is a win within 1.2 times the expected
  duration (was 1.5), and the hoarding gate measures the balanced bot only. The Foundry also
  leaves the balance scope.
- **Verified:** `tools/balance_loop.sh <dir> 1-20`: all five balance gates pass. Winnable on Normal
  15 of 20 (was 20 of 20), no hoarding 0 of 40 balanced runs (was 80 of 80 runs of every bot but
  random-legal), everything matters passes (the Storehouse 37%, Fusion Plant 39%, Research
  Institute 47%, Civic Hall 48%; was Foundry 0%, Research Institute 3%), median win turn 78 (was
  74), end-turn p95 44 ms.
- **Verified:** `godot --headless --path . -s tools/validate_data.gd`: 0 errors, 0 skipped checks.
  `godot --headless --path . -s tests/run_tests.gd`: 165 passed, 0 failed, 3,129 checks; the golden
  hashes did not change (the scripted turns never trade or build the changed buildings).
- **Unverified:** how the market from turn 1 plays for a person; the pacing moved four turns.

### The game screen: views, overlays, settings, load and credits (DESIGN_LOG 94)

- `GameScreen` replaces the stand-in on the game route: the top bar over the current view, a
  navigation rail (PC) or tab bar (phone), the advisor's tutorial (a card, or a strip on phones)
  with a highlight ring, Undo and End Turn. End Turn opens a waiting event, else lists what has no
  orders and lets the player go on; then the turn's report, each event, and the debrief at the end.
- Seven views: **colony planner** (numbers with breakdowns, the hex grid, a slot menu with a
  what-would-change preview, queue with rush and cancel, job priority, governor with its plan and
  veto, shipyard), **system** (planets, ships, survey, colonise, outposts with costs and reasons),
  **galaxy** (locked lanes, with the reason), **research**, **ordinances**, **market** and
  **objectives** (with the Sealed Order's decoding).
- Overlays: the event scene (painted scene, speaker, choices with cost, effects and the chances of
  an uncertain outcome, story music), the turn report and End Turn checklist (each line jumps to
  what it is about), Why? (the turn's causes for a colony), the game menu (save, load, Codex,
  settings, quit).
- New screens and routes: **Settings** (each volume, mute, text size, interface size, high
  contrast, reduced motion, hints), **Load** (thumbnails, kind, delete) and **Credits** (the
  CREDITS.md file itself, shipped in the game). The title offers Load, Settings and Credits.
- The audit and tour: hex cells are compared by their tile; the tour visits 17 more states (the
  game's views on a game 24 turns in, the market on a finished one, an event, a report, the
  checklist, the menu, Why?, Settings, Load, Credits).
- **Verified:** `godot --headless --path . -s tests/run_tests.gd`: 165 passed, 0 failed, 3,126
  checks (new `tests/integration/test_game_screen.gd`: a game opens with its report and the
  advisor's first steps complete, End Turn and the checklist play a turn, orders are given from the
  views, events block End Turn, and every view and overlay passes the explanation and layout audit
  as a PC and a phone at 100% and 200% text, on a new game and on one 24 turns in);
  `tools/validate_data.gd`: 0 errors, 1,356 strings; the screenshot tour
  (`xvfb-run -a -s "-screen 0 2560x1600x24" godot --rendering-driver opengl3 --path . -s tools/screenshot_tour.gd -- --out <dir>`):
  176 screenshots, 0 audit issues, 325 numeric exemptions, each with its reason (the largest game
  classes: settlers and jobs counted from the colony, objective targets, turns left, build
  times). **Unverified:** the web smoke test on this build (CI runs it) and real phones.

### Outsourced assets: the intake tool and the first delivery (DESIGN_LOG 93)

- `tools/import_assets.py` (§15.2): checks each batch zip against the manifest, the licence
  rules and the briefs (format, size, length, loudness and true peak, transparency, SVG rules),
  converts (music to Ogg Vorbis quality 6, sounds to 16-bit WAV, painted art to lossy WebP at
  display size), writes the Godot import settings, marks ids delivered and credits each batch.
- Ingested 131 ids in 9 batches: sounds 1–2 (40), music 1 (28), VFX 1 (17), story scenes 1 (7),
  portraits 1 (6 neutral), ships 1 (17), title key art and logos (5), store art (11, kept out of
  the game's pack). Two warnings, no failures: `beacon_activate` had 7.6 ms of leading silence
  (trimmed); `logo_dark_on_light` uses two darker shades outside the palette.
- In the game: real sounds and music play; the title shows the key art with the menu in its calm
  left side and the vector logo; portraits are painted and cut to their disc; story scenes are
  painted and cropped, not stretched; the showcase uses the real scenes; the project icon is the
  delivered emblem.
- **Verified:** `godot --headless --path . -s tests/run_tests.gd`: 160 passed, 0 failed, 3,006
  checks (new `tests/unit/test_assets.gd`); `tools/validate_data.gd`: 0 errors; the screenshot
  tour: 108 shots, 0 audit issues (before the showcase switched to the real scenes; its two
  states re-shot with 0 issues); web export: 48.2 MB as a gzip download (budget 150 MB), with no
  store art in the pack. **Unverified:** the web smoke test on this build (stopped at the
  Owner's request to save usage).

### Simulation: the Scenario 1 rules (DESIGN_LOG 51–84)

- State schema 2 (research branches, build queues, governors, ordinances, surveys, modifiers,
  events, the event log, objectives, famine and autonomy counters) with migration `v1_to_v2`.
  **Verified:** `godot --headless --path . -s tests/run_tests.gd`: the M0 fixture save still loads
  and passes the invariants, and a new schema 2 fixture (`tests/fixtures/saves/s1_v2.json`, 16
  scripted turns of Scenario 1) does too.
- Rules in `sim/rules/`, each with breakdowns: economy (jobs by priority, district and colony
  bonuses, flat upkeep and consumption, industry input and mineral shortages, caps and overflow,
  influence), population (growth, homelessness, famine), stability (every §5.4 source, bands,
  unrest and autonomy), research (costs, seeded hands, carry-over, rerolls, story and objective
  techs), construction (queues, tiers, adjacency, building limits, demolition, rushing),
  governors (advisor plans with reasons, purses, vetoes), ordinances, civilian ships (surveys,
  outposts, colonisation), the market, objectives and the tutorial. **Verified:** the test run
  above: 135 passed, 0 failed, 1,196 checks, including Aster's starting numbers against §5
  (food +13.00, energy +10.00, minerals +11.00, research 1.80 per branch, influence +4.00,
  housing 20, stability 67).
- Event engine: triggers from a closed set of conditions with Why? reasons, scripted and status
  chains, a paced director (at most one emergent event every 4–6 turns), choices with costs,
  lasting modifiers, "Uncertain" outcomes on the EVENTS stream, delayed chain steps, and the
  log. **Verified:** `--filter events` (7 tests).
- 21 new commands, each validated with a reason (districts, upgrades, demolition, buildings,
  ships, queue edits, rushing, research picks and rerolls, ordinances, governors, vetoes,
  surveys, outposts, colonising, event choices, tutorial steps, trades). **Verified:**
  `--filter commands` (every type round-trips through the registry).
- **Golden re-baseline.** Reason: "M1: the economy, events and orders run in every phase; schema
  2". New golden: 24 scripted turns of Scenario 1 (`tests/golden/s1_hashes.json`). **Verified:**
  `--filter golden` (4 tests, including a save and load at every turn).

### Balance pass (DESIGN_LOG 92)

- Cheaper tier 1 and 2 technologies, a leaner Scenario 1 start (food, influence), dearer Colony
  Ships in food, a Market Exchange paid partly in metals, metal costs on the advanced buildings,
  and advisor and bot changes (full stocks, workerless output, saving up for a clear best
  option). Tests that pinned the old numbers now read them from the rules; the golden hashes are
  re-baselined with this reason. **Verified:** `tools/balance_loop.sh <dir> 1-20` (the CI balance
  job's runs): invariants 0 problems in 100 runs; pacing median turn 74 (was 78); everything
  matters fails only on the Foundry (0%) and the Research Institute (3%), where it failed on
  four buildings; hoarding still 80 of 80 runs (food 84, metals 80, influence 51, energy 33,
  was 115, 81, 51, 41); balanced on Normal still wins 20 of 20. The remaining failures are
  design questions for the Owner. `godot --headless --path . -s tests/run_tests.gd`: 157 passed,
  0 failed.

### The title is the main scene; lit-sphere planets; the tour and web smoke cover the app (DESIGN_LOG 91)

- The game now starts on the title (`ui/screens/app_root.tscn`); the UI showcase is a debug-build
  entry on it.
- Planets are lit spheres drawn by `ui/map/planet_sphere.gdshader`: a painted-looking surface
  from 3D noise on the sphere (seas, land, ice caps and clouds; dunes; ice cracks; craters;
  swirling haze; gas-giant bands with a storm), a soft terminator, a rim light and an atmosphere
  glow, all from the type's palette and the seed. Ringed gas giants draw their rings in two halves
  around the sphere; asteroid belts are unchanged.
- The screenshot tour also visits the app: title, campaign, briefing, the game route, the debrief
  of a real win (the balanced bot plays Scenario 1 to victory first), with a legacy chosen and
  lost, the Codex, an entry and the Codex over a screen. **Verified:** `xvfb-run -a -s "-screen
  0 2560x1600x24" godot --rendering-driver opengl3 --path . -s tools/screenshot_tour.gd -- --out
  screens/`: 108 screenshots, 0 audit issues.
- The web smoke test also opens the game with `?smoke=begin`, which starts Scenario 1 and plays
  one turn (auto-saving it), and checks that the browser reaches the same state hash as the
  desktop (`tools/smoke_hash.gd`). **Verified:** `node tools/web_smoke.mjs --build build/web
  --expect-hash 8d3b3f7d3ce6` after a web export: PC, phone and iPad each reached turn 2 with
  state `8d3b3f7d3ce6` and 1 save; a wrong expected hash fails all three.

### Codex, Scenario 1 subset (DESIGN_LOG 90)

- The Codex from the title (search; categories, list and entry side by side on PC, falling back
  to two columns with large text; list then entry on phones) and over any screen: every "Codex"
  link in a breakdown now opens its entry, with Back through the links followed. 22 mechanics
  pages in `data/codex/*.md` quote their numbers from the rules and data (`CodexFacts`), so they
  cannot disagree with the game; resources, districts, the buildings and technologies Scenario 1
  can offer, its ordinances and civilian ships, Ember's worlds and traits, and its cast are built
  from the data, with costs as explainable chips, effects and "See also" links; with a game
  running, every event step seen so far. **Verified:** `--filter codex` (5 tests: coverage of
  Scenario 1's scope, every link resolves, all 20 mechanic links that breakdowns make have an
  entry, live numbers, search and seen events) and the id audit on the Codex, an entry, a
  mechanics page, a search and the overlay as a PC and a phone at 100% and 200% text.

### Saves and campaign progress (DESIGN_LOG 89)

- `SaveService`: an auto-save after every resolved turn in a ring of 10, a checkpoint every fifth
  turn in a ring of 6, numbered manual saves, deletion, a listing read from the save envelopes
  (kind, scenario, turn, seed, thumbnail), and a 320-pixel-wide PNG thumbnail beside each save
  when a renderer is running. A lost debrief offers the newest checkpoint of that game from before
  the loss. Campaign progress (difficulty, wins, legacies) is kept in `user://campaign.json` and
  written after every change. Continue on the title picks up the newest auto-save.
  **Verified:** `--filter save_service` (4 tests: both rings over 40 turns, the checkpoint a loss
  goes back to, manual saves, deletion, auto-saving only while persistence is on, the campaign
  file across a restart).

### Audio (DESIGN_LOG 88)

- `Audio` autoload: UI, Effects and Music buses under Master; UI, effects and music volumes and
  mute in `Settings` (saved); every §15.4 sound by id, from its delivered file or, until then, a
  blip synthesised from a recipe in `app/sound_synth.gd` (soft, D major pentatonic, the same
  samples every time); music cues per screen (the main theme on the title and campaign, the
  scenario's briefing and main tracks, a sting at the debrief) that crossfade and stay silent
  until the tracks are delivered. Buttons, overlays, pinned breakdowns, warning toasts and End
  Turn make their sounds. `tools/audio_preview.gd` writes every fallback to WAV with a length and
  peak report; CI uploads them as the `audio-preview` artifact. **Verified:** `--filter audio`
  (5 tests: buses follow the settings, all 40 ids have a fallback or are a bed, lengths 0.05 to
  2.22 s, peaks at most 0.85, deterministic renders, silent music cues, UI sounds) and
  `godot --headless --path . -s tools/audio_preview.gd` (39 sounds written).

### Screens: the app shell and the campaign flow (DESIGN_LOG 85–87)

- `AppRoot` (`ui/screens/app_root.tscn`) hosts one screen at a time and routes title → campaign →
  briefing → game → debrief, plus the showcase in debug builds. Only screens that exist are
  offered; until the game screen lands, a stand-in names the game that Begin started. Not yet the
  main scene: the showcase stays the main scene until the M1 screen work is complete.
- Title (the sky with lane pulses, or the painted key art once delivered; Continue opens the newest
  save that loads), campaign select (the difficulty preset, three scenario cards: ready, won with
  its legacy, locked until the one before is won, or not in this build), briefing (Archivist
  Sola, the briefing, required and optional objectives, the difficulty, Begin) and debrief (the
  outcome and why, the objectives as they ended, the legacy pick after a win; Try again after a
  loss). Phones scroll the scenario cards sideways and put each screen's buttons in its heading
  row. `CampaignProgress` holds the difficulty, wins and legacy picks for the session.
  **Verified:** `godot --headless --path . -s tests/run_tests.gd -- --filter flow_screens` (2
  tests: the whole flow driven through the AppRoot, and the id audit on 8 screen states as a PC
  and a phone at 100% and 200% text, 0 issues) and `--filter campaign_progress` (3 tests).
- Fixed: a tab button marked pressed before it entered the tree lost the mark, so the showcase's
  page and text-size tabs never showed which was selected. Fixed: a portrait's shoulders were
  drawn outside its disc, over the text beside it. **Verified:** the full suite (143 passed, 0
  failed, 1,498 checks) and `xvfb-run -a -s "-screen 0 2560x1600x24" godot --rendering-driver
  opengl3 --path . -s tools/screenshot_tour.gd -- --out screens/` (68 screenshots, 0 audit
  issues).

### Display building blocks for the M1 screens

- Effects as readable text (`sim/explain/effect_text.gd`), with signed number arguments in the
  string layer. New components: `EffectList`, `CostChips`, and code placeholders for story scenes
  (`StoryScene`) and speaking characters (`Portrait`), drawn from `data/vignettes.json` and
  `data/portraits.json`. `AssetIds` resolves a §15 id to a delivered file, or to nothing while
  outsourcing is on hold. **Verified:** `--filter effect_text` (3 tests, 221 checks: every effect
  in every event choice reads without a raw placeholder).
- `docs/BUILD_PROMPT.md` rewrite 4: M1 progress, the balance status, the screen plan and where to
  resume. Documentation only.

### Content

- Scenario 1 is playable: the full start state (Ark Hull, Spaceport, both ships, seeded research
  hands), 4 required and 3 optional objectives, 14 tutorial steps, loss rules, locked
  ordinances, the tech pool and the balance scope. Cinder is now a small dome world (DESIGN_LOG
  66).
- 16 event chains with 36 fully written steps: The Founders' Vote, Cold Sleepers, Labor Strike,
  The Sealed Order (steps 1–2), The Ark's Last Engine; the status chains Unrest, Empty Granaries
  and Envoys of the Autonomy; and 8 emergent chains (Solar Flare, Crop Blight, Mine Collapse,
  Founding Day, The Frontier Doctor, Refugee Slowboat, Ice Comet Capture, Orbital Debris
  Cascade). Every body is 60–140 words. **Verified:** `godot --headless --path . -s
  tools/validate_data.gd`: 0 errors, 0 skipped checks, including the new reachability walk and
  event word counts.

### Bots and balance telemetry

- Bot policies balanced, economy, turtle and random-legal play the whole scenario through the
  same commands as a player; per-turn telemetry now records income, gross income, caps,
  overflow, builds, techs, events, objectives and the outcome. `tools/telemetry_report.gd`
  computes all five balance gates. **Verified** on 6 seeds per policy (105 turns, Normal):
  balanced wins 6 of 6 (median win turn 79; expected 70); random-legal wins 0 of 6; no dead
  turns; end-turn p95 34 ms. On CI, 20 seeds per policy plus Story (run 36006538014): balanced
  20/20 on Normal and 20/20 on Story, median win turn 78; random-legal 0/20; end-turn p95 36 ms.
  **Failing, still being tuned:** no hoarding (80 of 80 runs: food early, metals after the
  colony ships, influence, energy), everything matters (Foundry 0%, Research Institute 1%,
  Fusion Plant 3%, Hydroponics Bay 11%), and the balanced win rate on Normal is above the 60–90%
  band.

## After M0

- Display renames and units (Owner request, DESIGN_LOG 42): Metals (was Alloys), Ordinance (was
  Edict), settlers (1 pop = 1,000), and units kt, GW, Mt, kt on food, energy, minerals and metals
  in breakdowns, rate labels and the "More" drawer. Internal ids are unchanged. **Verified:**
  `godot --headless --path . -s tools/validate_data.gd` (0 errors, 420 strings),
  `godot --headless --path . -s tests/run_tests.gd` (85 passed), and the screenshot tour (68
  screenshots, 0 audit issues), with `screens/pc_100/02_breakdown_pinned.png` inspected.
- Art and sound direction (Owner, DESIGN_LOG 45–49): a flat interface over "painted diorama"
  world art; a visual-novel-style soundtrack with character themes and mood cues from M1; ships
  as top-down painted sprites; portraits with optional expressions; §15 briefs rewritten to match.
  Documentation only.
- The web build budget is 150 MB as the compressed download (Owner). The CI size step now checks
  150,000,000 bytes. **Unverified** until the next CI run.
- `docs/BUILD_PROMPT.md`: the rewritten build brief (status, the full game, remaining milestones,
  and outsourcing briefs with an intake contract for sound, music, VFX and art). Documentation
  only.

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
  **Verified:** [run 35977347923](https://github.com/mariyaholic/starfire_hearth_v2/actions/runs/35977347923)
  passed every job on its first run; the deploy job only runs on `main`.
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
