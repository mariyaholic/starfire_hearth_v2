# STARFIRE HEARTH: Complete Build Prompt (rewrite 4, M1 in progress)

**To the builder** (the AI coding agent reading this): this document is your whole brief. You are
building a complete game in the GitHub repository `mariyaholic/starfire_hearth_v2`, working alone
under the direction of the project Owner. It replaces the original build prompt. It keeps every
game-design rule of the original, records what milestone M0 has already built, and adds the
Owner's decisions from the M0 review:
- display renames and units
- a flat interface over painted-diorama world art
- a visual-novel-style soundtrack and story presentation
- a 150 MB web budget
- a pipeline for outsourced art, sound and music, on hold for now, so the game is built against
  code placeholders

Rewrite 4 adds the M1 simulation as built, its design decisions (DESIGN_LOG 51–84), the balance
status, and exactly where to resume: see **M1 progress and where to resume**, right after the
status table.

Read the whole document before writing any code.

| Part | Contents |
| --- | --- |
| §0 | How to work |
| §1–§8 | What to build: the game, its rules, UX, screens and art |
| §9 | The architecture as built |
| §10–§12 | Content scope and milestones: what is done, what is left |
| §13 | Reference data and formats |
| §14 | Decisions: made, and still open |
| §15 | Outsourced assets: ready-to-use briefs and the intake contract |

Where this document is silent, choose the option that best serves the pillars in §2. Record that
choice in `docs/DESIGN_LOG.md` and list it in your next milestone report so the Owner can
overrule it.

**Names in this document.** The player-facing name comes first. Where the code uses a different
id, it follows in backticks, and the id never changes: renaming is display text only (§5.0).
For example, **Metals** (`alloys`) and **Ordinances** (`edict`).

---

## Project status at the time of writing

| Item | State |
| --- | --- |
| Repository | `mariyaholic/starfire_hearth_v2`, **public**. Licence: "All rights reserved" (§14) |
| M0: Foundation and UI kit | **Built and merged** (PR #1). CI green. The web build is deployed to GitHub Pages at `https://mariyaholic.github.io/starfire_hearth_v2/`. The Owner approved the look |
| After the M0 review | Display renames and units (§5.0); painted-diorama world art (§8); a visual-novel soundtrack and story scenes (§5.10, §8.6); the web budget raised to 150 MB (§9.11); this prompt rewritten (PR #2) |
| Outsourced assets | **First delivery ingested** (DESIGN_LOG 93): sounds batches 1–2, music batch 1 (all 28 tracks), VFX, the seven Scenario 1 story scenes, the six neutral portraits, ships, the title key art and logo, and store art. Still on their code fallbacks: story scenes batch 2 (18), the portrait expressions (18), `title_cast` and `logo_title` |
| M1: First Light | **In progress** on branch `claude/starfire-hearth-build-cs2vb6`, draft PR #3. The plan is `docs/milestones/M1_PLAN.md`. Built and pushed: the simulation, data, story, bots, telemetry, the app shell and campaign flow screens, audio, saves, the Codex, lit-sphere planets, the tour and web smoke over the app, a balance pass, the asset intake with the first delivery, and the game screen with its views, overlays, settings, load and credits. The five balance gates pass after the review of DESIGN_LOG 95 and 96, and the M1 report is written. Next: the Owner plays the checkpoint build |
| Main scene | The title (`ui/screens/app_root.tscn`); the UI kit showcase is a debug-build entry on it. Begin opens the game screen |
| Next | The Owner plays the checkpoint build and answers the report's questions ("Balance status"); then merge and deploy (which publishes the build) and the playtest on Pages |
| Toolchain | Godot 4.7.2-stable, Compatibility renderer, statically typed GDScript |

---

## M1 progress and where to resume (rewrite 4)

### What is built (all pushed; each claim's verification is in the CHANGELOG)

| Area | As built | Verified by |
| --- | --- | --- |
| Data | 15 buildings, 37 techs, 5 ordinances, 6 hulls, 12 modules, district tiers, 3 difficulty presets, 3 legacies, origin effects, 25 story-scene and 6 portrait placeholder records, `data/asset_manifest.json` (169 ids) | `tools/validate_data.gd`: 0 errors, 0 skipped checks |
| Scenario 1 | Playable data: start state (Ark Hull landmark, Spaceport, both ships, seeded research hands), 4 required + 3 optional objectives, 14 tutorial steps, loss rules, `tech_pool`, `locked_ordinances`, `locked_buildings`, `balance_scope`, `expected_turns` 70, `director_start` 8. Cinder is now small (DESIGN_LOG 66) | the validator's scenario checks and reachability walk |
| State | Schema 2 with migration `v1_to_v2`; fixtures `tiny_v1.json` and `s1_v2.json` | `tests/unit/test_saves.gd` |
| Rules | `sim/rules/`: `economy`, `production`, `population`, `stability`, `research`, `construction`, `governor`, `ordinances`, `ships`, `market`, `objectives`, `tutorial`, `events`, `effects`, `modifiers`, `colony_rules`, `hex_grid`; `sim/ai/advisor.gd` | 157 tests, 2,327 checks (`tests/run_tests.gd`), incl. Aster's start numbers against §5 |
| Commands | 22 player commands (§9.12) | every type round-trips (`--filter commands`) |
| Story | 16 chains, 36 steps (§10.6 list below) | the validator checks every body is 60–140 words |
| Bots | balanced, economy, turtle, random-legal (`tools/bot/bot_policy.gd`); per-turn telemetry; all five gates in `tools/telemetry_report.gd` | CI balance job (20 seeds × 4 policies + Story) |
| Golden | `tests/golden/tiny_hashes.json` and `s1_hashes.json` (24 scripted S1 turns), re-baselined with a CHANGELOG reason | `--filter golden` |
| UI groundwork | `sim/explain/effect_text.gd` (effects as keys and args), `ui/components/effect_list.gd`, `cost_chips.gd`, `story_scene.gd` and `portrait.gd` (data-driven placeholders), `app/asset_ids.gd` (§15 id → delivered file or null) | `tests/unit/test_effect_text.gd` |
| App shell and flow screens | `ui/screens/app_root.tscn` (the main scene; routes; only built screens are offered), `ui/screens/flow/`: title (sky or key art; Continue), campaign (difficulty, scenario cards), briefing, debrief (legacy pick, Try again, the checkpoint after a loss), and a stand-in for the game route; `app/campaign_progress.gd`; `Game.new_game(..., difficulty)` and `Game.resume(state)` | `tests/integration/test_flow_screens.gd` (the flow, and the id audit on 13 states × 4 layouts), `tests/unit/test_campaign_progress.gd` |
| Audio | `app/audio.gd` (UI, Effects and Music buses; volumes and mute in `Settings`), `app/sound_synth.gd` (a synthesised fallback for every §15.4 id), music cues per screen (the delivered tracks); `tools/audio_preview.gd` (CI artifact `audio-preview`) | `tests/unit/test_audio.gd` |
| Saves | `app/save_service.gd`: auto-save after every turn (ring of 10), a checkpoint every 5 turns (ring of 6), numbered manual saves, thumbnails, a listing from the envelopes; `user://campaign.json` | `tests/unit/test_save_service.gd` |
| Codex | `ui/codex/` (index, live facts, entry view, overlay) and `ui/screens/codex_screen.gd`; 22 mechanics pages in `data/codex/*.md`; every breakdown's Codex link opens its entry | `tests/unit/test_codex.gd`; the Codex states in the flow audit |
| Planets and tooling | `ui/map/planet_sphere.gdshader` (lit spheres); the screenshot tour visits the app (108 shots, the debrief of a bot-won game); the web smoke test plays a turn and matches the desktop's state hash (`tools/smoke_hash.gd`) | the tour; `node tools/web_smoke.mjs --expect-hash` |
| Game screen | `ui/screens/game/`: `GameScreen` (top bar, rail or tab bar, advisor with highlight, Undo, End Turn with its checklist, the end-of-turn flow), seven views (`colony_view` planner with preview, queue, jobs, governor and shipyard; `system_view`; `galaxy_view`; `research_view`; `ordinances_view`; `market_view`; `objectives_view`), overlays (`event_overlay`, `turn_report_overlay` with the checklist, `why_overlay`), `game_model` (top bar and checklist from a state) and `game_ui` (shared builders); `ui/screens/flow/settings_screen`, `load_screen` and `credits_screen` | `tests/integration/test_game_screen.gd` (a game played from the first report, orders from every view, events, and the audit on every view and overlay at four sizes); the tour's 17 game states |
| Asset intake | `tools/import_assets.py` (§15.2; checks, converts, imports, credits); `assets/delivered/<kind>/`; 131 ids delivered in 9 batches; painted portraits cut to their disc, scenes cropped not stretched, the title's key art and vector logo; the project icon is the delivered emblem | `tests/unit/test_assets.gd` (every delivered id loads); the tour |

The story chains: scripted Labor Strike (T5), The Founders' Vote (T10), Cold Sleepers (T18), The
Sealed Order steps 1–2 (T40, then when decoded), The Ark's Last Engine (T45+); status Unrest,
Empty Granaries (famine), Envoys of the Autonomy; emergent Solar Flare, Crop Blight, Mine
Collapse, Founding Day, The Frontier Doctor, Refugee Slowboat, Ice Comet Capture, Orbital Debris
Cascade.

### Balance status (after the review of DESIGN_LOG 95 and 96; the CI balance job's settings: 20 seeds per policy on Normal, plus balanced on Story)

| Gate | Result | Band |
| --- | --- | --- |
| Invariants | PASS: 0 problems in 100 runs, 8,789 turns | 0 |
| Performance | PASS: end-turn p95 44 ms | < 300 ms |
| Winnable, balanced on Normal | PASS: 15 of 20 within 1.2 times the expected duration (19 of 20 win at all; was 20 of 20 within 1.5 times) | 60–90% |
| Winnable, random-legal | PASS: 0 of 20 | < 20% |
| Winnable, balanced on Story | PASS: 20 of 20 | 85–100% |
| Pacing | PASS: median win turn 78 (was 74) | 56–84 |
| No dead turns | PASS: median 5% | < 25% |
| No hoarding | PASS: 0 of 40 balanced runs (was 80 of 80 runs of every bot but random-legal) | ≤ 20% of runs |
| Everything matters | PASS: Storehouse 37%, Fusion Plant 39%, Research Institute 47%, Civic Hall 48%, Hydroponics Bay 49%, Park Commons 61%, Clinic 83%, Habitat Dome 83% (was Foundry 0%, Research Institute 3%) | buildings ≥ 25%, techs ≥ 15% |

Balance gates are advisory in CI (`--balance advisory`) until the M1 gate (DESIGN_LOG 82).
What the review changed, and which of it is a change of play and which only of a count (95, 96):
- **Play, Scenario 1:** the Ark Hull opens the market from turn 1; the Market Exchange and the
  Foundry are locked; the Research Institute is one per empire with +2.00 research in each branch
  and costs 120 minerals; the Storehouse, Fusion Plant and Civic Hall are cheaper (the Civic Hall
  gives 1.50 influence); the balanced bot keeps the larger of seven turns of income and the next
  Colony Ship's price.
- **A count only:** "winnable" is a win within 1.2 times the expected duration (was 1.5), which
  does not make Normal harder for a person: the scenario has no deadline, so a competent player
  loses only if the capital declares autonomy. Events at 125% or 150% severity change nothing.
  The hoarding gate measures the balanced bot only; the Foundry left the balance scope.
- **Open for the Owner:** whether a 60–90% band suits an onboarding scenario at all, and whether
  Normal needs a real turn limit or a harsher status chain.

What the balance pass learned, so it is not repeated:
- Minerals are the bottleneck and the market is the valve (surplus sold for energy, energy buys
  minerals), but its building competes for the same minerals. A market with no technology
  (available from turn 1) broke pacing (median turn 94). Halving metallurgist output starved the
  market's metals and delayed it to turns 60–100. A research priority for the market's technology
  changed nothing, because the building waited for minerals, not the technology.
- Food sits near 280 against a line of about 250 (ten turns of gross) until the market opens
  around turn 45; metals pile up between the two Colony Ships.
- Local loop: `tools/balance_loop.sh <dir> 1-20` runs the four policies and Story in parallel
  (about 5 minutes on 4 cores), then the gates.
- The market from turn 1 (the Ark Hull) settled hoarding; a technology-free market had broken pacing
  in the earlier pass because its building still had to be paid for. The Institute needed a limit of
  one per empire, or every colony built its own and three other buildings lost their slots.

### Remaining M1 work, in order

Done since rewrite 4: the app shell and flow screens, audio, saves and campaign progress, the
Codex, lit-sphere planets, the title as the main scene, the tour and web smoke over the app, a
balance pass, the asset intake with the first delivery, and the game screen with every view and
overlay of the plan below (CHANGELOG, DESIGN_LOG 85–94). What is left:

1. **The balance questions** above (the Owner's calls), then a last tuning pass.
2. **M1 report** (`docs/milestones/M1_REPORT.md`), merge, deploy, stop for the Owner's playtest.
3. Known gaps, small: a colony cannot be renamed yet (the command exists), the game screen has
   no keyboard shortcuts beyond Esc for the menu, and the phone layouts have been audited in the
   simulator but not on a real phone.

### The screen plan (as built; DESIGN_LOG 94 says how it differs)

- **`AppRoot`** (built; the main scene, `ui/screens/app_root.gd`): hosts
  one screen at a time and routes title → campaign → briefing → game → debrief, plus Codex,
  settings, load and the showcase. A route joins `AppRoot.routes()` when its screen exists.
- **Title** (built): Continue (newest save), Campaign, Load, Codex, Settings, Credits, Showcase
  (debug), Quit (desktop).
- **Campaign** (built): the three scenario cards (S2 and S3 locked until the one before is won) and the
  difficulty preset with its description.
- **Briefing** (built): `scenario.s1.briefing`, the objectives, Begin. **Debrief** (built):
  outcome, objectives, the legacy pick (1 of 3), then back to the campaign; after a loss, Try
  again (the checkpoint reload joins it with the save rings).
- **Game screen** (built): the top bar (every resource, net and breakdown; date; menu); navigation (a rail
  on PC, a bottom tab bar on phones); the current view in the centre; a context panel (right side
  on PC, a bottom sheet on phones); the advisor card (tutorial: current step, goal, highlight,
  completes on the player's action through `Tutorial.condition_met` or a UI event, then
  `AcknowledgeCommand`); End Turn with the checklist (pending events block; idle Construction
  Ship, empty research card and overflow warnings are listed; critical alerts must be
  acknowledged).
  - **Galaxy view**: Ember and the six fogged neighbours; the lanes are locked, with the reason.
  - **System view**: the star, planets on orbits, ships; a planet's panel shows survey state,
    traits, slots, and the actions Survey, Colonise and Build an Outpost (with costs and reasons).
  - **Colony planner**: the hex grid from `HexGrid.coords` with `HexCell`s; header stats (settlers,
    housing, jobs, stability, growth: each an Explainable); a slot's menu of districts and
    buildings with cost chips, the adjacency ghost and the change it would make (compare
    `Economy.colony` before and after on a cloned state); the queue (cancel, move up, rush); job
    priority; the governor (on or off, focus, budget, plan with its reason, veto).
  - **Research**: three branch columns of cards with progress and cost breakdowns; reroll; a
    tech-tree list by branch and tier.
  - **Ordinances**, **Market** (once open), **Objectives** (progress per objective).
- **Overlays**: the event scene (StoryScene, speaker Portrait and name, title, body, choices with
  CostChips and EffectList, uncertain outcomes with their chances, the hint); the turn report (top
  3, then grouped, each with jump-to); Why? (the WhyLog entries for the selection); settings;
  save and load.
- **After End Turn**: `Game.end_turn()`, auto-save, the report, then each pending event in turn;
  a won or lost outcome opens the debrief.

### Builder notes (learned the hard way)

- Check every new script with `godot --headless --path . --check-only -s <script>`: `--import`
  does not report parse errors in a class script nothing uses yet.
- Never name a method after an Object virtual (`_set`, `_get`, `_init` with arguments...).
- Untyped declarations are errors, including `for` loop variables.
- Never `pkill -f` a pattern that appears in your own command line: it kills the shell (exit
  144). Kill by PID.
- A probe script that fails before `quit()` hangs: run probes under `timeout`.
- In test messages, `%` must be escaped as `%%` when the string is formatted.
- String keys that code builds from ids go through `sim/explain/names.gd`, so the data checks can
  see them; literal keys with the prefixes in `tools/data_checks.gd` must exist.
- String arguments: `_key` resolves a key; `_c` is a centi amount; `_sc`, `_sp` and `_bp` are
  signed centi, points and basis points.
- Local balance loop: run the four policies in parallel with `tools/bot_run.gd --seeds 1-6
  --turns 105 --out <dir>`, then `tools/telemetry_report.gd -- --in <dir> --balance advisory`.
- `set_anchors_preset()` on a control already in the tree keeps its (zero) rect; code-built
  full-rect controls use `set_anchors_and_offsets_preset()`.
- An autowrapping label inside a `CenterContainer` gets no width and wraps every word: give its
  column a minimum width.
- A node that is built but never added to the tree leaks (the test run warns at exit).
- Headless runs must not start audio playback: a stream still playing at exit leaks.
- A `-s` script that names UI classes (which use autoloads) can hang: load them with
  `load(path)` and call them with `.call()`.

---

## 0. How to work

### 0.1 Operating rules

**Plan first, then build.** At the start of each milestone (§12), write
`docs/milestones/M<n>_PLAN.md` with:
- the goal
- a task list
- the files you expect to touch
- the risks
- how you will verify each gate

Then execute it.

**Small, working commits.**
- Use conventional commit messages (`feat(sim): …`, `fix(ui): …`, `content: …`, `test: …`,
  `docs: …`, `ci: …`).
- The build and tests must pass at every commit.
- Work on a branch and open a pull request into `main`.
- Merging to `main` deploys the web build.
- Check each commit with import, `validate_data` and the full test suite before pushing.

**Verified vs. unverified.**
- In every report and changelog entry, a claim is **Verified** only if you ran a command that
  proves it, and you name that command.
- Everything else is **Unverified** and must be labelled that way.
- Never write an unverified claim as a fact.
- A green CI check proves only exit codes. Read the logs for the numbers.

**Play what you build.** A feature is not done until it has been exercised in three ways:
- by a headless test
- by a bot playthrough
- by at least one screenshot captured from a real render (§9.9)

Look at your screenshots and judge them the way a player would. Also load the exported web build
in a browser (`tools/web_smoke.mjs`); desktop renders do not prove the web build.

**Keep the docs proportional.** The only documents are:
- `README.md`
- `CHANGELOG.md` (newest entries first; one entry per meaningful change)
- `docs/DESIGN_LOG.md` (decisions, each with a one-line reason)
- `docs/milestones/*` (a plan and a report for each milestone)
- `docs/BUILD_PROMPT.md` (this brief; the Owner asked for it)
- `docs/assets/*` (the outsourcing briefs and asset manifests of §15, when the Owner uses them)
- the Codex, generated from data

Do not write process documents that are bigger than the code they describe.

**Stop at every gate.** At the end of each milestone:
1. Merge to `main`, so CI deploys the web build to Pages and uploads artifacts.
2. Write `docs/milestones/M<n>_REPORT.md`.
3. Stop and wait for the Owner's playtest verdict before you start the next milestone.

**Ask, don't guess, on taste.** If a decision changes how the game feels and §14 does not settle
it:
- give the Owner 2–3 concrete options with your recommendation
- continue with the recommended one until they answer

**Never cut the explanation layer to hit a deadline.** Cut content instead. A smaller game that
explains itself beats a bigger one that doesn't.

**Outsourced assets never block the build.** Every asset kind in §15 has a procedural or
placeholder fallback in code. An asset that arrives replaces its fallback through the intake
pipeline (§15.2). An asset that never arrives costs nothing. Outsourcing is **on hold** for now
(Owner, before M1): build every screen against the placeholders, and address each asset by its
§15 id, so delivered files drop in later without code changes.

### 0.2 Repository bootstrap (done in M0)

M0 created the layout of §9.2:
- `.gitignore`, `.gitattributes`, `LICENSE` and `.godot-version`
- the vendored IBM Plex Sans and Mono fonts with their OFL files
- a GitHub Actions workflow with cached Godot and export templates

Nothing here needs redoing. Keep `.godot-version` pinned. Upgrade Godot only as a planned task
with a DESIGN_LOG entry and re-baselined golden hashes.

---

## 1. The game in one page

Starfire Hearth is a turn-based space 4X for PC and mobile, built in Godot 4 with GDScript. It
has a clean, flat interface over a painted-diorama world, and its story plays out in illustrated
scenes, like a visual novel.

**Premise: the Long Silence.** In 2297 the Sol relay stopped transmitting. There was no warning,
no last message, and no reply to anything sent since. The slowboat colonies that humanity seeded
across nearby stars over the previous two centuries have been alone ever since.

The player leads one of those colonies a hundred years into the Silence. They:
- grow frontier worlds into a civilisation
- cross the gap from sublight slowboats to jump drives
- meet a human successor state and the first alien species humans have ever encountered
- slowly uncover why Earth went quiet

The answer turns the player's greatest technology into their greatest risk.

**Format.**
- Turn-based. One turn is one month.
- Default game length: a 20–40 hour epic in sandbox mode. The campaign scenarios are 1.5–3 hours
  each.
- Single-player only. Premium one-time purchase; no ads, no in-app purchases.
- Platforms: Windows and Linux PC, Android, and Web (for playtesting); iOS once a Mac is
  available. Every screen is designed for PC and phone at the same time.

**The core loop (each turn):**
1. Read the turn report: the three things that matter most, and why.
2. Make decisions:
   - plan colony districts
   - pick research cards
   - move fleets and survey ships
   - answer events
   - handle diplomacy
3. End the turn. The simulation resolves it deterministically and explains every change.

**The long arc:**
- **Slowboat era:** slow, local, city-building-heavy.
- **Beacon era:** the region opens up; rivals and pirates matter.
- **Jump era:** fast and powerful, and loud.
- The Silence resolves into one of five endings.

## 2. Pillars and anti-goals

The pillars are listed in priority order. When two of them conflict, the higher one wins.

1. **It explains itself.** Every number on screen can be hovered on PC, or tapped or long-pressed
   on mobile, to show its breakdown: the base value, each modifier with its source, and the
   total. Every AI decision and every opinion comes with reasons the player can read. The player
   never sees an internal id. The question "why did that happen?" always has an answer somewhere
   in the game.
2. **Every choice costs something.** Each resource has at least two sinks that compete for it
   (§5.3). Hoarding is never optimal. Balance is measured by bot playthroughs (§12 gates), not
   argued.
3. **A space 4X at heart, with colonies as hearths.** The galaxy is the game: explore, expand,
   exploit, and deal with neighbours. Each colony is a compact hex district planner, where about
   two minutes of meaningful layout decisions make it feel like home.
4. **Stories you remember.** Three layers respond to what the player has done:
   - a main arc (the Long Silence)
   - an origin thread
   - emergent event chains
5. **Kill micro hell.** The game offers governors, auto-explore, auto-resolved combat with a
   replay, and batched turn reports. The depth lives in decisions, not in clicking.
6. **PC and mobile as equals.** Every screen works at 1920×1080 with a mouse, and at 2400×1080 on
   a 6-inch phone with touch.
7. **A clean interface over a painted world.** The interface is flat, geometric and readable at a
   glance. The world (story scenes, portraits, ships, key art) is painted-diorama art. Both share
   one palette (Owner decision after M0).

**Anti-goals.** Do not build:
- real-time play or pausable real-time
- multiplayer or netcode
- a modding API in v1 (the data files stay readable JSON anyway)
- visuals that depend on shaders (a few simple canvas shaders for glow are allowed only if a
  flat fallback exists)
- information that only appears on hover
- raw ids anywhere in the UI
- a resource with fewer than two sinks
- a system that no scenario teaches
- punishment the player cannot see coming
- losing without a checkpoint to go back to
- forced CRT or scanline effects
- weather simulation on planets
- ground combat in the POC
- a full species creator in the POC

## 3. Lessons from the previous prototypes

A first prototype of this game was abandoned. Do not repeat these mistakes:

| Mistake | What v2 does instead |
| --- | --- |
| Its gates tested the engine, not the game. They measured determinism, save/load equality and turn speed, and never asked whether a human understood the game or enjoyed it | Every milestone gate includes an explanation audit, balance telemetry and an Owner playtest |
| Resources had nowhere to go. In a measured 60-turn run the player banked thousands of food and hundreds of credits and science points it could not spend. The colony grew to more than three times the population win bar. The tech tree was 6 techs in a straight line | Every resource has competing sinks and caps, and telemetry flags hoarding |
| Its art was drawn by code and too small to read, while better concept art was never used | One flat visual language designed first (the UI kit, M0), used on every screen. Outsourced art enters through a strict intake (§15), so better art is actually used |
| The UI exposed the engine. It showed internal ids, gave no reasons, and had a tutorial that listed conditions instead of instructions | Explanation is pillar #1 and is audited automatically |
| The process outweighed the product. It had more governance text than game, and a rules engine in a separate language behind a bridge that could not ship | One language, one codebase, lean docs |

M0 of v2 added three lessons of its own:
- **Test the artifact the Owner will open.** The desktop tour passed, but only a browser test found
  that iPads received the PC layout (DESIGN_LOG 36).
- **Look at 200% text on a phone every time.** Layouts that pass at 100% break there (DESIGN_LOG
  40).
- **Read CI logs, not just check marks.**

## 4. Setting, story and factions

### 4.1 Tone

Hopeful frontier, hard science fiction. People are competent, communities are warm, and space is
vast and slow. Physics is respected:
- there is no faster-than-light communication without beacons
- there are no energy beings
- aliens are strange but biologically plausible

The writing is humane and specific, sometimes funny. Horror and grimdark are allowed where the
story leads there (the darker routes of the branching campaign, DESIGN_LOG 106). Every event
should give the player someone to care about.

### 4.2 Timeline (canon)

| Year | Event |
| --- | --- |
| 2140–2290 | The Slowboat Century: about 40 generation ships and sleeper ships leave Sol for stars within 20 light-years |
| 2261 | First jump-field experiment at the Sol L2 laboratory: a ship crosses 0.3 light-years in an instant |
| 2268–2292 | Sol builds the first beacons, relay stations that make jump lanes stable. Eleven beacons link Sol to the nearest colonies |
| 2294 | Sol's deep-space arrays record a structured signal, arriving from outside the region, that answers the jump wakes |
| 2296 | Sol's Quiet Directive: every beacon is dark, every jump drive is decommissioned, and all broadcasting stops. A final message to the colonies explains why |
| 2297 | The Sol relay goes silent. The final message never arrives; it was lost, and later suppressed (the Meridian thread) |
| 2397 | The game begins. Year 100 of the Silence |

### 4.3 The main-arc truth (revealed across the campaign and sandbox)

Earth went quiet on purpose. Every jump transit leaves a detectable wake in spacetime, and
something far away had begun to answer those wakes.

Sol shut the beacons down and asked its colonies to go quiet as well. The message carrying that
request was lost when the relay went dark. The one surviving copy, held by the Meridian
Directorate, was suppressed.

This makes jump drives both the player's great power spike and noise. The Noise meter (§5.9)
turns the story into a mechanic.

What answered the wakes is never fully shown. It is patient, distant and vast. The Vael have met
its attention before, and survived by going silent for ten thousand years.

**Five endings in sandbox mode (the Story victory):**
1. **Hide.** Dismantle the beacons, build the Quiet Drive, and seal the region in silence. You
   are safe and small.
2. **Warn.** Rebuild the relay to reach every lost colony, and gather them under the Quiet
   Accord. You become a federation of the careful.
3. **Answer.** Build the Great Array and make deliberate contact. The outcome depends on the
   preparation made along the way: Vael counsel, Noise discipline, and the scientific milestones
   reached.
4. **Shield.** Build the Hearthlight, a megastructure that masks the whole region's wake. You gain
   a costly, permanent protection.
5. **Homecoming.** Reach Sol itself through a restored beacon chain, and discover that Earth is
   alive and has been listening to you all along.

### 4.4 Player origins (humans only)

| Origin | Mechanical identity | Starting differences | Story thread |
| --- | --- | --- | --- |
| Generation Ark (campaign) | cohesive, slow and large | +2 starting pops, +10 stability, −10% research; unique capital building Ark Hull | the Ark's archive holds a sealed Sol order no one can open |
| Corporate Charter | trade and energy | +25% market rates, +1 trade-deal slot, −10 stability; unique building Charter Exchange | Halvorsen-Kade, the parent company, may still exist, and still wants its dividends |
| Exile Fleet | military | starts with 2 frigates and 1 corvette, −2 pops; unique building Fleet Yard | who exiled them, and why their records were wiped |
| Survey Mission (sandbox, M4) | exploration | +1 survey ship, +50% anomaly research, −1 housing per district | the mission's true target was a beacon Sol never admitted to building |

The player's polity in the campaign is called **The Ember Compact** (DESIGN_LOG 25; it can still
be renamed, §14).

### 4.5 Powers the player meets in the POC

**The Meridian Directorate**, a human successor state. It grew from the Meridian beacon-keeper
colony, which kept more of Sol's technology than anyone else.
- **Traits:** orderly, bureaucratic, expansionist and trade-minded. It believes it is Earth's
  rightful heir.
- **Personality:** Ambitious Steward. It values expansion and trade, fights for claims, but
  honours treaties.
- **Secret:** it holds the only intact copy of Sol's final message, and it suppressed that copy to
  justify its own jump programme.
- **Colour:** friend blue shading to steel.
- **Emblem:** a compass rose.

**The Vael**, the first aliens humans have met.
- **Biology:** long-lived and slow-metabolism. They are colonial organisms that communicate
  through modulated light.
- **Traits:** patient, cautious and courteous. They consider humans dangerously loud children.
- **Personality:** Cautious Elder. It values security and quiet, rarely declares war, and shares
  knowledge with those who stay quiet.
- **History:** they went silent ten thousand years ago, after they were "noticed".
- **Colour:** rival magenta shading to violet.
- **Emblem:** a spiral of seven dots.

**The Unlit**, pirates. They descend from beacon-station crews stranded when the network went dark.
- **Role:** a hazard, not a diplomatic partner. They raid lanes and demand tolls, but they can be
  bribed, hired or destroyed.
- **Colour:** alert orange-red.
- **Emblem:** a broken circle.

### 4.6 Named characters (the campaign cast)

| Character | Who they are |
| --- | --- |
| Archivist Imre Sola | The Ark's archivist and the advisor voice: dry, warm and scholarly, and they footnote everything |
| Steward Anneliese Varga | The Ark's elected leader: pragmatic, and worried about food |
| Captain Oduya Brandt | The Ark's first fleet captain: loyal, and bored of peace |
| Director Kasimir Hale | Head of the Meridian Directorate: charming, sincere in his own way, and hiding the message |
| Speaker-of-Seven | The Vael envoy. Its dialogue is rendered as translated light-patterns, with bracketed uncertainty in early contact |
| Mother Rook | Leader of the Unlit: bitter, clever, and open to a deal |

---

## 5. Core systems

**Fixed-point rule.** Every quantity in simulation state is an integer:
- resources in hundredths (centi-units: 1.00 food = 100)
- percentages in basis points (+10% = 1000)
- lane lengths in centi-light-years
- counts (pops, turns, stability and opinion points) as plain integers

Floats never enter simulation state. Rounding floors toward negative infinity (DESIGN_LOG 4).
Presentation divides for display.

### 5.0 Display names and units (Owner decision after M0)

These are **display text only**: ids, data keys, save fields and code keep the original names. The
units live in the string table and in `resources.json` (`unit_key`); `Fmt.unit()` and
`Fmt.suffix()` show them.

| Id | Shown as | Unit | Example |
| --- | --- | --- | --- |
| `food` | Food | kilotonnes, **kt** | "+12.2 kt / turn" |
| `energy` | Energy | gigawatts of grid power, **GW** | "120 GW", "+13.5 GW / turn" |
| `minerals` | Minerals | megatonnes, **Mt** | "250 Mt" |
| `alloys` | **Metals** | kilotonnes, **kt** | "+3.0 kt / turn" |
| `research` | Research | points (no unit) | "+2.7 / turn" |
| `influence` | Influence | points (no unit) | "60" |
| pops | **Settlers**. One pop is 1,000 settlers | thousands, **k** | "10k settlers eat" |
| `edict` | **Ordinance** | — | "Ordinance: Festival" |

Where the units appear:
- breakdown headers and totals
- rate labels ("Food on Aster +12.2 kt / turn")
- the "More" drawer ("Food (kt)")
- the Codex

Top-bar chips stay unitless to save width, and their breakdowns show the unit. Every rule in this
document is written in the original internal quantities: "1.00 food per pop" means 1.00 kt per
thousand settlers on screen.

### 5.1 Galaxy

**Stars** each have a spectral class that sets the star's colour and planet odds: M, K, G, F, A,
a white dwarf, or a binary.

**Systems** hold 1–6 planets, plus optional asteroid belts, specials and starbase slots.

**Lanes** connect systems:
- There are two kinds: **deep lanes**, which are sublight routes, and **beacon lanes**, which exist
  only between two active beacons.
- Each lane has a length in light-years (1–6).

**Fog** has three states:
- **Unknown:** only the star position is shown.
- **Surveyed:** planets and specials are known, but shown as of the last visit.
- **Observed:** currently in sensor range, with live information.

**Specials in the POC:**
- nebulae (block sensors, +research outposts)
- dormant beacons
- derelicts
- ruins
- rich asteroid fields

### 5.2 Travel

| Era | Mechanism | Turns per lane |
| --- | --- | --- |
| Slowboat | sublight | `ceil(length_ly × 2 / speed)`; base speed 1 gives 2 turns per light-year |
| Beacon | a lane between two active beacons | 1 turn, whatever the length |
| Jump drive (late) | jump directly to any system within `jump_range` ly of a beacon or starbase | 1 turn |

- Moves resolve simultaneously at the end of the turn.
- Fleets that meet in a system engage if they are hostile.
- The UI always shows the ETA, the path, and the Noise cost of every move.

### 5.3 Resources, sources and sinks

| Resource | Stockpile cap (base) | Main sources | Sinks (competing) |
| --- | --- | --- | --- |
| Food (kt) | 500 | farmer jobs, Hydroponics Bay | 1.00 per pop per turn; pop growth (needs a positive net); colony ships (100); trade |
| Energy (GW) | 500 | technician jobs, Fusion Plant, clerks | upkeep of districts, buildings, fleets and beacons; market currency; ordinances |
| Minerals (Mt) | 500 | miner jobs, outposts | districts, buildings, construction ships, outposts; refined into metals |
| Metals (kt) (`alloys`) | 250 | metallurgist jobs (consume minerals) | ships, starbases, beacons, megaprojects |
| Research (Physics, Society, Engineering) | none (flows into the current cards) | researcher jobs, anomalies | techs; anomaly analysis; relic study; decoding the Sol order |
| Influence | 200 | +3 base per turn; +1 per colony with stability ≥ 60; treaties; events | outposts (50), claims, treaties, ordinances, card rerolls, event choices |

**Caps and overflow.**
- Storehouse buildings raise caps by 250 (metals by 125).
- Overflow above a cap is lost.
- The UI warns two turns ahead: "Food will overflow in 2 turns: consider growing, trading or
  storing".

**Market** (fixed rates in the POC, dynamic in sandbox):
- Energy is the currency.
- Buy/sell rates per 1.00 of: food 1.5/1.0, minerals 1.5/1.0, metals 6.0/4.0. Influence cannot be
  traded.
- It is available once the player has a Market Exchange or a trade deal.
- Every trade is shown with its exact rate.

### 5.4 Planets and colonies: the district planner

**Planet types (hard SF)**

| Type | Habitable | Habitability | Notes |
| --- | --- | --- | --- |
| Continental | yes | 100% | rare |
| Ocean | yes | 80% | +10% food |
| Arid | yes | 60% | +10% minerals |
| Ice | domes | — | +10% research |
| Barren | domes | — | +20% minerals |
| Toxic | domes | — | +20% energy |
| Gas giant | orbital only | — | energy and research outposts only |
| Asteroid belt | outpost only | — | minerals |

- Habitability multiplies the housing of Habitation districts and scales growth speed.
- A dome world needs the Habitat Domes tech. It has half its slots and habitability 40%.

**Size** sets the number of slots:

| Size | Tiny | Small | Medium | Large | Huge |
| --- | --- | --- | --- | --- | --- |
| Slots | 12 | 16 | 20 | 25 | 30 |

- Slots sit on a hex map, drawn as a planet surface disc cut into hex cells.
- 1–3 slots per planet are blocked (mountains, sea trench, crater) until a tech or event clears
  them.

**Districts.** The planner offers 6:

| District | Build cost | Build turns | Upkeep | Housing | Jobs | Job output |
| --- | --- | --- | --- | --- | --- | --- |
| Habitation | 50 minerals | 3 | 1.00 energy | 6 | 1 clerk | +2.00 energy, +1 stability to the colony |
| Agriculture ("Farm district") | 60 minerals | 3 | 0.50 energy | 1 | 2 farmers | +4.00 food each |
| Energy | 60 minerals | 3 | none | 1 | 2 technicians | +5.00 energy each |
| Mining | 60 minerals | 3 | 0.50 energy | 1 | 2 miners | +4.00 minerals each |
| Industry | 80 minerals | 4 | 1.00 energy | 1 | 2 metallurgists | each −6.00 minerals, +3.00 metals |
| Research | 80 minerals | 4 | 1.50 energy | 1 | 2 researchers | +4.00 research each, in the branch chosen for that district |

**Tiers:**
- **Tier II** costs ×2 the base cost, needs Advanced Districts, and gives +1 job and +25% output.
- **Tier III** costs ×3, needs a tech, and gives +2 jobs and +50% output.
  - Habitation tier III needs Arcology Design and gives housing ×2.
  - The other districts: see the default decision in §10.4.

**Adjacency** (always previewed as a ghost overlay before the player places):
- Research next to Energy: +10% output per adjacent Energy district, up to +30%.
- Industry next to Mining: +10% per adjacent Mining district, up to +30%.
- Agriculture next to Agriculture: +5% each, up to +20% (the field-cluster bonus).
- Industry next to Habitation: −2 stability each (pollution).
- A Habitation district next to a Park Commons or Civic Hall gains +1 housing.

Buildings take one slot each and are listed in §10.3.

**Pops (settlers), jobs and growth**
- Pops are abstract people; one pop is shown as 1,000 settlers.
- Each pop eats 1.00 food per turn and takes one job. Jobs are filled highest priority first.
- The player can reorder job priorities. The default order is food, energy, minerals, metals,
  research, clerks.
- Unemployed pops cost −3 stability each.
- Homeless pops (over housing) cost −8 stability each and grow at half speed.

**Growth:**
- Growth progress per turn is `10 + 2 × free_housing` (capped at 20), multiplied by habitability
  and by modifiers.
- A new pop arrives when progress reaches 100.
- Growth is paused when the empire's food net is below 0, or the food stockpile is 0.
- **Famine:** when food is 0 and the net is negative, the colony loses 1 pop every 3 turns and
  −15 stability. The player is warned 3 turns ahead.

**Stability** (0–100, per colony). Base 50, plus:

| Source | Modifier |
| --- | --- |
| Clerks | +1 each |
| Civic Hall | +10 |
| Park Commons | +8 |
| Ordinance: Festival | +10 |
| Origin | the origin's modifier |
| Unemployed pop | −3 each |
| Homeless pop | −8 each |
| Pollution | per the adjacency rule above |
| Events | as each event says |
| War exhaustion | −(exhaustion / 10) |

Its effects:
- ≥ 70: +10% output.
- ≤ 30: −15% output.
- ≤ 15: starts the Unrest chain.
- ≤ 5: the colony declares autonomy. It is recoverable by event, and it is always warned 5 turns
  ahead.

**Colony stages**

| Stage | Condition | Effect |
| --- | --- | --- |
| Outpost | no pops | minerals, energy or research only |
| Settlement | 1–4 pops | — |
| Colony | 5–14 pops | unlocks tier II |
| City | 15+ pops | unlocks tier III, +1 building slot |

In the scenario objectives, a "developed colony" means ≥ 5 pops and ≥ 6 districts.

**Governor** (optional, per colony):
- The player picks a focus: Balanced, Food, Industry, Research, Growth or Stability.
- The governor queues 1 build at a time, within a spending limit the player sets (default: 50% of
  minerals income).
- It always shows its next planned build and a one-line reason, for example "Farm district: food
  net will be −2 in 4 turns".
- The player can veto a planned build, which blocks it for 10 turns.

### 5.5 Research

Three branches:
- **Physics:** energy, sensors, lasers, shields, jump drive.
- **Society:** food, growth, stability, diplomacy, xenology.
- **Engineering:** minerals, metals, hulls, kinetics, armour, construction.

**Card draws:**
- Each branch offers 3 cards drawn from the techs whose prerequisites are met. The draw is seeded,
  and weighted by tier and by what the player already owns.
- The player researches one card per branch at a time. The three branches progress in parallel.
- A reroll costs 25 influence and gives a new hand.
- Story techs (marked ★) are always offered once their prerequisites are met.

**Costs:**
- Tier I 80, tier II 200, tier III 450, tier IV 1,000.
- Each is multiplied by `(1 + 0.05 × (colonies − 1))`.
- Catch-up: a tech already known by any empire you have contact with costs −15%.

The jump drive is a three-tech ★ chain: Jump Field Mathematics → Beacon Resonance → Jump Drive.

The full tech list is in §10.4. The tech-tree screen shows the whole graph; the cards are just
the active hand.

### 5.6 Ships, fleets and combat

**Civilian ships**

| Ship | Cost | Upkeep | Purpose |
| --- | --- | --- | --- |
| Survey Probe | 50 minerals | 0.50 energy | explores; can auto-explore |
| Construction Ship | 100 minerals | 1.00 energy | builds outposts, starbases and beacons |
| Colony Ship | 100 food, 150 minerals, 50 metals | 1.00 energy | founds a colony with 2 pops |

**Military hulls** (S, M, L and U are small, medium, large and utility slots)

| Hull | Structure | Speed | Slots | Cost | Upkeep | Unlock |
| --- | --- | --- | --- | --- | --- | --- |
| Corvette | 150 | 1.5 | 2 S, 1 U | 60 metals | 1.00 energy | start |
| Frigate | 350 | 1.0 | 2 S, 1 M, 2 U | 140 metals | 2.00 energy | Frigate Hulls |
| Cruiser | 800 | 0.75 | 2 M, 1 L, 3 U | 320 metals | 4.00 energy | Cruiser Hulls |

**Modules**

| Module | Slot | Type | Stats | Unlock |
| --- | --- | --- | --- | --- |
| Mass Driver | S | kinetic | 10 dmg | start |
| Railgun | M | kinetic | 24 dmg | Railguns |
| Laser | S | thermal | 9 dmg | Laser Weapons |
| Pulse Laser | M | thermal | 22 dmg | Pulse Lasers |
| Missile Rack | S | explosive | 14 dmg | Missile Systems |
| Torpedo | L | explosive | 60 dmg | Cruiser Hulls |
| Composite Armor | U | armour | +80 armour | Composite Armor |
| Heavy Armor | U | armour | +180 armour | Heavy Armor |
| Deflector | U | shield | +60 shield, regenerates 20%/round | Deflector Shields |
| Hardened Deflector | U | shield | +140 shield, regenerates 20%/round | Hardened Deflectors |
| Point Defence | U | defence | intercepts 40% of incoming explosive hits (does not stack beyond 70%) | Point Defence |
| Sensor Suite | U | utility | +10% hit chance; first strike on round 1 if the enemy lacks one | Sensor Arrays |

**Damage rules**

| Damage type | Against shields | Against armour | Against structure |
| --- | --- | --- | --- |
| Kinetic | ×1.5 | ×0.5 | ×1.0 |
| Thermal | ×0.5 | ×1.5 | ×1.0 |
| Explosive | bypasses shields | ×1.0 | ×1.0; can be intercepted by point defence |

Damage applies in layers: shields first, then armour, then structure.

**Resolution.** Combat is automatic, seeded and deterministic.
1. It runs up to 6 rounds.
2. In each round, every weapon on every ship picks a target. Targeting is weighted toward the
   ships the weapon type is best against, and ties go to the lowest structure.
3. Each weapon rolls to hit: 70% base, adjusted by sensors and evasion (corvette evasion is +15%).
4. Damage is applied through the layers.
5. After each round, a fleet checks whether to retreat according to its stance:
   - Cautious: retreats below 50% of total effective HP.
   - Balanced: retreats below 30%.
   - Aggressive: retreats below 10%.
   - Last Stand: never retreats.

A fleet that retreats moves to the nearest owned system, with −25% structure on its surviving
ships. The winner holds the system.

Admirals give +10% hit chance and one trait each: for example Shieldwright (+15% shield
regeneration) or Raider (+20% damage in round 1). There are four admiral traits.

**Before and after a battle.**
- **Battle forecast.** Before moving into a hostile system, the player sees an odds bar: likely
  win, even, or likely loss. It comes from 50 cheap simulated battles using fresh seeds on the
  `FORECAST` stream. Next to it is the single biggest factor, for example "Their deflectors blunt
  your lasers; consider mass drivers".
- **Battle replay.** A 10–20 second animated, skippable flat replay: ships as silhouettes,
  tracers coloured by damage type, shield bubbles and armour sparks. It uses the VFX kit of §15.6
  when delivered, and primitives otherwise.
- **Battle breakdown.** Winner and losses, then the three decisive factors, ranked by their
  contribution to the outcome. For example:
  - "Their shields absorbed 62% of your kinetic damage"
  - "Your point defence stopped 9 of 14 missiles"
  - "Admiral Brandt's first strike removed 2 corvettes"

  Each links to the relevant Codex entry.

**The designer.**
- The player picks a hull and fills its slots. Live stats update as they go: damage by type,
  effective HP against each damage type, cost and upkeep.
- An "auto-fit" button builds a sensible design for a chosen role and explains its picks.
- Ships are built at a colony with a Spaceport, using that colony's build queue. Build time is
  `ceil(metal_cost / 40)` turns.

**Starbases.**
- Built by a construction ship at an owned system, for 200 metals.
- Stats: structure 1,500, shields 300, 4 medium weapons.
- They extend sensor range and anchor jump range (M4).

### 5.7 Diplomacy

Contact starts when a player unit enters a system in sensor range of the other empire. First
contact always fires an event.

**Opinion** runs from −100 to +100. It is shown as a list of reasons, with numbers and remaining
duration:

| Reason | Opinion | Duration |
| --- | --- | --- |
| Trade deal | +20 | while active |
| Shared rival | +15 | — |
| Border friction | −10 per shared border system | — |
| Broke a treaty | −50 | decays 1 per turn |
| Is noisy (Vael only) | −1 per 5 Noise | — |
| Gift | +1 per 10 energy, max +25 | decays |

**Treaties** (each costs influence to propose and has a small upkeep):

| Treaty | Proposal cost | Upkeep | Effect |
| --- | --- | --- | --- |
| Non-Aggression Pact | 25 | 0.5 influence per turn | no war |
| Trade Deal | 25 | none | both sides +3 energy per turn per colony pair within 3 lanes, capped at +15; opens the market |
| Research Pact | 50 | none | both sides +10% research; needs opinion ≥ 25 |
| Open Borders | 10 | none | lets units pass through; required for most trade-route events |
| Peace | none | none | ends a war; a 20-turn truce follows |

**Acceptance preview.** Before the player proposes anything, the UI shows "They will accept /
refuse" and the acceptance score breakdown. For example: "+30 opinion, +20 they fear the Unlit,
−40 they are Cautious Elders and you are noisy". The player cannot fire off blind proposals.

**War:**
- Declaring war costs 50 influence and needs a war goal:
  - Claim a system adjacent to your territory.
  - Humiliate: they lose 50 influence and −20 opinion with others.
  - Liberate a colony.
- War exhaustion (0–100 per side) rises with losses, lost systems, and the number of turns at war.
  At 100, a status-quo peace is forced.
- Occupation: a fleet with no opposition in a colony system for 5 turns occupies it. Claims
  transfer at peace.

**The Unlit (pirates)** spawn from bases, raid undefended lanes, and demand tolls through events.
Base strength scales with the difficulty slider and with the player's total fleet power, clamped.

### 5.8 AI (utility-based and explainable)

**Scoring.**
- Each AI turn scores candidate actions, generated from the same command list the player uses:
  build, research pick, move, diplomacy, event choice.
- Each action is scored by `Σ weight_k × consideration_k(state)`. The considerations are economy
  need, expansion value, threat, opportunity, diplomatic fit and story. The weights come from the
  personality file (§13.6).
- The AI takes its best actions under its budgets, which are the same resources the player has.
- The AI does not cheat on Normal. On Hard it gets +20% output, disclosed in the difficulty
  tooltip.

**Explainability.**
- Every AI action records its top 3 considerations.
- The diplomacy screen's "Why?" panel shows the last 5 notable AI actions toward the player, with
  those reasons. For example: "Meridian claimed Tessel: expansion value high (rich asteroid
  field), threat low (your fleet is 3 lanes away)".

**Performance budget.**
- An AI turn takes under 300 ms at 16 systems, and under 1 s at 50 systems, on a 2022 mid-range
  phone.
- Use candidate pruning. Never search the whole state space.

**As built:** `sim/ai/ai_player.gd` is a stub that returns no commands. The turn processor
already calls it, in a fixed empire order, on the start-of-turn state.

### 5.9 Noise

Noise is an empire meter from 0 to 100, displayed as a waveform in the top bar and always
explained.

| Source | Noise |
| --- | --- |
| Each jump or beacon transit by a ship | +1 |
| Each active beacon | +0.25 per turn |
| Broadcast events | +5 to +15, stated on the choice |
| The Great Array (M4) | +2 per turn |
| Natural decay | −0.5 per turn |
| Quiet Drive tech | halves ship transit Noise |
| Listening Post | lets the player see other empires' Noise |

- Thresholds 25, 50 and 75 unlock main-arc events.
- Above 75, "the Attention" events begin in sandbox mode. They are always foreshadowed at least
  10 turns ahead, and never unfair.
- The Vael's opinion reacts to Noise. The Meridian Directorate does not care until the late arc.

### 5.10 Events

Events are data (§13.4). Each has:
- a trigger (conditions on state and flags, plus a weight and cooldown)
- a title
- a body with named characters
- an optional illustration (a story scene id; §8.3, §15.7)
- an optional speaking character (a portrait id with an expression) and a music cue (a character
  theme or a mood; §15.5), so story scenes play like a visual novel
- 2–4 choices

Each choice has visible costs and effects, and an optional chain continuation (the next event,
after a delay of N turns).

Rules:
- Hidden outcomes are allowed only when the choice is marked "Uncertain" and a range is shown
  ("50%: +2k settlers, 50%: −10 stability"). The rolled outcome is reported afterwards.
- Chains are 2–8 steps long. Flags persist and can be referenced by any later event.
- **Pacing:** the Event Director fires at most 1 emergent event every 4–6 turns (seeded), and
  never in the same turn as a main-arc event. It weights by what has not been seen recently.
- An event log records every event and the choice made. It can be reread.

### 5.11 Ordinances (`edict`)

The player has 2 ordinance slots; Civic Charters adds a third. Each ordinance costs influence to
activate, and energy per turn:

| Ordinance | Activation | Upkeep | Duration | Effect |
| --- | --- | --- | --- | --- |
| Festival | 30 influence | 2.00 energy/turn | 10 turns | +10 stability everywhere |
| Work Drive | 30 influence | 2.00 energy/turn | 10 turns | +10% minerals and metals, −5 stability |
| Research Grants | 40 influence | 3.00 energy/turn | — | +10% research |
| Radio Silence | 20 influence | — | — | −1 Noise per turn; no broadcasts, and trade deals give −50% |
| Frontier Charter | 40 influence | — | — | outposts cost −50% |

### 5.12 Victory, defeat and saves

**Campaign.** Each scenario has objectives (§10). It is lost only by losing the capital, or by the
scenario-specific condition. Losing offers a reload from the checkpoint 5 turns ago, or a retry.

**Sandbox.** Five victories (§11).

**Saves:**
- The game auto-saves every turn in a ring of 10, plus a separate checkpoint every 5 turns in a
  ring of 6.
- There are manual save slots, and an optional Ironman mode (single save).
- Saves are versioned JSON with a migration chain (§9.6; the serializer is built).
- A POC save is under 1 MB; a sandbox save at 50 systems is under 5 MB.

### 5.13 Difficulty

Difficulty comes from presets (Story, Normal and Hard), plus sliders the player can set:
- AI aggression, 0–2
- pirate strength, 50–150%
- event severity, 50–150%
- player output, 80–120%
- tutorial hints, on or off

Every value affected by difficulty says so in its breakdown tooltip.

---

## 6. UX: how the game explains itself

### 6.1 The breakdown tooltip system (built in M0; use it everywhere)

Any number, icon or status in the UI is wrapped in an `Explainable` component. The component takes
a `Breakdown` object from the simulation:
`{label, total, unit, resource, per_turn, lines:[{source, value, kind: base|add|mult|cap, child}], note, links}`.

**As built** (`sim/explain/breakdown.gd`, `ui/components/explainable.gd`,
`ui/components/breakdown_tooltip.gd`):
- **The lines sum exactly to the total.** The subtotal is `base + adds`; each mult line is
  `mul_bp(subtotal, bp)`; caps clamp last.
- **Opening it:**
  - PC: hover opens it after 300 ms, and a click pins it.
  - Touch: a tap opens a number, and a long-press opens anything.
  - Keyboard: `ui_accept`.
- **Nesting:** a line with a `child` opens that source's own breakdown, up to 2 levels.
  - On PC the nested panel opens beside its parent.
  - On phones it cascades over its parent, like a navigation stack.
- **Size:** panels widen with the text scale and scroll when taller than the screen.
- **Units:** the header shows the unit and "/ turn" (§5.0).

The simulation must produce a Breakdown for every derived value it computes, including:
- colony output
- upkeep
- stability
- growth
- opinion
- acceptance
- combat odds
- research cost
- Noise

This is a hard rule. The UI never recomputes game math; it only displays breakdowns the simulation
emits.

### 6.2 The "Why?" inspector

The Why? inspector is a button (or the `?` key) that opens a panel for the current selection. It
shows the causal chain for the selection's recent changes, for example "Stability fell 58 → 44
this turn: +2k settlers without work (−6), Festival expired (−10), Clerk added (+1), …".

It also works on AI actions, on events ("why did this event fire?" shows the trigger conditions
that were met), and on combat. It is backed by `WhyLog` (built).

### 6.3 Turn report

- The turn report opens at the start of each turn. It can be collapsed to a side strip.
- The top 3 items are chosen by an importance score (threats, completions, shortfalls, story).
- Below them come grouped sections: Colonies, Research, Fleets, Diplomacy, Story. Each item has a
  one-line "what and why", and a jump-to button.
- Every item comes from a `ReportItem` the simulation emits (built). It carries a category,
  importance, text key and args, a focus target, and a breakdown.
- A critical severity blocks End Turn.

### 6.4 Tutorial and advisor

- Archivist Imre Sola guides Scenario 1 step by step. Each step names a goal, highlights the
  relevant UI with a pulsing outline, explains why it matters, and completes on the player's
  action. The player never has to click "next" to read text.
- After Scenario 1, the advisor offers contextual hints the first time a mechanic appears: for
  example the first overflow warning, the first combat, or the first treaty.
- Hints can be muted individually or all at once, and reread in the Codex.
- Every hint links to its Codex entry.

### 6.5 Codex

- The Codex is generated from the data files plus authored prose (`data/codex/*.md`). It covers
  every district, building, tech, hull, module, trait, resource, mechanic, faction and character,
  and every event already seen.
- Every entry shows its live numbers from data, so the Codex can never disagree with the game.
- It can be searched and is cross-linked. It has a "Mechanics" section with the formulas of §5
  written in plain English.

### 6.6 Alerts

- Alerts are pausable and filterable, and the player chooses which ones they receive.
- Critical alerts (war declared, colony in famine, autonomy imminent, combat lost) block End Turn
  until acknowledged. Every other alert is a non-blocking toast plus a line in the report.
- An End Turn press with unassigned idle things (an idle construction ship, an empty research
  card, an unspent overflow) shows a single checklist. "End anyway" is always allowed.

### 6.7 Undo and the order queue

- Every player command within a turn is queued, and undoable until End Turn (Ctrl+Z or the undo
  button). The `CommandQueue` is built.
- Commands validate immediately. An invalid command shows the reason and is never silently
  dropped.

### 6.8 Text rules

- All player-facing text lives in `strings/en.csv`. English is the only language in v1.
- Name things the way a player would: write "Farm district", never `agriculture_district`.
- Numbers show a unit and a sign: "+4.0 kt / turn" (§5.0). Negative numbers use a true minus
  sign (−).
- The raw-id audit (§12 gates) fails the build if any rendered label matches
  `^[a-z0-9]+(_[a-z0-9]+)+$`, or contains `SYS-`, `COL-`, `null` or `{`.

### 6.9 Accessibility

- Text scales from 100 to 200%. The layout must reflow, not overlap.
- Every input can be remapped. The game can be paused at any time, and nothing runs in real time
  anyway.
- Colour is never the only signal: every coloured state also has an icon or a shape.
- The palette is checked for colour-blind safety by `tools/palette_report.gd` and by deuteranopia
  copies in the screenshot tour. The negative-number colour question is still open (§14).
- A Reduce Motion setting turns off pulses and replays, and cuts to the breakdown.
- A high-contrast theme variant is available (built).

---

## 7. Screens (each is specified for PC and mobile)

**Layout base (as built in `app/layout.gd`):**
- PC reference: 1920×1080. UI scale is `max(1, window_height / 1080)` times the user multiplier.
- Mobile reference: 2400×1080, landscape, with safe areas respected. On touch devices, one logical
  pixel is one dp.
- Phones and tablets are detected on the web from the user agent or a coarse main pointer
  (DESIGN_LOG 36).
- The **compact** layout class applies below 1280×700 logical px. Every screen needs a compact
  layout.
- Minimum touch target: 48 dp. Minimum body text: 16 px at 1080p, 14 sp on mobile.

| # | Screen | PC layout | Mobile layout | Key content and interactions |
| --- | --- | --- | --- | --- |
| 1 | Title / Main menu | centred menu over an animated starfield and a slow lane pulse | same, bigger buttons | Continue, Campaign, Sandbox (locked until M4), Load, Settings, Codex, Credits |
| 2 | Campaign select | three scenario cards in a row | horizontally swipeable cards | title, synopsis, completion state, legacy picked; Play, Replay |
| 3 | Galaxy view | full-screen map; top bar; right sidebar (selection); collapsible left outliner; End Turn at bottom right | full-screen map; top bar compacted to 4 resources plus a "More" drawer; bottom sheet for selection; outliner as a left drawer; floating End Turn button | pan and zoom (drag or pinch); tap a star to select it; double-tap or the Enter button to dive; lanes styled by type; fog states; fleets as chevrons with counts; route preview with ETA and Noise |
| 4 | System view | orbit diagram of planets on flat rings, the star at the centre, a sidebar | same; bottom sheet | planets (tap to select, double-tap to open the planner), belts, starbase, fleets present; actions: colonise, outpost, survey, build starbase or beacon |
| 5 | Colony planner | large hex disc centred; left panel with colony stats and the stability breakdown; right panel with the build palette and queue | hex disc full-width; palette as a bottom tray; stats in a top drawer | drag or tap to place, with an adjacency ghost preview and output deltas; upgrade; demolish (with confirmation); job priority; governor panel; Why? on every number |
| 6 | Research | three branch columns, each with 3 cards and progress; a "View tree" button | branch tabs with swipeable cards | cards show cost, ETA, effects and what they unlock; a ★ story marker; reroll (with its influence cost shown); the tree view is a pannable graph |
| 7 | Fleet manager & designer | fleet list, then fleet detail (ships, admiral, stance), then the designer with its slot grid and live stats | stacked screens with back navigation | build queue per spaceport; auto-fit; compare designs; stats per damage type |
| 8 | Combat replay & breakdown | full-screen overlay: replay above, breakdown below | same, stacked inside landscape | skip, replay; three decisive factors; losses; links to the Codex |
| 9 | Diplomacy | empire list on the left; relation detail on the right (opinion reasons, treaties, war status, Why? log) | list, then detail | propose a treaty with an acceptance preview; declare war with a war-goal picker; gift |
| 10 | Event modal | a centred card: the painted scene at the top (slow pan), the speaking character's portrait beside the body, then 2–4 choice buttons, each with cost chips and effect lines; the step's music cue plays | full-screen card | choices disabled if unaffordable, with the reason shown; "Uncertain" choices show their ranges |
| 11 | Turn report | right-side panel, collapsible | full-screen sheet; swipe down to collapse | top 3, then grouped items with jump-to buttons |
| 12 | Codex | search at the top; categories on the left; entry on the right | search, then list, then entry | live numbers; cross-links |
| 13 | Settings | tabs: Game, Display, Audio, Controls, Accessibility | same, scrolling | text scale, UI scale, reduce motion, high contrast, key remapping, hint toggles, audio volumes |
| 14 | Save / Load | list with screenshot thumbnails, turn and date | same | auto-saves, checkpoints, manual saves; delete needs confirmation |
| 15 | Scenario briefing & debrief | full-screen card: objectives, optional objectives, advisor portrait | same | the debrief picks 1 of 3 legacies to carry forward |

**The top bar** (built as `ui/components/top_bar.gd`) shows, from left to right:
1. the six resources, each with its stock, net per turn, and a breakdown on tap
2. the Noise waveform
3. the turn and date (for example "Month 4, Year 101 S.")
4. the menu

On mobile it shows food, energy, minerals and metals in a swipeable strip, plus a "More" drawer
listing every resource with its unit, the Noise meter and the date.

---

## 8. Art direction: a flat interface over a painted world

### 8.1 Principles

- **Two layers, one palette** (Owner decision after M0; DESIGN_LOG 45):
  - **The interface** (panels, chips, icons, the map's symbols) is flat and geometric, readable at
    16–24 px. It stays generated by code and authored as SVG in the repo.
  - **The world** (story scenes, portraits, ships, title and store art) is **painted diorama**:
    stylized, chunky 3D forms like a hand-built miniature, rendered with soft painterly brushwork,
    glowing light and luminous skies, in the spirit of hopeful 1960s space-age illustration. The
    full direction is in §15.3.
- It is not pixel art and not photoreal. Its default mood is hopeful; darker routes use the dark
  variant of §15.3.
- **Baseline:** every world asset keeps a code-drawn fallback, so the game is always complete.
  Outsourced art replaces the fallback through the intake contract of §15.
- **Mood references for human artists:** the games *Before We Leave*, *Dorfromantik* and *Outer
  Wilds*, and NASA's 1960s–70s space art. Never name a living artist in a generator prompt.
- Readability beats decoration: every ship and icon must be identifiable at small sizes.

### 8.2 Palette (design tokens, as built in `ui/theme/tokens.gd`)

| Token | Hex | Use |
| --- | --- | --- |
| `bg.deep` | #0B1622 | space background |
| `bg.panel` | #13263A | panels |
| `bg.panel.alt` | #1B3350 | raised panels, hovers |
| `line.subtle` | #2A4A6B | dividers, deep lanes |
| `text.primary` | #EAF2F8 | body text |
| `text.secondary` | #9FB3C8 | labels |
| `accent.teal` | #2EC4B6 | primary actions, the player's empire, Habitation districts |
| `hearth.gold` | #FFD37A | highlights, positive numbers, beacon lanes |
| `alert.ember` | #FF6B4A | danger, negative numbers (pending §14), the Unlit |
| `ally.blue` | #4EA8DE | the Meridian Directorate |
| `other.magenta` | #C04CFD | the Vael |
| `ok.green` | #6BD68A | success, food |
| `energy.yellow` | #F7C948 | energy |
| `mineral.slate` | #A7B4C2 | minerals |
| `alloy.copper` | #E0925A | metals |
| `sci.cyan` | #56CFE1 | research |
| `influence.violet` | #9D8DF1 | influence |

**Star colours** by spectral class:

| Class | Hex |
| --- | --- |
| M | #FF8B5E |
| K | #FFB870 |
| G | #FFE08A |
| F | #FFF3D1 |
| A | #CFE3FF |
| White dwarf | #EEF5FF |

- Text contrast is at least WCAG AA (4.5:1 for body text). Verified for every text token by
  `tools/palette_report.gd`.
- The high-contrast variant swaps in black panels and white text, with 2 px outlines.

### 8.3 Shapes and components

- Corner radii are 4 px (chips) and 8 px (panels). Icon strokes are 2 px at 24 px.
- **Icons (built):** 87 icons on a 24×24 grid in `assets/icons/<id>.svg` and `<id>_outline.svg`,
  rasterised at run time at the exact pixel size. `tools/icon_sheet.gd` renders the contact sheet.
  Their ids are listed in §13.8.
- **Stars (built):** a glowing disc coloured by spectral class and sized by magnitude; binaries get
  a companion (`ui/map/star_disc.gd`).
- **Planets (built):** a flat disc with seeded bands, blobs, craters or cracks by type, a soft
  terminator crescent and a thin rim light; rings on some gas giants; belts as outlined rocks
  (`ui/map/planet_disc.gd`). M1 upgrades them to match the painted world: lit spheres with a
  soft terminator, an atmosphere glow and painted-looking surfaces, still generated from the seed.
- **Ships (to build, M2):** painted top-down sprites with chunky 3D forms, 3 hull shapes × 4 faction styles, tinted by owner,
  plus 3 civilian ships and the starbase. Each faction style has a signature feature:
  - human: a spine and a ring
  - Meridian: symmetrical wings
  - Vael: organic lobes
  - Unlit: asymmetric salvage

  Code-drawn polygons are the fallback; the painted sprites of §15.8 replace them.
- **Lanes (to build, M2):** deep lanes are a 1 px dotted `line.subtle`. Beacon lanes are a 2 px
  solid `hearth.gold` with a slow dash animation.
- **Hex planner (cells built, planner M1):** the hex cells are clipped to the planet disc.
  Districts are flat hexes with a centred icon and tier pips. Adjacency ghosts are dashed outlines
  with +/− chips.
- **Story scenes (vignettes, M1):** painted-diorama scenes (§15.7) behind the event text, with a
  slow pan and engine-drawn light flicker; optional layers add parallax. The fallback is assembled
  from primitives defined in `data/vignettes.json`, as in the showcase's Founders' Vote card.
- **Portraits (M1):** painted chest-up busts with a neutral expression and optional warm, worried
  and stern ones (§15.7). Speaker-of-Seven is an abstract light-spiral. The fallback is a flat
  geometric bust generated from parameters.

### 8.4 Motion

- Tweens last 150–250 ms with ease-out: panels sliding, numbers counting, and the map zooming
  between levels.
- Pulses mark alerts and tutorial highlights. Beacon lanes animate their dashes.
- Every animation respects Reduce Motion.

### 8.5 Type

IBM Plex Sans for UI text (Regular, Medium, SemiBold), and IBM Plex Mono for numbers in tables
and breakdowns.

| Use | PC px at 1080p | Compact px |
| --- | --- | --- |
| Display | 32 | 26 |
| Heading 1 | 22 | 20 |
| Heading 2 | 18 | 16 |
| Body | 16 | 14 |
| Caption | 13 | 12 |

Line height is 1.35. All sizes multiply by the text scale.

### 8.6 Audio

- **Soundtrack:** melodic, in the manner of a story-rich visual novel (Owner decision after M0;
  DESIGN_LOG 46). It has:
  - a main theme
  - era tracks for the map and colony screens
  - a theme for each named character
  - mood pieces (warm, sorrow, mystery, tension, hope, light)
  - endings

  Event steps name a character theme or a mood, which crossfades in (§5.10, §15.5). Music arrives
  from M1, not M4.
- **Sounds:** musical, soft interface sounds, tuned to D major pentatonic so they sit inside the
  score, plus game sounds (§15.4). Code-synthesised blips are the fallback.
- **Settings:** volume sliders for UI, effects and music, plus mute. Every sound respects mute.

---

## 9. Technical architecture (as built after M0)

### 9.1 Engine settings

- Godot **4.7.2-stable** (pinned in `.godot-version`), GDScript with static typing everywhere.
  Untyped declarations are errors (`untyped_declaration=2`), including `for` loop variables.
- **Renderer:** Compatibility (OpenGL 3 / WebGL 2). No 2D MSAA (unsupported); edges use
  anti-aliased lines.
- **Window:** 1920×1080, stretch mode `canvas_items`, aspect `expand`, sensor-landscape
  orientation on phones.
- **Export presets:** Web (single-threaded, so no special server headers), Windows and Linux.
  Android is added at M3.

### 9.2 Repository layout

```
/
├─ project.godot  .godot-version  export_presets.cfg
├─ README.md  CHANGELOG.md  CREDITS.md  LICENSE
├─ docs/  DESIGN_LOG.md  BUILD_PROMPT.md  milestones/  assets/ (outsourcing briefs, §15)
├─ sim/                      # pure simulation: RefCounted, no Node/SceneTree/Input/ui
│  ├─ core/                  # GameState, Empire, StarSystem, Lane, Planet, Colony, Fleet, Ship, Design,
│  │                         # Fx (fixed point), Calendar, DictIO, Invariants            [built]
│  ├─ rules/                 # economy, growth, stability, research, travel, combat, diplomacy,
│  │                         # noise, events, ordinances (edicts.gd), victory           [M1–M3]
│  ├─ ai/                    # ai_player.gd (stub), considerations, personalities       [M3]
│  ├─ commands/              # Command, Result, registry, queue with undo; 2 commands   [built]
│  ├─ turn/                  # TurnProcessor (14 phases), TurnResult, ReportBuilder     [built]
│  ├─ explain/               # Breakdown, ReportItem, WhyLog                            [built]
│  ├─ gen/                   # scenario_loader.gd [built]; galaxy_gen.gd, planet_gen.gd [M4]
│  ├─ data/                  # ContentDb, DataSchema, EffectKeys, DataValidator, StringTable [built]
│  ├─ rng.gd  rng_stream.gd  # deterministic streams                                    [built]
│  └─ save/                  # canonical JSON, serializer, migrations/                  [built]
├─ data/                     # all content, JSON (§13); events/ scenarios/ codex/
├─ strings/en.csv            # key,en — loaded at run time into a Translation
├─ ui/
│  ├─ theme/                 # tokens.gd, theme_builder.gd (theme built at run time)    [built]
│  ├─ components/            # Explainable, BreakdownTooltip, ResourceChip, Card, Modal, Toast, Drawer,
│  │                         # BottomSheet, SfTabs, HexCell, SfButton, SfIcon, Meter, NoiseWave,
│  │                         # TopBar, Fmt, IconCache, OverlayLayer                     [built]
│  ├─ screens/               # one folder per screen of §7; showcase/ (M0 main scene)
│  └─ map/                   # star_disc, planet_disc [built]; galaxy_map, system_map, planner [M1–M2]
├─ assets/  icons/ (87×2 SVG)  fonts/ (IBM Plex + OFL)  delivered/<kind>/ (§15 batches)
├─ app/                      # autoloads: Settings, Strings, Layout, Overlay, Game, SaveService
├─ tests/  run_tests.gd  t.gd  unit/  integration/  golden/  fixtures/
├─ tools/                    # validate_data, data_checks, bot_run (+bot/), telemetry_report,
│                            # screenshot_tour, id_audit, icon_sheet, palette_report, colour_vision,
│                            # regen_golden, web_smoke.mjs; import_assets.py (§15.2)
└─ .github/  workflows/ci.yml  actions/setup-godot/
```

### 9.3 The simulation boundary

`sim/` never references `Node`, `SceneTree`, `Input`, engine randomness, or anything under `ui/`.
`tests/unit/test_boundary.gd` enforces this with a static scan.

**State:**
- `GameState` is a tree of typed `RefCounted` objects, each with `to_dict()` and a static
  `from_dict()`. It also has `clone()`, `state_hash()` (SHA-256 of canonical JSON), and
  `next_id(prefix)`.
- Ids are stable, zero-padded strings (`sys_ember`, `col_0001`). They are for code only and never
  displayed.
- Simulation code iterates collections in sorted-id order.

**Commands:**
- The UI sends `Command` objects through `Game.submit(cmd)`.
- Each command implements `validate(state) -> Result` (ok, or an error with a `reason_key` and
  args) and `apply(state)`. The within-turn `CommandQueue` keeps a preview state and supports undo.
- End of turn runs `TurnProcessor.run(state, queued_commands) -> TurnResult`, which contains
  `{state, report_items, events_pending, battles, why_log, state_hash}`. Rejected orders become
  report items with their reason.

Presentation reads the state plus the TurnResult. It never mutates state and never recomputes
rules. It displays Breakdowns and ReportItems.

**Determinism:** the same save plus the same command list always produces the same resulting state
hash. The golden tests check this.

### 9.4 Turn phase order (a contract; changing it needs a DESIGN_LOG entry)

1. Apply the queued player commands (already validated), then AI commands, in a fixed empire order.
2. Construction progress (districts, buildings, ships, starbases, beacons).
3. Production: jobs output → upkeep → market trades → caps and overflow.
4. Food, growth and famine.
5. Research progress; completions go into the report; new cards are drawn.
6. Movement: every fleet advances; arrivals.
7. Combat in every contested system (seeded per system).
8. Occupation, outposts, colonisation completions.
9. Stability recalculation and ordinance ticks.
10. Diplomacy ticks: opinion decay, treaty upkeep, war exhaustion, AI diplomatic decisions.
11. Noise update.
12. Events: story triggers first, then the director for emergent events. Pending choices go to
    the player next turn.
13. Victory and defeat checks; scenario objectives.
14. Build the report and the why-log; compute the state hash; auto-save.

All 14 phases exist in `sim/turn/turn_processor.gd` with empty bodies. M1–M3 fill them.

### 9.5 Deterministic RNG (built)

- Do not use Godot's global `randi()`, and do not hash strings with the engine's `hash()`.
- The generator is xoshiro128** with 32-bit arithmetic on 64-bit ints, masking with `& 0xFFFFFFFF`.
  `mul32` splits its second argument into 16-bit halves.
- Streams are stateless. `Rng.stream(seed, turn, stream_id, salt)` folds the four inputs with
  `fmix32`/`mul32`, then splitmix32 expands them into the four state words.
- String salts use FNV-1a (`Rng.salt_of`).
- Stream ids: `GEN, COMBAT, EVENTS, AI, RESEARCH, GROWTH, FORECAST`. `FORECAST` never affects state.
- `RngStream` API: `next_u32()`, `range(lo, hi)` (inclusive, unbiased), `chance_bp(bp)`,
  `weighted(weights)` (−1 if every weight is 0), `shuffle()`.
- Test vectors from an independent reference implementation live in
  `tests/golden/rng_vectors.json`.

### 9.6 Saves (built)

- Envelope:
  `{format:"starfire-hearth-save", version, game_version, seed, turn, scenario_id, state, rng_meta, checksum}`.
- `version` is the state schema version (`GameState.SCHEMA_VERSION`, now 1).
- The checksum is SHA-256 of the canonical JSON of `state` (sorted keys; integers only; a float is
  an error).
- **Migrations:** `sim/save/migrations/v<N>_to_v<N+1>.gd`, each with a static
  `migrate(state: Dictionary)`. Every schema change adds one, plus a fixture in
  `tests/fixtures/saves/`.
- Saves live in `user://saves/`, with a small PNG thumbnail alongside (M1).
- Save, load and save again produces byte-identical canonical JSON.

### 9.7 Strings (built)

- `strings/en.csv` (key,en) is loaded at run time into a `Translation`. Use
  `Strings.fmt(key, args)`: arguments ending in `_key` are resolved as nested keys.
- Keys are namespaced: `ui.*`, `res.*`, `district.*`, `event.<chain>.<step>.*`, `icon.<id>` and
  so on.
- The validator checks that every data `*_key` exists, that no key is orphaned, and that every icon
  has an `icon.<id>` name.
- Code that builds a key dynamically must be listed in `tools/data_checks.gd`, so the orphan check
  still sees it.

### 9.8 Tests (headless; built)

Run: `godot --headless --path . -s tests/run_tests.gd` (`-- --filter <text>` to narrow). The
runner discovers `test_*.gd`. An engine `Logger` turns script errors into test failures.

**As of M0:** 85 tests and 390 checks, in these suites:
- unit
- commands
- golden: RNG vectors, and per-turn hashes with a save and load every turn
- saves
- data (including bad-data fixtures that prove every check fires)
- boundary
- integration: 50 skeleton turns, and a headless audit of the showcase

**Required from M1 on:**
- **Unit:** every rules module, with formulas checked against §5 and breakdowns that sum to their
  totals.
- **Commands:** the validation of every command, with the error reasons checked.
- **Integration:** 50 turns of each scenario with the balanced bot, with no errors and no invariant
  violations. The invariants are:
  - no negative stocks except via the famine rules
  - pops ≤ housing + homeless tracking
  - every state value is an integer
  - every id reference resolves
- **Golden:** a fixed seed and command script (`tests/golden/golden_script.gd`), with per-turn
  hashes. Re-baselining is allowed only through `tools/regen_golden.gd --reason "..."`, and each
  re-baseline is logged in CHANGELOG.md.
- **Data:** every district and building is reachable in some scenario. Today this check reports
  SKIP; it becomes real in M1.

### 9.9 Screenshots and visual verification (built)

- `tools/screenshot_tour.gd` renders every state in its list at PC 1920×1080 and phone 2400×1080
  (440 dpi, touch, simulated cut-out), each at 100% and 200% text, plus deuteranopia copies. From
  M1 it loads fixture saves and visits every screen of §7 as it is built.
- `tools/id_audit.gd` fails on:
  - raw-id text
  - overlapping labels
  - clipped labels (along a scroll axis, clipping is scrolling, not a defect)
  - words broken mid-word
  - tap targets under 48 dp
  - numeric labels outside an `Explainable` (exemptions need the `audit_numeric_ok` meta with a
    reason)
- `tools/web_smoke.mjs` opens the exported web build in headless Chromium as a PC, an Android
  phone and an iPad. It checks boot, console errors and the layout class.
- Look at the screenshots yourself after every UI change, and note what you checked in the report.

### 9.10 Continuous integration (built: `.github/workflows/ci.yml`)

**Triggers:** pushes to `main`, pull requests, and manual dispatch. A PR's superseded runs are
cancelled; runs on `main` always finish.

**Jobs:**

| Job | What it runs |
| --- | --- |
| checks | import; validate_data; tests; the bot smoke test (2 policies × 3 seeds × 60 turns, each replayed for determinism); telemetry gates; palette report; telemetry artifact |
| screens | xvfb plus software OpenGL; screenshot tour and id audit; icon sheet; screens artifact |
| export | Web, Windows and Linux; web size check (gzip download under 150 MB, DESIGN_LOG 37 and 49); web smoke test; the web-build artifact; desktop builds on `main` and manual runs; the Pages artifact on `main` |
| deploy | GitHub Pages (Source: GitHub Actions), on pushes to `main` |

**To add:** the Android export at M3 (signing keys from the Owner as repository secrets). Asset
intake runs on the builder's machine (§15.2); CI checks its result in the test job
(`tests/unit/test_assets.gd`: every delivered id imports and loads). Bump
`actions/checkout`, `cache` and `upload-artifact` to their Node 24 majors when convenient.

### 9.11 Performance budgets (checked in CI where possible; reported otherwise)

| Metric | Budget | Status after M0 |
| --- | --- | --- |
| End turn, POC scenario (16 systems, 2 AIs) | < 300 ms desktop; < 1 s on a mid-range phone | skeleton only: p95 about 1.5–2 ms |
| End turn, sandbox (50 systems, 4 AIs) | < 3 s on a mid-range phone | M4 |
| Map pan and zoom | 60 fps at 50 systems on desktop Compatibility | M2 |
| Memory | < 400 MB | showcase peak 294 MiB with software GL |
| Web build size | < 150 MB, as the compressed download (Owner, after M0; DESIGN_LOG 49) | 48.2 MB with the first delivery (was 11.0 MB) |
| Audio added by §15 | music ≤ 70 MB in total as Ogg (about 112 kbps); effects ≤ 5 MB | music 27.8 MB (28 tracks); effects 3.6 MB |
| Painted art added by §15 | ≤ 40 MB, shipped as lossy WebP at display size | 2.9 MB of sources (batch 1) |

---

### 9.12 The M1 simulation (as built)

- **Content access:** rules read `Content.db()` (`sim/data/content.gd`), loaded once; tests can swap
  it with `Content.use()` (DESIGN_LOG 51).
- **Breakdowns** gained a `flat` line kind, applied after the percentage lines: upkeep,
  consumption and inputs are never scaled by bonuses (DESIGN_LOG 67).
- **Turn phases** filled: 1 commands; 2 governors, then construction; 3 production (the
  `EmpireReport` is kept in `TurnResult.reports`); 4 growth and famine; 5 research and decoding;
  8 civilian ship tasks; 9 stability, autonomy, ordinance and modifier ticks; 12 events; 13
  objectives, victory and loss; 14 report. Phases 6, 7, 10 and 11 wait for M2 and M3.
- **Commands** (22): rename colony, set job priority, place district, upgrade district, demolish,
  build building, build ship, cancel build, move build up, rush build, pick research, reroll
  research, activate ordinance, cancel ordinance, set governor, veto plan, survey, build outpost,
  colonise, choose event, acknowledge (tutorial), trade.
- **Economy** (`Economy.colony`, `Economy.empire`): derived, never mutating; the UI, the bots and
  the production phase all read the same reports and breakdowns.
- **Events:** `Events.check` evaluates a closed set of trigger conditions and returns the colony
  and readable reasons (written to the Why? log); `Effects.apply` turns lasting effects into
  `Modifier`s named after the event, applies one-off effects, and schedules gradual ones.
- **Advisor** (`sim/ai/advisor.gd`): scores every legal build for a colony from the empire's needs
  and a focus, with a reason key; the governor and the bots share it, and M3's AI will too.

## 10. Content scope: the 3-scenario mini-campaign (the POC)

### 10.1 Campaign structure

- Scenarios run in order, and each one unlocks the next. Every scenario is a handcrafted map with
  an authored start state.
- **Legacies** connect the scenarios. State does not carry over: the next scenario starts from an
  authored state that assumes success. At each debrief the player picks 1 of 3 legacies, a small
  perk that carries forward, for example "Seasoned Farmers: +10% food".
- The player is always the Generation Ark origin in the campaign.
- Expected length: each scenario is 60–110 turns, about 1.5–3 hours for a first-time player.

### 10.2 The scenarios

#### Scenario 1: First Light

**Teaches:** colonies, economy, research, stability, governors, ordinances.

**Map:** one system, Ember, a K-type star. The galaxy view shows Ember plus 6 unknown neighbours
under fog as a teaser (Halden, Vesper, Shroud, Tessel, Scour, Corrie; stubbed in M0). Travel
beyond Ember is locked, and the lock is explained in the story: "our slowboats need refitting".

**Planets:**

| Planet | Type and size | Slots | Traits | Role |
| --- | --- | --- | --- | --- |
| Aster | continental, medium | 20 (2 blocked) | Fertile Soil | capital |
| Brume | ocean, small | 16 | Geothermal | colony target |
| Cinder | barren, small | 16 (8 as a dome world) | Rich Veins | dome world once Habitat Domes is researched (small, not tiny: DESIGN_LOG 66) |
| Dross | gas giant | — | — | energy or research outpost slot |
| The Tithe Belt | asteroid belt | — | — | minerals outpost |

**Start state** (the stub already in `data/scenarios/s1_first_light.json`):
- **Colony:** Aster has 10 pops (10k settlers), with 2 Habitation, 2 Agriculture, 1 Energy and
  1 Mining district, plus the Ark Hull building (housing 4, +3.00 of each basic resource,
  +5 stability).
- **Stock:** 150 food, 120 energy, 250 minerals, 0 metals, 60 influence.
- **Ships:** 1 Construction Ship and 1 Survey Probe.
- **Research:** the three branch hands are pre-seeded so that the Hydroponics, Automated Mining and
  Fusion Efficiency cards appear.

**Objectives.**

Required:
- Develop 3 colonies in Ember (≥ 5 pops and ≥ 6 districts each): Aster plus 2 of Brume, Cinder or
  a second dome.
- Build 1 outpost (Dross or the Tithe Belt).
- Keep every colony at stability ≥ 40 for 10 consecutive turns.
- Complete the main-arc chain step The Sealed Order (decode 1/3).

Optional:
- reach 40 total pops (40k settlers)
- research 8 techs
- never let food run out

**Tutorial beats** (advisor-guided; turns are approximate):

| Turn | Beat |
| --- | --- |
| T1 | The turn report, the top bar, and the breakdown tooltip on food |
| T2 | Open the Aster planner and place a Farm district (the adjacency preview is explained) |
| T3 | Pick research cards |
| T5 | Stability explained after a scripted strike (the Labor Strike chain) |
| T8 | Survey Brume |
| T12 | Build the Colony Ship |
| T15 | Found Brume |
| T20 | Governors |
| T25 | Ordinances |
| T30 | Overflow warning and storehouses |
| T35 | Outposts |
| T40 | The Sealed Order begins |

**Scripted chains:** The Founders' Vote (T10), Cold Sleepers (T18), Labor Strike (T5), The Sealed
Order steps 1–2.

**Loss condition:** Aster falls to 0 pops, or goes into autonomy. Losing offers the checkpoint
reload.

**Expected duration:** 70 turns.

#### Scenario 2: The Crossing

**Teaches:** exploration, fog, travel, anomalies, pirates, fleets, the designer, combat, Noise.

**Map:** 9 systems, with deep lanes of 2–5 ly. The start state is Ember developed, plus 1 fleet
(3 corvettes and 1 frigate prototype), with the Frigate Hulls tech granted.

**Key systems:**
- **Halden's Gate:** a dormant beacon, 3 lanes away.
- **Scour:** the Unlit base.
- **Vesper:** a habitable ocean world, the second-colony target.
- **The Shroud:** a nebula holding a derelict.
- **Tessel:** a rich asteroid field.

**Objectives.**

Required:
- Survey 6 systems.
- Found a colony outside Ember.
- Restore the beacon at Halden's Gate. This needs Beacon Resonance (★), a Construction Ship on
  site, 300 metals and 3 turns.
- Resolve the Unlit, by any of three routes:
  - destroy the Scour base (structure 2,000)
  - pay the toll chain to its end
  - hire them through Mother Rook's Offer

Optional:
- win a battle without losses
- keep Noise under 20
- analyse 3 anomalies

**Beats:**

| Turn | Beat |
| --- | --- |
| T1 | Fleet basics and stances |
| T3 | Auto-explore |
| T6 | First anomaly |
| T10 | Designer tutorial (the auto-fit explanation) |
| T15 | Unlit Toll, step 1 |
| T20 | First battle and replay (scripted: favourable but instructive) |
| T30 | Jump Field Mathematics becomes available |
| T45 | Beacon restoration and Noise introduced (the first beacon transit adds Noise and shows the meter) |
| T50 | The Dark Beacon: the logs reveal Sol shut the network down deliberately |

**Loss condition:** losing Ember's capital.

**Expected duration:** 90 turns.

#### Scenario 3: Neighbours

**Teaches:** contact, diplomacy, treaties, war and peace, AI, trade, story choice.

**Map:** 16 systems.
- The player starts with 3 colonies (in Ember and Vesper), and the Halden beacon active.
- **The Meridian Directorate:** 4 colonies to the east, with 2 active beacons of its own.
- **The Vael:** 3 systems beyond a nebula belt to the north. First contact needs a probe through
  the Shroud.
- **The Unlit:** remnants on the edges, if they were not resolved in Scenario 2.

**Objectives.**

Required:
- Make contact with both powers.
- Achieve either a peace (a Non-Aggression Pact or Trade Deal) with Meridian that holds for
  20 turns, or win a limited war with a Claim war goal on 2 systems.
- Complete First Words, the Vael linguistics chain.
- Complete What the Vael Heard and make the path choice: lean Quiet, lean Warn, or lean Answer. It
  is the cliffhanger into sandbox mode.

Optional:
- a Research Pact with the Vael
- expose Meridian's suppressed message (the Meridian's Claim chain, branching)
- Noise under 40

**AI behaviour:**
- Meridian expands toward contested Tessel and trades readily. At T40 it demands the player's
  beacon access through an event, and goes to war if the player refuses and relations are
  below 0.
- The Vael stay passive, but their opinion swings strongly with the player's Noise.

**Loss condition:** losing 2 of 3 colonies.

**Expected duration:** 100 turns.

### 10.3 Buildings (15 in the POC)

| Building | Cost (minerals) | Upkeep (energy) | Effect | Unlock |
| --- | --- | --- | --- | --- |
| Ark Hull | — | — | unique capital building: housing 4, +3 food/energy/minerals, +5 stability | origin |
| Storehouse | 100 | 1 | +250 to all caps (+125 metals) | start |
| Hydroponics Bay | 120 | 2 | +6 food; works on any planet type | Hydroponics |
| Fusion Plant | 150 | — | +10 energy, but −3 stability to adjacent Habitation | Plasma Containment |
| Foundry | 150 | 2 | +25% metals on this colony | Foundry Automation |
| Research Institute | 180 | 3 | +20% research on this colony | Research Network (default decision below) |
| Civic Hall | 120 | 2 | +10 stability, +1 influence per turn; one per colony | Civic Charters |
| Park Commons | 80 | 1 | +8 stability; adjacent Habitation +1 housing | start |
| Clinic | 100 | 1 | +25% growth | Frontier Medicine |
| Spaceport | 150 | 2 | builds ships; needed for colony ships from this colony | start (Aster has one) |
| Planetary Shield | 200 | 3 | orbital bombardment −75%, +5 stability during war | Deflector Shields |
| Market Exchange | 150 | 1 | opens the market; −10% spread | Colonial Administration |
| Archive of Sol | — | 2 | unique; decodes the Sealed Order (story progress per turn = research / 20) | story event |
| Listening Post | 120 | 2 | +2 sensor range; shows other empires' Noise; early warning of Attention events | Sensor Arrays |
| Habitat Dome | 150 | 2 | +4 housing on a dome world; required to settle one | Habitat Domes |

**Default decision for M1 (log it in DESIGN_LOG; the Owner may overrule it):** add **Research
Network** as a tier II Society tech (+5% research; unlocks the Research Institute). This brings
the tech count to 37.

### 10.4 Techs (36 plus Research Network; ★ = story; the tier is in brackets)

**Physics:**
- Fusion Efficiency [I]: +10% energy.
- Sensor Arrays [I]: +1 sensor range; unlocks the Listening Post and the Sensor Suite.
- Laser Weapons [I]: unlocks the Laser.
- Deflector Shields [I]: unlocks the Deflector and the Planetary Shield.
- Plasma Containment [II]: +10% energy; unlocks the Fusion Plant.
- ★ Wake Theory [II]: reveals the Noise readout for others; +1 decode of the Sealed Order.
- Pulse Lasers [II]: unlocks the Pulse Laser.
- Hardened Deflectors [II]: unlocks the Hardened Deflector.
- ★ Jump Field Mathematics [III]: needs Wake Theory; +1 decode.
- ★ Beacon Resonance [III]: lets the player restore or build beacons.
- ★ Jump Drive [IV]: direct jumps within 4 ly of a beacon or starbase (sandbox).
- Quiet Drive [IV]: halves ship transit Noise.

**Society:**
- Hydroponics [I]: unlocks the Hydroponics Bay; +5% food.
- Frontier Medicine [I]: +10% growth; unlocks the Clinic.
- Civic Charters [I]: +1 ordinance slot; unlocks the Civic Hall.
- Colonial Administration [I]: outposts −25 influence; unlocks the Market Exchange.
- Habitat Domes [II]: lets the player settle dome worlds; unlocks the Habitat Dome.
- Genetic Crop Tailoring [II]: +15% food; Agriculture works on Arid worlds at full output.
- Cultural Archive [II]: +5 stability everywhere.
- Research Network [II]: +5% research; unlocks the Research Institute (default decision, §10.3).
- ★ Xenolinguistics [II]: needed for First Words; +15 Vael opinion.
- Diplomatic Corps [III]: +1 influence per turn; treaty proposal costs −50%.
- Arcology Design [III]: Habitation tier III.
- Federation Theory [III]: federations (sandbox).
- Hearthlight Theory [IV]: the Wonder project (sandbox).

**Engineering:**
- Automated Mining [I]: +10% minerals.
- Orbital Construction [I]: starbases; outposts build 50% faster.
- Mass Driver Refinement [I]: +15% kinetic damage (the Mass Driver is available from the start).
- Composite Armor [I]: unlocks Composite Armor.
- Foundry Automation [II]: +10% metals; unlocks the Foundry.
- Frigate Hulls [II]: unlocks the frigate.
- Missile Systems [II]: unlocks the Missile Rack.
- Point Defence [II]: unlocks Point Defence.
- Advanced Districts [II]: district tier II.
- Cruiser Hulls [III]: unlocks the cruiser and the Torpedo.
- Heavy Armor [III]: unlocks Heavy Armor.
- Railguns [III]: unlocks the Railgun.

**Tier III districts, default decision for M1 (log it; the Owner may overrule it):**
- Habitation tier III needs Arcology Design.
- The other five districts get tier III from an "Industrial Megaplex" upgrade, folded into
  Foundry Automation as an extra effect.

Each tech's name, description and effects are data. Effects use the closed set of effect keys in
§13.3; content never contains expressions.

### 10.5 Planet traits (8; data built)

| Trait | Effect |
| --- | --- |
| Fertile Soil | +20% Agriculture |
| Rich Veins | +20% Mining |
| Geothermal | +20% Energy |
| Tidally Locked | −2 slots, +10% Energy, −5 stability |
| Toxic Atmosphere | domes only; +10% Industry |
| Low Gravity | +10% metals; ships built here −10% cost |
| Ancient Ruins | the Ancient Ruins Survey chain; 1 blocked slot, cleared by the chain |
| Radiation Belt | +15% research, −5 stability |

### 10.6 Event chains (25 in the POC; each fully written, 2–8 steps)

Each chain lists its vignette id, used by §15.7.

**Main arc (3):**
- **The Sealed Order** (S1–S2), 4 steps, `sealed_archive`.
  - The archive holds a Sol-sealed order.
  - Decoding it is slow, needing Archive of Sol progress plus techs.
  - Fragment 1: "…all beacons dark…". Fragment 2: "…the wakes are heard…".
  - Choices shape the Ark's culture: an open or a restricted archive, which trades stability
    against research.
- **The Dark Beacon** (S2), 3 steps, `dark_beacon`.
  - Restoring Halden's Gate brings its logs back.
  - The keepers shut it down by order, and one keeper refused.
  - The player chooses whether to keep the beacon live (Noise, but mobility) or throttle it
    (half-speed lanes, less Noise).
- **What the Vael Heard** (S3), 5 steps, `vael_heard`.
  - Speaker-of-Seven recounts the Vael's own silence.
  - The player is shown Noise as the Vael perceive it.
  - The path choice (Quiet, Warn or Answer) sets flags for sandbox mode.

**Scenario and origin chains (6):**
- **The Founders' Vote** (S1), `founders_hall`. The Ark chooses its governance style: Council,
  Steward or Assembly. The choice is permanent: +influence, +stability or +research.
- **Cold Sleepers** (S1), `vault_frost`. 400 sleepers remain in the Ark's cold vaults. The choices:
  - wake them over 10 turns: +6 pops, and −10 stability for a time
  - wake the specialists only: +2 pops, +10% research
  - leave them sleeping: +influence later
- **The Ark's Last Engine** (S1, late), `ark_engine`. The choices:
  - dismantle the Ark's drive: +300 metals, and it closes the chance of a relic later
  - keep it as a monument: +5 stability forever
  - study it: +1 decode
- **Unlit Toll** (S2), 4 steps, `unlit_toll`. Mother Rook demands energy, and the demands
  escalate. The chain can end in war, in paying tribute, or in Mother Rook's Offer.
- **Meridian's Claim** (S3), 5 steps, `meridian_hall`.
  - Hale presents Meridian as Earth's heir and wants beacon access.
  - Investigating uncovers the suppressed message.
  - The player can expose it, which damages Meridian's stability and your relations, or bargain
    with it.
- **First Words** (S3), 4 steps, `vael_light`. Linguistics puzzles written as choices. The Vael's
  speech is shown with bracketed uncertainty that resolves as the chain progresses. Good choices
  unlock the Research Pact and a Vael relic tech hint.

**Emergent chains (16):**

| Chain | Premise | Vignette |
| --- | --- | --- |
| Solar Flare | shield the grid for energy, or accept a stability hit | `solar_flare` |
| Crop Blight | quarantine, or risk spread | `crop_blight` |
| Mine Collapse | rescue the miners (minerals) or seal the shaft | `mine_collapse` |
| Labor Strike | the scripted S1 teaching chain; negotiate, concede or suppress | `labor_strike` |
| Derelict Freighter | salvage it, claim its cargo, or honour the dead | `derelict_freighter` |
| Ghost Signal | a false Sol signal; investigate at a Noise cost | `ghost_signal` |
| Ice Comet Capture | redirect it for water and food, or leave it | `ice_comet` |
| Orbital Debris Cascade | a clean-up cost, or a sensor penalty | `debris_cascade` |
| Founding Day | a festival choice | `founding_day` |
| The Frontier Doctor | a recurring character; growth boons | `frontier_doctor` |
| Smugglers' Market | an Unlit-adjacent black market | `smugglers_market` |
| Refugee Slowboat | accept the refugees (pops, stability risk), or turn them away | `refugee_slowboat` |
| Ancient Ruins Survey | driven by a planet trait; relic research | `ancient_ruins` |
| The Rogue Core | a stray Sol-era AI in a derelict; ally or delete | `rogue_core` |
| Stellar Nursery | a nebula anomaly with a research windfall | `stellar_nursery` |
| The Quiet Lane | a dead beacon found; foreshadows the arc | `quiet_lane` |

**Writing standard for events:**
- Bodies are 60–140 words, with named people and a concrete image in the first sentence.
- Choices are 3–8 words each, with cost chips.
- There is no "OK" choice when the player actually has a real choice to make.

### 10.7 Counts checklist (the POC must hit all of them, finished and explained)

| Content | Count | After M0 |
| --- | --- | --- |
| Districts | 6 | data real (tiers in M1) |
| Buildings | 15 | stub |
| Planet types | 8 | real |
| Planet traits | 8 | real |
| Techs | 36 (+ Research Network) | stub |
| Military hulls | 3 | stub |
| Civilian ships | 3 | stub |
| Modules | 12 | stub |
| Stances | 4 | icons only |
| Admiral traits | 4 | — |
| Ordinances | 5 | stub |
| Treaties | 5 | stub (icons exist) |
| War goals | 3 | — |
| AI personalities | 2 | stub |
| Pirate faction | 1 | faction record |
| Event chains | 25 | — |
| Vignettes | ≥ 25 (one per chain; 20 at the least) | 1 showcase sample |
| Portraits | 6 named characters (neutral, plus optional warm, worried and stern), plus generic generators | — |
| Codex entries | every one of the above, plus a Mechanics section | — |
| Advisor lines | at least 1 per mechanic | — |
| Scenarios | 3, with briefing and debrief | S1 stub |
| Legacies | 9 (3 per scenario debrief) | — |
| UI and game sounds | the list of §15.4 | — |
| Music tracks | 28, visual-novel style (§15.5) | — |

---

## 11. Sandbox mode (M4, after the POC is approved)

**Galaxy generation:**
- A small spiral of 20–50 systems (the player chooses the size).
- Arm-and-core placement with minimum spacing, lanes from a relative neighbourhood graph, and 2–4
  dormant beacons placed so they link regions.
- Habitable planets are scarce (about 10–15% of planets) and clustered.

**Setup:** the player picks:
- an origin (4)
- a galaxy size
- 1–4 AI empires: Meridian, the Vael, plus 2 generated human successor states using the
  personalities Zealous Restorer and Isolationist Commune
- a difficulty preset and sliders
- a seed

**Victories:**

| Victory | Condition |
| --- | --- |
| Federation | found, and lead for 30 turns, a federation of ≥ 3 empires (needs Federation Theory) |
| Science | complete the Beacon Archive: all tier IV techs, 5 beacons restored, then the Archive project (2,000 research across branches) |
| Wonder | build the Hearthlight megaproject (4 stages; metals, research and turns) and reach 150 pops (150k settlers) |
| Conquest | control 60% of capital systems for 10 turns |
| Story | resolve the Silence through one of the five endings (§4.3) |
| Fallback | score at turn 400 |

**Extra sandbox systems:**
- a dynamic market
- federations and a simple council (3 resolutions)
- Attention crisis events (high Noise), foreshadowed and escalating
- repeatable techs
- relics from ruins
- the ending pieces of the soundtrack (§15.5)

**Gates:**
- a 300-turn bot soak at 50 systems with 4 AIs and no errors
- every victory reachable by a bot or cheat script
- end-turn time within budget

---

## 12. Milestones, task lists and gates

Every milestone ends with:
- all of its tasks done
- CI green
- the report written
- the web build deployed (merge to `main`)
- a stop to wait for the Owner's playtest verdict

### M0: Foundation and UI kit (**done**)

**Built:**

| Area | What exists |
| --- | --- |
| Repository | bootstrap and CI |
| `sim/` skeleton | state and saves, RNG with vectors, Command/Result and the queue, a TurnProcessor with 14 empty phases, Breakdown, ReportItem and WhyLog |
| Tests | the test runner and the boundary scan |
| Data | ContentDb, the validator, and every data file (real or stub) |
| Strings | the string table |
| UI kit | tokens, runtime theme, fonts, every component, the responsive layout, overlays |
| Art | 87 icons, filled and outlined, plus the contact sheet; star and planet renderers |
| Tools | screenshot tour and id audit; bot runner and telemetry gates; palette report; web smoke test |
| Showcase | the main scene of the M0 build |

The full list is in `docs/milestones/M0_REPORT.md` and `CHANGELOG.md`.

**Gate:**
- CI green. Verified: run 35977347923, and the merge run on `main`.
- Deployed to Pages.
- The Owner reviewed the look: approved, with the display renames and units of §5.0 (applied after
  M0).

### M1: First Light

**Status:** tasks 1–4 and 6–8 below are built (rules, commands, data, events, audio, asset ids,
bots and telemetry), and task 5 in part (the app shell, the campaign flow screens, the Codex,
saves, planets and the main scene); the balance gates are computed after a balance pass, and
three still fail. The game screen, its views and overlays, and task 9 remain. See "M1 progress
and where to resume".

**Tasks:**
1. **Rules** (`sim/rules/`), each with unit tests and breakdowns:
   - economy: jobs, output, upkeep, caps and overflow warnings
   - growth and famine
   - stability and colony stages
   - research: card draw, costs, catch-up, reroll
   - districts: tiers and adjacency
   - buildings
   - governors
   - ordinances
   - in-system outposts
   - colony ships and colonisation
2. **Commands:** place, upgrade and demolish a district; build a building; set job priority
   (built); pick and reroll research; activate and cancel an ordinance; set a governor focus,
   limit and veto; build a ship; found a colony; build an outpost; answer an event choice; rename
   a colony (built).
3. **Data:** buildings (15), techs (37), ordinances (5), district tiers, the Research Network and
   Megaplex decisions (§10.3, §10.4), the full Scenario 1 (objectives, tutorial, legacies),
   vignettes and portraits as fallback parameters.
4. **Events engine:** triggers, the director and pacing, choices, costs and effects, delays,
   flags, the log, and "Uncertain" ranges. Each step can name its speaking character (a portrait
   and an expression) and a music cue. Content: the S1 chains (Founders' Vote, Cold Sleepers,
   Labor Strike, The Sealed Order steps 1–2, The Ark's Last Engine) and the S1-eligible emergent
   chains.
5. **Screens:**
   - the title screen
   - campaign select
   - the galaxy view (Ember plus fogged neighbours)
   - the system view
   - the colony planner (with the adjacency ghost preview and deltas)
   - research (cards and the tree)
   - the event modal: the story scene, the speaking character's portrait, the text, the choices
   - the turn report
   - Why?
   - the advisor tutorial
   - the Codex (the S1 subset)
   - settings
   - save and load (auto-saves, checkpoints, thumbnails)
   - briefing and debrief
   - the planet renderer upgraded to lit spheres, to match the painted world (§8.3)
6. **Audio:** music playback (the title theme, era tracks, and event cues with crossfades; §15.5)
   and the UI sound hooks (the bus layout, volume sliders, mute), using the §15.4 files when
   delivered and synthesised blips otherwise.
7. **Asset ids:** `data/asset_manifest.json` lists every §15 id with its kind and status, and the
   game resolves each id to a delivered file or its placeholder. The intake tool
   (`tools/import_assets.py`, §15.2) is built, and the first delivery is in (DESIGN_LOG 93).
8. **Bot:** the balanced, economy, turtle and random-legal policies playing the full S1; the
   telemetry tools with real balance gates. Reachability in `validate_data` becomes real.
9. **Main scene:** the title screen. The showcase moves to a debug menu item (and stays in the
   tour).

**Gate:** as described below the M3 section.

### M2: The Crossing

**Tasks:**
- the multi-system map, fog, travel and ETA, survey and auto-explore, anomalies
- fleets, the designer, auto-fit, combat and the forecast, the replay and the breakdown
- ship sprites: code fallback, plus the §15.8 sprites if delivered
- the VFX kit (§15.6) for the replay, beacons and jumps
- the Unlit AI, beacons, Noise
- the S2 chains, the Codex additions, a military bot policy

**Gate:** as below, plus a combat check:
- The forecast agrees with the actual result in at least 80% of 200 sampled battles.
- Every breakdown's factors explain at least 90% of the outcome: re-run the battle without each
  factor, and rank the factors by how much the result changes.

### M3: Neighbours and campaign polish

**Tasks:**
- diplomacy, treaties, war goals and exhaustion, occupation
- the utility AI for Meridian and the Vael, and the AI Why? log
- the market, the S3 chains, the debriefs and legacies
- an accessibility pass: colour-blind check, high contrast, reduce motion, key remap
- the full UI and game sound set (§15.4)
- the Android export (signing keys as repository secrets)

**Gate:** as below, plus an AI audit:
- 20 bot-vs-AI runs with no AI stalls
- the AI reaches at least 70% of the player bot's economy by turn 60
- every AI war declaration has a logged reason

### The M1–M3 gate

1. Tests and CI are green: unit, integration, golden, saves, data and boundary.
2. **Explanation audit:**
   - the id audit passes on every screen, at both sizes and both text scales
   - every numeric label in the tour is an Explainable
   - every event choice shows its costs
   - the web smoke test passes on PC, phone and tablet
3. **Balance telemetry,** over 20 bot runs per policy with varied seeds:
   - **No hoarding:** no resource stays above 10 turns of its gross income for more than
     10 consecutive turns, in more than 20% of runs.
   - **Everything matters:** every district and building is built in at least 25% of runs, and
     every tech is picked in at least 15%.
   - **Winnable, not trivial:** the balanced bot wins 60–90% of runs on Normal; the random-legal
     bot wins under 20%; the balanced bot wins 85–100% on Story.
   - **Pacing:** the median win turn is within ±20% of the scenario's expected duration.
   - **No dead turns:** in the balanced runs, the median share of turns with no meaningful
     decision available is under 25%. A decision counts as meaningful when the bot had at least
     2 legal non-trivial commands.
4. Performance is within the budgets in §9.11.
5. The Owner playtests on PC and a phone browser, and signs off.

**The report** (`docs/milestones/M<n>_REPORT.md`) contains:
- what was built
- gate results, with commands and numbers
- screenshots
- known issues
- deviations from this prompt (each also in DESIGN_LOG)
- decisions the Owner can overrule
- questions for the Owner

### M4: Sandbox

- Build §11, with origins 2–4.
- Music (§15.5) and the full VFX set.
- iOS, if a Mac is available.
- A store-readiness checklist: icons, capsule art (§15.9), and a trailer capture script.

### Asset track (runs in parallel; the Owner drives it)

| Batch | Contents | Needed by | Section |
| --- | --- | --- | --- |
| A1 | UI sounds | M1 | §15.4 |
| A2 | Story scenes, S1 set (7 ids) | M1 | §15.7 |
| A3 | Portraits (6 named characters, optional expressions) | M1 | §15.7 |
| A4 | Remaining story scenes | M2–M3 | §15.7 |
| A5 | Ship sprites | M2 | §15.8 |
| A6 | VFX kit | M2 | §15.6 |
| A7 | Game sounds | M2–M3 | §15.4 |
| A8 | Title key art and logo | M3 | §15.9 |
| A9 | Music (priority tracks first) | M1 (priority), M2–M4 (rest) | §15.5 |
| A10 | Store art | M4 | §15.9 |

Each batch goes through the intake of §15.2 and gets its own changelog entry. **The track is on
hold** (Owner, before M1): milestones use the code placeholders until the Owner resumes it.

---

## 13. Reference

### 13.1 Data-file conventions

- JSON with no comments. The top level is `{ "version": 1, "<plural>": [...] }`.
- Every record has an `id` (snake_case), a `name_key` and a `desc_key`, plus stage or unlock data
  where relevant. The schema lives in `sim/data/schema.gd`; the validator is `tools/validate_data.gd`.
- Numbers use the fixed-point rules: resources in centi-units, percentages in basis points. For
  authoring convenience, centi fields accept `"4.00"` strings, which are converted once at load.
- No expressions in data. Effects are `{ "key": <effect_key>, "value": <int>, "target": <optional selector> }`.
- Resources carry `unit_key` for their display unit (§5.0).

### 13.2 Example records

```json
{ "version": 1, "districts": [
  { "id": "agriculture", "name_key": "district.agriculture.name", "desc_key": "district.agriculture.desc",
    "icon": "district_agriculture", "cost": { "minerals": 6000 }, "build_turns": 3,
    "upkeep": { "energy": 50 }, "housing": 1,
    "jobs": [ { "job": "farmer", "count": 2 } ],
    "adjacency": [ { "with": "agriculture", "bonus_bp": 500, "cap_bp": 2000 } ],
    "tiers": [ { "tier": 2, "requires_tech": "advanced_districts", "cost_mult_bp": 20000, "extra_jobs": 1, "output_bp": 2500 },
               { "tier": 3, "requires_tech": "foundry_automation", "cost_mult_bp": 30000, "extra_jobs": 2, "output_bp": 5000 } ] }
]}
{ "version": 1, "jobs": [
  { "id": "farmer", "name_key": "job.farmer.name", "output": { "food": 400 } },
  { "id": "metallurgist", "name_key": "job.metallurgist.name", "output": { "alloys": 300 }, "input": { "minerals": 600 } }
]}
{ "version": 1, "resources": [
  { "id": "food", "name_key": "res.food.name", "unit_key": "res.food.unit", "cap": 50000, "icon": "res_food",
    "color": "ok.green", "sinks": ["pop_upkeep", "pop_growth", "colony_ships", "market_sell"] }
]}
```

### 13.3 Effect keys (a closed set; extend only by adding code, tests and Codex text together)

The set lives in `sim/data/effect_keys.gd`.

| Group | Keys |
| --- | --- |
| Output and stats | `output_bp`, `resource_output_bp:<res>`, `district_output_bp:<district>`, `stability_add`, `growth_bp`, `housing_add` |
| Unlocks and slots | `unlock_building`, `unlock_district_tier`, `unlock_module`, `unlock_hull`, `edict_slots_add` (ordinance slots), `treaty_slots_add`, `slots_add` |
| Costs, influence and sensors | `influence_per_turn_add`, `outpost_cost_bp`, `ship_cost_bp`, `cap_add:<res>`, `sensor_range_add` |
| Noise and story | `noise_add`, `noise_transit_bp`, `decode_progress_add` |
| Opinion | `opinion_add:<faction>` |
| Combat | `hit_chance_bp`, `damage_bp:<type>` |
| Research | `research_bp:<branch>` |
| Flags and events | `set_flag`, `clear_flag`, `spawn_event` |
| Stock and pops | `add_stock:<res>`, `add_pops`, `remove_pops` |
| Planet | `clear_blocked_slot`, `add_trait`, `remove_trait` |

### 13.4 Event format

```json
{ "id": "s1_cold_sleepers", "chain": "cold_sleepers",
  "steps": [
    { "step": 1,
      "trigger": { "min_turn": 18, "flags_all": ["founders_vote_done"], "flags_none": ["sleepers_resolved"], "weight": 100, "scripted": true },
      "vignette": "vault_frost", "portrait": "archivist_sola",
      "title_key": "event.cold_sleepers.1.title", "body_key": "event.cold_sleepers.1.body",
      "choices": [
        { "label_key": "event.cold_sleepers.1.wake_all",
          "cost": { "food": 10000 },
          "effects": [ { "key": "add_pops", "value": 6, "over_turns": 10 }, { "key": "stability_add", "value": -10, "turns": 10 } ],
          "next": null, "set_flags": ["sleepers_resolved", "sleepers_woken"] },
        { "label_key": "event.cold_sleepers.1.wake_specialists",
          "effects": [ { "key": "add_pops", "value": 2 }, { "key": "research_bp:all", "value": 1000 } ],
          "set_flags": ["sleepers_resolved"] },
        { "label_key": "event.cold_sleepers.1.let_sleep",
          "effects": [],
          "next": { "step": 2, "delay_turns": 20 }, "set_flags": ["sleepers_waiting"] }
      ] }
  ] }
```

**As built in M1:** a chain file also has `version`, `kind` (`scripted`, `main_arc`, `status` or
`emergent`), optional `scenarios`, `vignette`, `cooldown` and `weight`. A step has `speaker`,
`expression` (`neutral`, `warm`, `worried`, `stern`), `music` (a §15.5 id), `hint_key`, and
`on_fire` {`effects`, `set_flags`}; a later step's `trigger` is a requirement it waits for. A
choice has `cost`, `effects`, `set_flags`, `clear_flags`, `next`, `requires` and `locked_key`; an
"Uncertain" choice has `uncertain: true` and `outcomes` [{`chance_bp`, `text_key`, `effects`,
`set_flags`, `next`}] summing to 10000. Trigger conditions: `min_turn`, `max_turn`, `flags_all`,
`flags_none`, `colony_stability_max`, `colony_stability_min`, `colony_pops_min`, `colonies_min`,
`has_building`, `has_district`, `techs_all`, `stock_min`, `stock_max`, `net_max`, `net_min`,
`decode_min`, `outposts_min`, `colony_planet_type`, `colony_is_capital`, `autonomous_colony`.
Effects with `"target": "colony"` land on the event's colony; `turns` makes them timed and
`over_turns` gradual.

### 13.5 Scenario format (outline; S1 as built)

```json
{ "id": "s1_first_light", "name_key": "scenario.s1.name", "origin": "generation_ark",
  "map": { "systems": [ ... ], "lanes": [ ... ], "fog_locked": ["..."] },
  "start": { "empires": [ { "id": "player", "stock": {...}, "colonies": [...], "fleets": [...], "techs": [...] } ] },
  "objectives": { "required": [ { "id": "develop_3", "type": "colonies_developed", "count": 3, "text_key": "..." } ],
                  "optional": [ ... ] },
  "tutorial": [ { "id": "t_food_tooltip", "turn": 1, "highlight": "topbar.food", "text_key": "...",
                  "complete_on": { "ui_event": "tooltip_opened:food" } } ],
  "scripted_events": ["labor_strike", "founders_vote", "cold_sleepers", "sealed_order"],
  "legacies": ["seasoned_farmers", "archive_scholars", "steady_hands"],
  "loss": [ { "type": "capital_pops_zero" }, { "type": "capital_autonomy" } ] }
```

**As built in M1** (see `data/scenarios/s1_first_light.json`): also `briefing_key`, `debrief_key`,
`status` (`playable`), `expected_turns`, `director_start`, `teaches`, `tech_pool`
{`exclude_military`, `always_offer`}, `locked_ordinances`, `locked_buildings`, `music`, and `balance_scope`
{`districts`, `buildings`, `techs`} (what the "everything matters" gate checks). A start empire
has `surveyed`, `research_hands` per branch, `ships` [{`hull`, `system`}], and colonies with
`capital`, `buildings` (landmarks use slot −1) and district `branch`. Objective types:
`colonies_developed`, `outposts`, `stability_streak` (`min`, `turns`, `min_colonies`), `flag`,
`total_pops`, `techs`, `never_flag`. Tutorial `complete_on` is `{ui: ...}` or `{state: ...}`
with the conditions of `sim/rules/tutorial.gd`.

### 13.6 AI personality format

```json
{ "id": "ambitious_steward", "weights": { "economy": 10000, "expansion": 14000, "threat": 9000, "opportunity": 11000, "diplomacy": 12000, "story": 6000 },
  "war_threshold": 40, "treaty_bias": { "trade_deal": 30, "nap": 10, "research_pact": 0 },
  "noise_sensitivity": 0 }
```

Weights are basis points (1.0 = 10000).

### 13.7 Bot policies (`tools/bot_run.gd`; skeleton built)

| Policy | What it plays like |
| --- | --- |
| balanced | a competent human: meets needs, builds toward objectives, answers events by expected value |
| economy | maximises output |
| military | prioritises fleets and conquest |
| turtle | minimal expansion, high stability |
| random-legal | uniformly random legal commands (a sanity floor) |

Run:
`godot --headless --path . -s tools/bot_run.gd -- --scenario s1 --policy balanced --seeds 1-20 --out telemetry/ --check-determinism`

Each run writes per-turn JSON:
- stocks, income, caps and overflow
- built counts and techs picked
- stability minimum and mean
- decisions available versus taken
- events fired and battles
- the objective state
- timing

`tools/telemetry_report.gd` aggregates the runs and prints PASS, FAIL or SKIP for each gate of §12.

### 13.8 Built icon ids (87; `assets/icons/<id>.svg` and `<id>_outline.svg`)

| Group | Ids |
| --- | --- |
| Resources | res_food, res_energy, res_minerals, res_alloys, res_research, res_influence |
| Branches | branch_physics, branch_society, branch_engineering |
| Districts | district_habitation, district_agriculture, district_energy, district_mining, district_industry, district_research |
| Planet types | planet_continental, planet_ocean, planet_arid, planet_ice, planet_barren, planet_toxic, planet_gas_giant, planet_asteroid_belt |
| Traits | trait_fertile, trait_veins, trait_geothermal, trait_locked, trait_toxic, trait_low_gravity, trait_ruins, trait_radiation |
| Emblems | emblem_hearth, emblem_compass, emblem_spiral, emblem_broken_circle |
| Stances | stance_cautious, stance_balanced, stance_aggressive, stance_last_stand |
| Alerts | alert_info, alert_success, alert_warning, alert_critical |
| Treaties | treaty_nap, treaty_trade, treaty_research, treaty_open_borders, treaty_peace |
| Damage | dmg_kinetic, dmg_thermal, dmg_explosive |
| Stats | stat_pops, stat_housing, stat_growth, stat_stability, stat_noise |
| Ships | ship_survey, ship_construction, ship_colony, ship_fleet, ship_starbase |
| Map | map_anomaly, map_beacon, map_outpost |
| Interface | ui_back, ui_check, ui_chevron_right, ui_close, ui_codex, ui_colony, ui_diplomacy, ui_edict, ui_end_turn, ui_event, ui_fleet_move, ui_governor, ui_lock, ui_menu, ui_minus, ui_pin, ui_plus, ui_report, ui_save, ui_search, ui_settings, ui_undo, ui_why |

**New icons needed in M1–M3** (author them in the same generator style; add them to the sheet):
- buildings: storehouse, hydroponics, fusion_plant, foundry, research_institute, civic_hall,
  park_commons, clinic, spaceport, planetary_shield, market_exchange, archive_of_sol,
  listening_post, habitat_dome, ark_hull
- hulls: corvette, frigate, cruiser
- the 12 modules
- the 4 admiral traits
- war goals: claim, humiliate, liberate
- difficulty
- objective (required, optional)
- legacy

### 13.9 Definition of Done (for every feature)

- [ ] The rules are in `sim/`, with unit tests and breakdowns.
- [ ] The content is in `data/` and passes `validate_data`.
- [ ] All strings are in `en.csv`, with no raw ids; units per §5.0.
- [ ] The UI works on PC and at phone size, at 100% and 200% text scale, with screenshots in the
  tour.
- [ ] The web smoke test passes.
- [ ] `Explainable` is wired on every number.
- [ ] A Codex entry exists, and the advisor hint is written.
- [ ] A scenario uses it, and the bot exercises it.
- [ ] Any outsourced asset it uses has passed the intake (§15.2), and its fallback still works.
- [ ] The CHANGELOG.md entry is written, with Verified or Unverified marked.

---

## 14. Decisions

### 14.1 Settled (the Owner may still overrule any of these)

- **Story and cast.** The main-arc truth is the one in §4.3: Earth went quiet on purpose, because
  jump wakes are heard. Jump drives are both power and Noise. The names and personalities of the
  Meridian Directorate, the Vael, the Unlit and the six named characters are as written in
  §4.5–§4.6.
- **Origins.** The campaign origin is fixed to the Generation Ark. Origins can be chosen in
  sandbox only.
- **Platform.** Phones use landscape only; the web build also reflows in portrait.
- **Clean slate.** Nothing from the previous prototype carries over: no names, data or code.
- **Calendar.** "Month M, Year Y S." (Silence era). The game starts in Year 100 S.
- **Language.** Only English, but every string goes through the string table.
- **Builds.** The web build is for playtesting only. Store builds are Windows, Android and iOS
  (iOS once a Mac is available).
- **Repository and hosting.** The repository is public; the web build deploys to GitHub Pages
  from `main` (Owner, after M0).
- **The M0 look** is approved (Owner, after M0).
- **Display renames and units** (Owner, after M0; §5.0):
  - Alloys → Metals
  - Edicts → Ordinances
  - Pops → Settlers (1 pop = 1,000)
  - Food kt, Energy GW, Minerals Mt, Metals kt
- **Outsourced assets** are allowed through the intake contract (§15). Every asset keeps a code
  fallback.
- **Art direction:** a flat interface over a painted-diorama world (Owner, after M0; §8.1,
  §15.3).
- **Soundtrack:** visual-novel style, with character themes and mood cues from M1 (Owner, after
  M0; §8.6, §15.5).
- **Web build budget:** 150 MB as the compressed download (Owner, after M0).
- **Outsourced assets are on hold:** M1 onward builds against the code placeholders until the
  Owner resumes (DESIGN_LOG 50).
- **Technical decisions** DESIGN_LOG 1–41 (M0, listed in the M0 report) and 42–50 (after the M0
  review) stand unless overruled.
- **M1 decisions** DESIGN_LOG 51–84 (M1 plan and build), all open to the Owner. The ones that change
  how the game feels:
  - the fixed-rate market arrives in M1 with the Market Exchange (78)
  - rushing a build with energy (81)
  - governors pay from a purse filled by their share of minerals income (80)
  - a colony ship's hull becomes the colony's free first shelter (77)
  - Scenario 1 always offers Habitat Domes once Frontier Medicine is known (79)
  - the stability objective counts only turns with two or more colonies (83)
  - Cinder is a small dome world (66)

### 14.2 Still open (continue with the default until the Owner answers)

| Question | Default |
| --- | --- |
| Licence | "All rights reserved". The repository is now public; code stays unlicensed for reuse unless the Owner picks one |
| Negative-number colour for colour-blind players | keep ember #FF6B4A. Recommended alternative: coral pink #FF6F91 for negative numbers only |
| Polity name | "The Ember Compact" |
| Music source | outsourced per §15.5 |
| Event scene layout | the card of §7 (scene on top, portrait beside the text); a full visual-novel layout (scene full-screen, portrait over it, text box below) is offered in the M1 plan |
| Research Institute unlock and tier III | settled at M1 with the §10.3 and §10.4 defaults (DESIGN_LOG 65) |
| Balanced bot wins 100% on Normal (band 60–90%) | make Normal harsher (for example emergent events), keeping the median win within turns 56–84; to be proposed in the M1 report |

---

## 15. Outsourced assets: briefs and the intake contract

**Purpose.** The Owner can commission sound, music, VFX and graphics from people or generators.
They hand the output back to the builder, who ingests it without rework. This section is written
so each brief can be copied as-is to whoever makes the asset. The builder keeps a copy of each
brief as `docs/assets/<kind>.md` when a batch is commissioned, with the item list trimmed to that
batch.

### 15.1 Rules that apply to every kind

1. **Ids are fixed.** Every deliverable has an exact id from the lists below. The file name is
   `<id>.<ext>`, lowercase with underscores. There are no other names, no version suffixes
   (`_v2`, `final`) and no spaces.
2. **One zip per batch**, named `sfh_<kind>_batch<N>.zip` (for example `sfh_sfx_batch1.zip`). It
   holds the files at its root, plus a `manifest.json`:
   ```json
   { "kind": "sfx", "batch": 1,
     "licence": "CC0 | work-for-hire, all rights to the Owner | generated, commercial use allowed (tool + plan named) | CC BY (with \"attribution\")",
     "source": "who or what made it (person, studio, or tool and version)",
     "items": [ { "id": "ui_click", "file": "ui_click.wav", "notes": "optional" } ] }
   ```
   Items can be left out; a missing item keeps its fallback. An unknown id is rejected. If a
   maker cannot produce the manifest, the Owner sends the files with their source and licence,
   and the builder writes the manifest.

   | Kind | Brief | Batches |
   | --- | --- | --- |
   | `sfx` | §15.4 | 1 = UI sounds (A1); 2 = game sounds (A7) |
   | `music` | §15.5 | 1 (A9) |
   | `vfx` | §15.6 | 1 (A6) |
   | `vignette` | §15.7 | 1 = the seven Scenario 1 scenes (A2); 2 = the other eighteen (A4) |
   | `portrait` | §15.7 | 1 (A3) |
   | `ship` | §15.8 | 1 (A5) |
   | `art` | §15.9 | 1 = title key art and logo (A8) |
   | `store` | §15.9 | 1 = store and platform art (A10) |
3. **Licence:**
   - Allowed: CC0; work-for-hire with all rights assigned to the Owner; generated with
     commercial-use rights that the tool's terms grant for this plan; or CC BY (attribution
     only) when the batch manifest gives the credit as `"attribution"` (DESIGN_LOG 105).
   - Rejected: non-commercial terms, share-alike, no-derivatives, or any attribution
     requirement beyond a credit line.
   - Every accepted batch is credited in `CREDITS.md`.
4. **No text in images, and no logos or trademarks** other than the game's own. Do not imitate
   named artists or franchises.
5. **Style:** world art (story scenes, portraits, ships, key and store art) follows the
   painted-diorama direction of §15.3. VFX are white and greyscale, tinted by the engine. The logo
   stays flat vector.
6. **Colour:** the palette of §8.2 gives the key colours. Rendered art may use any shades of them
   for light and shade, plus these tones for people: skin #F2D2B6 #E0B08A #C68A5E #9A6440 #6E4630
   #4A2F22; hair #2B211C #5A3B28 #8C6A4A #C9A56A #D8D8D8. Intake reports each image's dominant
   hues for a visual check instead of snapping colours. The logo uses exact palette values.
7. **The logo's SVG files** have fills and opacity as attributes. They have no `<style>` blocks
   and no live text: lettering is converted to paths.

### 15.2 How the builder ingests a batch (built in M1: `tools/import_assets.py`, DESIGN_LOG 93)

1. Put the zip in `incoming/`. This folder is git-ignored and `.gdignore`d. The Owner gets it
   there in one of three ways:
   - upload it to the repository on a branch; GitHub's web upload takes files up to 25 MB, so big
     files such as music go one per upload
   - attach it to a GitHub Release (files up to 2 GB; the first delivery came this way, as one
     zip holding the batch zips), which the builder downloads
   - attach it in the chat
2. Run: `python3 tools/import_assets.py --zip incoming/sfh_sfx_batch1.zip` (repeat `--zip` for
   more batches; `--check` reports without writing), then
   `godot --headless --path . --import`. The tool needs
   `pip install -r tools/requirements-assets.txt`: Godot cannot encode Ogg Vorbis.
3. The tool checks:
   - the manifest
   - that every id is in `data/asset_manifest.json` (the expected-id list for every kind, with the
     specs of §15.4–§15.9)
   - format, dimensions or sample rate, duration and loudness range
   - for rendered art: the size, and an alpha channel or a flat #00FF00 background to key out.
     It also writes a contact sheet and a dominant-hue report for a visual check
   - for the logo's SVGs: paths only, palette colours, and no raster, filter, text or script
4. It converts where needed: WAV or FLAC to Ogg Vorbis for music (and a looping sound); other
   sounds to 16-bit WAV; PNG to lossy WebP at display size for scenes (2400×900), portraits
   (768×768) and key art (2560×1440); flipbook metadata from the notes. It trims near-silence
   before a sound and keys out a #00FF00 background, and says so.
5. It copies the files to `assets/delivered/<kind>/` with the Godot import settings they need
   (painted art lossy with mipmaps; music looping except the stings), keeps store art in
   `assets/delivered/store/` (ignored by Godot, so it never ships in the game), and records the
   licence and source in `CREDITS.md`.
6. It marks each id "delivered" in `data/asset_manifest.json` with its file (or variant files),
   so the game swaps from the fallback.
7. It prints a PASS or FAIL report per item. It never overwrites a delivered asset without
   `--replace`.
8. The builder then runs the screenshot tour (and, for audio, a listening check with the level
   report), commits `content(assets): <kind> batch <N>`, and notes the batch in CHANGELOG.

**Rejected items** come back to the Owner as a short list: id, the rule broken, and the fix
("ui_error.wav: 1.2 s, max is 0.6 s").

### 15.3 Shared direction (paste at the top of every brief)

**The game, for every brief:**

> Starfire Hearth is a turn-based space strategy game with a hopeful, hard-science-fiction tone,
> and its story unfolds in illustrated scenes in the manner of a visual novel. People are
> competent, communities are warm, and space is vast and slow. The player leads a slowboat colony
> a hundred years into "the Long Silence", the century since Earth stopped answering. Everything
> should feel calm, human and a little lonely, with warmth in the details.

**Art direction: painted diorama** (Owner decision after M0; DESIGN_LOG 45). It combines two
things:
- the **forms** of a cozy sci-fi diorama: stylized, chunky 3D shapes with bevelled edges and clear
  silhouettes, like a hand-built miniature model
- the **rendering** of hopeful 1960s space-age painting: soft visible brushwork, glowing light,
  luminous painted skies and atmospheric haze

Its rules:
- **Lighting:** one warm key light from the upper left (about 10 o'clock, 45 degrees up), a cool
  blue fill from the right, and a thin rim light on edges. Soft light shafts where there is dust or
  mist. Every image has at least one warm light source: lit windows, lamps, or the orange home
  star.
- **Depth:** layered 2.5D depth. Distance dissolves into painted blue haze; the foreground carries
  the richest colour and contrast.
- **Surfaces:** painted, not photographed: matte metal, fabric, frosted glass, soft glowing lights,
  small signs of life (panel seams, patches, cables, plants). No grime or gore.
- **Skies:** luminous painted gradients, nebulae, dawn and dusk light.
- **Mood:** calm, human, a little lonely, warm in the details. A hopeful frontier, like the cover
  of an optimistic 1960s science-fiction novel built as a miniature.
- **Consistency:** the same light direction, brush treatment and level of detail in every image.
- **Avoid:** photorealism, photographic textures, film grain, noise, lens flares, chrome, busy
  mechanical clutter, anime or cartoon exaggeration, text, letters, logos, watermarks, and
  imitation of any named artist, studio or franchise.
- **Dark variant** (DESIGN_LOG 106): horror and grimdark are allowed for scenes that call for them,
  such as the darker routes and endings of the branching campaign. Keep the same diorama forms,
  light direction and brushwork, and shift to a muted palette of deep blues and cold greys, dread,
  emptiness and long shadows, with one small warm light as the accent. The "no grime or gore" rule
  under Surfaces still applies.

**Colour:** built around the key colours of §8.2, with any lighter and darker shades of them for
light and shade, plus the skin and hair tones of §15.1 for people. Most of each image sits in the
cool blues, with warm gold and orange light as the focal accent.

**Soundtrack direction** (Owner decision after M0; DESIGN_LOG 46): melodic and emotional, like a
story-rich visual novel.
- Piano and strings are at the heart, with acoustic guitar, flute, clarinet, harp, music box,
  glockenspiel, and soft synth pads for the space setting.
- Memorable melodies: a main theme, character themes, and mood pieces that story scenes call up.
- Interface sounds are tuned to D major pentatonic, so they sit inside the score.

**Mood references for human artists only** (never in generator prompts): the games *Before We
Leave*, *Dorfromantik* and *Outer Wilds*, and the hopeful space paintings of NASA's 1960s–70s art
programme.

### 15.4 Brief: sound effects (UI and game)

**Technical spec:**
- **Format:** WAV, 48 kHz, 24-bit (16-bit accepted), mono. Stereo is allowed only where marked.
- **Timing:** no silence longer than 5 ms at the start; a natural tail with no hard cut.
- **Loudness:** peak ≤ −1 dBTP. UI sounds are about −20 LUFS short-term; game sounds about
  −16 LUFS.
- **Character, UI:** musical and soft, like the interface of a story-rich visual novel: felt piano
  notes, music box, harp plucks, soft bells, glass, gentle wooden taps. Pitched sounds are tuned to
  D major pentatonic (D, E, F#, A, B).
- **Character, game:** tactile, warm and slightly musical, matching a painted-diorama world. Combat
  is exciting but never violent or gory. Pitched stings are in D major or B minor where possible.
- **Always:** no voices, no phrase longer than 3 notes (except stings), and a gentle high end.
- **Variants:** where marked ×3, deliver `<id>_1.wav`, `<id>_2.wav` and `<id>_3.wav`.

| Id | Batch | Length | Description |
| --- | --- | --- | --- |
| `ui_click` | 1 | 30–80 ms | a small, soft tap, like a felt piano key or a wooden bead ×3 |
| `ui_hover` | 1 | 20–50 ms | barely there; a soft tick at about −30 LUFS (mouse hover) |
| `ui_confirm` | 1 | 120–250 ms | a positive two-note rise; accepting an order |
| `ui_cancel` | 1 | 80–200 ms | a soft falling note; closing or backing out |
| `ui_error` | 1 | 150–400 ms | a gentle, dull double bump; an order refused (never alarming) |
| `ui_toggle_on` | 1 | 60–120 ms | a switch flicked up, with a tiny rising tone |
| `ui_toggle_off` | 1 | 60–120 ms | the same switch flicked down, with a tiny falling tone |
| `ui_panel_open` | 1 | 120–250 ms | an airy whoosh-in with a faint harp shimmer, for drawers and sheets |
| `ui_panel_close` | 1 | 100–200 ms | the matching whoosh-out |
| `ui_tooltip_pin` | 1 | 40–100 ms | a tiny glass tick when a breakdown is pinned |
| `ui_end_turn` | 1 | 400–900 ms | a deep, satisfying low bell with a soft swell: "the month turns" |
| `ui_alert` | 1 | 250–500 ms | an attention chime for a non-critical notice |
| `ui_alert_critical` | 1 | 500–900 ms | a firmer two-tone warning; serious, not a siren |
| `ui_event_open` | 1 | 400–800 ms | a warm music-box shimmer as a story scene opens |
| `ui_choice_made` | 1 | 300–700 ms | a soft, resonant chord as a story choice is locked in |
| `ui_page_turn` | 1 | 150–300 ms | a soft page turn for the Codex and story pages ×3 |
| `ui_research_done` | 1 | 400–800 ms | a bright ascending three-note arpeggio |
| `ui_build_done` | 1 | 300–600 ms | a construction clunk followed by a small chime |
| `ui_place_district` | 1 | 150–300 ms | a soft "set" sound as a hex tile is placed ×3 |
| `ui_demolish` | 1 | 300–500 ms | a low, muted crumble |
| `ui_pop_growth` | 1 | 200–400 ms | a small, warm rising tone: new settlers have arrived |
| `ui_overflow_warn` | 1 | 200–400 ms | a soft "brimming" sound, a liquid-like pitch rising to the rim |
| `ship_move_order` | 2 | 150–300 ms | a confirming radio blip |
| `ship_arrive` | 2 | 200–400 ms | a soft engine settle |
| `survey_ping` | 2 | 400–800 ms | a sonar-like ping with a long tail (stereo allowed) |
| `beacon_activate` | 2 | 1.5–3 s | a rising harmonic hum that locks into a chord (stereo) |
| `jump_transit` | 2 | 0.8–1.5 s | a quick suck-in and release; faintly uncanny (stereo) |
| `noise_threshold` | 2 | 1–2 s | a distant low pulse, a heartbeat-like double; unsettling but quiet |
| `hit_kinetic` | 2 | 80–200 ms | a sharp metallic impact ×3 |
| `hit_thermal` | 2 | 100–250 ms | a sizzling laser burn ×3 |
| `hit_explosive` | 2 | 200–400 ms | a muffled boom ×3 |
| `shield_hit` | 2 | 150–300 ms | a glassy ripple ×3 |
| `pd_intercept` | 2 | 60–150 ms | a tiny rapid "tak-tak" of defence guns stopping a missile |
| `ship_destroyed` | 2 | 0.8–1.5 s | a hull breaking up, with debris (stereo) |
| `battle_won` | 2 | 1–2 s | a restrained victorious sting |
| `battle_lost` | 2 | 1–2 s | a sombre, low two-note fall |
| `treaty_signed` | 2 | 0.8–1.5 s | a formal soft chord, like a seal pressed into wax |
| `war_declared` | 2 | 1–2 s | a dark drum hit with a low drone tail |
| `vael_voice` | 2 | 1–2 s | light made audible: layered glassy tones, no human voice ×3 |
| `ambient_ui_room` | 2 | 20–40 s loop | an almost-silent ship interior hum behind menus (stereo; loop-seamless; about −30 LUFS) |

**Fallback:** synthesised blips in code for every id.

### 15.5 Brief: music (visual-novel style)

**Technical spec:**
- **Format:** WAV or FLAC, 48 kHz, 24-bit, stereo masters. The builder encodes to Ogg Vorbis. If a
  tool only exports compressed audio: Ogg Vorbis at quality 8 or better, or MP3 at 320 kbps as a
  last resort. The builder then recalculates the loop points.
- **Loudness:** −18 LUFS integrated (±1), peak ≤ −1 dBTP.
- **Loops:** every track except the stings and ending pieces loops seamlessly. The loop start and
  end are given in samples in the manifest's `notes` (for example `loop 96000-5856000`). A tool
  that cannot loop delivers 4 s of natural tail, and the builder cuts the loop.
- **Key:** where possible, the calm pieces are in D major or B minor, matching the interface
  sounds.
- **Stems (optional):** `<id>__melody.wav` (the lead melody only) and `<id>__bed.wav` (everything
  else). The game lowers the melody under long passages of story text.
- **Vocals:** no lyrics. Wordless voices are allowed only in `mus_title` and the ending pieces.

**How the game uses them:** the era tracks play on the map and colony screens. An event step
names a character theme or a mood, which crossfades in while the scene is open (§5.10). Priority
tracks (P) are needed first, for Scenario 1.

| Id | Length | Mood and use |
| --- | --- | --- |
| `mus_title` (P) | 2–3 min | the main theme: hopeful and bittersweet; introduces the main motif (a simple 4–6 note melody) on solo piano, then strings join |
| `mus_slowboat_1` (P) | 2–3 min | early game, daily life: gentle, warm, domestic; piano and acoustic guitar; morning in the colony |
| `mus_slowboat_2` | 2–3 min | early game variation: afternoon work; flute and light strings; unhurried |
| `mus_beacon_1` | 2–3 min | mid game: the region opens up; curiosity and wonder; broader strings, harp arpeggios |
| `mus_beacon_2` | 2–3 min | mid game variation: trade and neighbours; a little more motion; light percussion allowed |
| `mus_jump_1` | 2–3 min | late game: power with unease; the main motif in a minor key; low strings and piano |
| `mus_jump_2` | 2–3 min | late game variation: grand but lonely |
| `mus_attention` | 2–3 min | when the colony grows too loud and something vast notices: sparse, eerie, a slow low pulse, glassy high notes |
| `mus_battle` | 1.5–2 min | battle replays: urgent but restrained; string ostinato; timpani allowed |
| `theme_sola` (P) | 1.5–2.5 min | Archivist Imre Sola: dry, warm, scholarly, a little playful; clarinet or bassoon, pizzicato strings, piano |
| `theme_varga` (P) | 1.5–2.5 min | Steward Anneliese Varga: steady and earnest, carrying worry; warm cello and piano |
| `theme_brandt` | 1.5–2.5 min | Captain Oduya Brandt: loyal, restless, brave; a light march with brushed snare and horn |
| `theme_hale` | 1.5–2.5 min | Director Kasimir Hale and the Meridian Directorate: charming, elegant, formal; a waltz with a hidden minor turn |
| `theme_speaker` | 1.5–2.5 min | Speaker-of-Seven and the Vael: patient, alien, kind; glass harmonica, bowed crystal, slowly shifting harmonies |
| `theme_rook` | 1.5–2.5 min | Mother Rook and the Unlit: wry, weathered, clever; nylon-string guitar, low strings, a lopsided rhythm |
| `mood_warm` (P) | 1.5–2.5 min | heart-warming moments, reunions, festivals: gentle and bright |
| `mood_sorrow` (P) | 1.5–2.5 min | loss and farewells: solo piano, then strings; tender, not melodramatic |
| `mood_mystery` | 1.5–2.5 min | discoveries, ruins, strange signals: sparse, curious, suspended chords |
| `mood_tension` (P) | 1.5–2.5 min | standoffs, danger, hard decisions: a pulsing low-string ostinato |
| `mood_hope` (P) | 1.5–2.5 min | resolve and new beginnings after hardship: rising strings; the main motif returns |
| `mood_light` | 1.5–2.5 min | lighthearted and funny moments: pizzicato, woodwinds, playful |
| `sting_victory` | 10–20 s | a scenario won (no loop) |
| `sting_defeat` | 10–20 s | a scenario lost, offering a retry (no loop) |
| `sting_hide` | 45–90 s | ending "Hide": the region seals itself in silence; safe and small; the motif fades into stillness (no loop) |
| `sting_warn` | 45–90 s | ending "Warn": a relay reaches every lost colony; the motif passed between many instruments (no loop) |
| `sting_answer` | 45–90 s | ending "Answer": deliberate contact with something vast; awe and uncertainty; the motif answered by an unfamiliar interval (no loop) |
| `sting_shield` | 45–90 s | ending "Shield": a megastructure masks the region; protective and solemn; a long rising chord (no loop) |
| `sting_homecoming` | 45–90 s | ending "Homecoming": reaching Earth, which was listening all along; the motif in full, warm major (no loop) |

**Fallback:** silence.

### 15.6 Brief: VFX kit

The engine draws effects with 2D particles and flipbooks, tinted at run time. Deliver them
**white or greyscale on transparent**, and the engine colours them. They belong to the painted
world: soft glows, sparkles and painted puffs, with slightly soft, brushed edges. There is no
photographic smoke or fire.

**Technical spec:**
- **Format:** PNG, RGBA, straight (non-premultiplied) alpha, sRGB.
- **Flipbooks:** one PNG per effect, a grid of equal frames left to right then top to bottom, no
  gaps. The effect sits centred in each frame with at least a 4 px margin. Loops flow from the last
  frame back to the first. Put the grid and frame rate in the manifest `notes` (for example
  `4x4 16 frames 24fps loop`).

| Id | Size | Kind | Description |
| --- | --- | --- | --- |
| `fx_dot_soft` | 64 | texture | a round soft dot with radial falloff; the general particle |
| `fx_dot_hard` | 64 | texture | a filled circle with a slightly soft edge |
| `fx_spark` | 64 | texture | a thin elongated diamond streak, pointing right |
| `fx_shard` | 64 | texture | a small angular fragment |
| `fx_ring` | 128 | texture | a thin circle outline, 3 px at 128 |
| `fx_glow` | 256 | texture | a wide, very soft glow for stars and beacons |
| `fx_hex_shield` | 256 | texture | a faint hex-grid bubble segment (an arc), for shield hits |
| `fx_tracer` | 128×16 | texture | a horizontal beam, bright head on the right, fading tail to the left |
| `fx_sparkle` | 64 | texture | a four-point twinkle star with a soft glow |
| `fx_smoke_puff` | 128 | texture | a soft painted puff of smoke or dust with brushed edges |
| `fx_light_shaft` | 256×1024 | texture | a vertical beam of soft light, brightest at the top and fading out toward the bottom |
| `fx_explosion_small` | frames 128, sheet 512×512 | flipbook, 4×4, 24 fps | a burst: a ring expands, shards fly, a puff fades |
| `fx_explosion_large` | frames 256, sheet 1024×1024 | flipbook, 4×4, 24 fps | the same, larger, with a second ring |
| `fx_shield_ripple` | frames 128, sheet 512×256 | flipbook, 4×2, 24 fps | a hex ripple spreading from a point |
| `fx_beacon_pulse` | frames 256, sheet 1024×1024 | flipbook, 4×4, 12 fps, loops | concentric rings leaving the centre |
| `fx_jump_flash` | frames 256, sheet 1024×1024 | flipbook, 4×4, 24 fps | an inward collapse, then a sharp flash, then a fading ring |
| `fx_survey_sweep` | frames 256, sheet 1024×1024 | flipbook, 4×4, 12 fps, loops | a radar sweep arc turning 360° |

**Fallback:** code-drawn circles, lines and polygons.

### 15.7 Brief: story scenes (vignettes) and portraits

#### Story scenes

These are painted-diorama scenes behind the story text. The engine pans them slowly and draws its
own light flicker and particles over them.

- **Format:** one finished PNG per scene, `<id>.png`, 3200×1200 (8:3), sRGB. If a tool cannot make
  8:3, generate 21:9 or 16:9 at the highest resolution and upscale; the scene is cropped to 8:3.
- **Optional, from real 3D work:** the same scene as separately rendered, aligned layers
  (`<id>__sky.png`, `<id>__horizon.png`, `<id>__midground.png`, `<id>__foreground.png`,
  `<id>__accent.png`), transparent except the sky, for parallax.
- **Composition:**
  - Keep the key subject in the centre 60% of the width. The outer quarters may be covered by
    character portraits, or cropped on phones.
  - The horizon sits at 55–70% of the height.
  - People are small, figures in a place, with faces simple or turned away. Named characters
    appear as portraits; in scenes they are small and distant.
- **Batches:**
  - Batch 1, the Scenario 1 set: `founders_hall`, `vault_frost`, `labor_strike`,
    `sealed_archive`, `ark_engine`, `solar_flare` and `crop_blight`.
  - Batch 2: the other eighteen.

| Id | Chain | Scene |
| --- | --- | --- |
| `founders_hall` | The Founders' Vote | the Ark's old cargo hall; a crowd facing a small distant figure speaking from an upturned crate; a high window glowing with orange starlight |
| `vault_frost` | Cold Sleepers | rows of frosted sleep pods in blue dimness; one pod lit gold; a small figure seen from behind, holding a lamp |
| `labor_strike` | Labor Strike | a mining yard at dusk; idle machines; workers standing in a line, arms folded; a single floodlight |
| `sealed_archive` | The Sealed Order | a vault shelf; a sealed metal cylinder with an abstract circle sigil; a reading lamp |
| `ark_engine` | The Ark's Last Engine | the Ark's huge dormant drive cone seen from below; scaffolding; tiny figures for scale |
| `solar_flare` | Solar Flare | a colony grid under an orange sky; the star bulging with a flare; shield pylons raised |
| `crop_blight` | Crop Blight | terraced green fields; one patch turning grey; a farmer kneeling beside it |
| `dark_beacon` | The Dark Beacon | a ring-shaped beacon station, dark, against the stars; one flickering light; a small ship approaching |
| `unlit_toll` | Unlit Toll | an asymmetric salvage ship blocking a travel lane; orange-red running lights; a small colony freighter facing it |
| `meridian_hall` | Meridian's Claim | a symmetrical, formal hall with blue banners bearing a compass rose; a small distant figure at a lectern |
| `vael_light` | First Words | a dark sea of slow lights; a colonial organism glowing in patterns; a human silhouette with a lantern answering it |
| `vael_heard` | What the Vael Heard | a vast, calm Vael light-structure; far above, a faint unexplained arc of light among the stars |
| `mine_collapse` | Mine Collapse | a mine entrance breathing dust; rescue lights; figures carrying stretchers |
| `derelict_freighter` | Derelict Freighter | a broken cargo ship drifting, cargo pods scattered; a survey probe's beam across it |
| `ghost_signal` | Ghost Signal | a listening array at night; a single dish pointed up; a waveform-like line of light in the sky |
| `ice_comet` | Ice Comet Capture | a comet with a long tail passing close; tug ships with cables; the colony planet below |
| `debris_cascade` | Orbital Debris Cascade | the planet's edge with a ring of glittering debris; a damaged satellite |
| `founding_day` | Founding Day | a festival square; lanterns on strings; a crowd; the Ark's hull standing as a monument |
| `frontier_doctor` | The Frontier Doctor | a small clinic tent at the edge of a settlement; a doctor carrying a bag; morning light |
| `smugglers_market` | Smugglers' Market | a cramped space-station bazaar; hanging goods; orange-red lights; hooded figures |
| `refugee_slowboat` | Refugee Slowboat | an old, patched slowboat limping into orbit; small lights at its windows |
| `ancient_ruins` | Ancient Ruins Survey | alien geometric ruins half buried in sand; a survey drone; long shadows |
| `rogue_core` | The Rogue Core | a derelict ship's dark corridor; one server column glowing cyan; a cautious engineer |
| `stellar_nursery` | Stellar Nursery | a nebula with bright young stars; the silhouette of a small research outpost |
| `quiet_lane` | The Quiet Lane | a dead lane-marker beacon; drifting dust; a lone survey ship passing with its lights dimmed |

#### Portraits

- **Format:** one PNG per character and expression, 1024×1024, sRGB, with a transparent background
  (or a flat #00FF00 background with no shadow, which intake removes). The game draws the backing
  disc.
- **Framing:** a chest-up bust in three-quarter view, framed the same for everyone. The top of the
  head is about 12% below the top edge, and the shoulders run off the bottom edge.
- **Mirroring:** the game may mirror a portrait so characters face each other, so avoid details
  that only work one way round.
- **Expressions:** `<id>.png` is neutral and required. Optional: `<id>__warm.png`,
  `<id>__worried.png` and `<id>__stern.png`, with the same outfit, framing and light; only the
  expression and a small head tilt change. Make the neutral portrait first, and use it as the
  reference image for the expressions.
- **The cast** descends from many Earth cultures: vary features, skin tones and builds.

| Id | Character | Notes |
| --- | --- | --- |
| `archivist_sola` | Archivist Imre Sola | the advisor voice: dry, warm, scholarly, a little playful. Older; round glasses; a knitted scarf; a teal collar; ink-stained fingers |
| `steward_varga` | Steward Anneliese Varga | the elected leader: pragmatic, worried about food. Middle-aged; practical short hair; a gold civic badge; tired but steady eyes |
| `captain_brandt` | Captain Oduya Brandt | the first fleet captain: loyal, restless, bored of peace. Fit; close-cropped hair; a high teal uniform collar; a restless half-smile |
| `director_hale` | Director Kasimir Hale | head of the Meridian Directorate: charming, sincere in his way, hiding a secret. Polished; swept-back hair; a steel-blue collar with a compass-rose pin |
| `speaker_of_seven` | Speaker-of-Seven | the Vael envoy: NOT a face. An abstract spiral of seven glowing light-dots in magenta and violet, floating in soft haze. Warm: brighter, gold-tinged, opening. Worried: dim, flickering, contracting. Stern: sharp, bright magenta, tightly wound |
| `mother_rook` | Mother Rook | leader of the Unlit: bitter, clever, open to a deal. Older; head shaved on one side; an asymmetric salvaged shoulder plate; orange-red details; a sharp gaze |

**Fallback:** the parameterised flat generators of §8.3.

### 15.8 Brief: ship sprites

- **Format:** one PNG per ship, 512×512, sRGB, with a transparent background (or flat #00FF00, no
  shadow).
- **View:** seen **straight from above**, nose pointing up, centred. Battle replays rotate ships
  freely, so there is no perspective tilt (DESIGN_LOG 47).
- **Volume:** chunky diorama forms with painted shading, and the light baked in from the upper
  left.
- **Size:** the longest dimension is about 400 of the 512 canvas; the starbase about 460.
- **Colour:** the hull is light neutral grey or off-white, so the engine can tint it with the
  owner's colour. Only lights, windows and engine glow carry colour: gold #FFD37A or cyan #56CFE1.
- **Readability:** recognisable at 32 px, with no details smaller than 8 px at full size.
- **Nothing else:** no ground shadow, background, text or insignia.

**Faction styles:**
- **human:** a central spine with a ring
- **meridian:** symmetrical swept wings
- **vael:** organic, rounded lobes, no straight lines
- **unlit:** asymmetric salvage, mismatched parts

**Sizes read at a glance:** a corvette is small and nimble, a frigate balanced, a cruiser long
and heavy.

| Id | Ship |
| --- | --- |
| `hull_corvette_human`, `hull_frigate_human`, `hull_cruiser_human` | human style |
| `hull_corvette_meridian`, `hull_frigate_meridian`, `hull_cruiser_meridian` | Meridian style |
| `hull_corvette_vael`, `hull_frigate_vael`, `hull_cruiser_vael` | Vael style |
| `hull_corvette_unlit`, `hull_frigate_unlit`, `hull_cruiser_unlit` | Unlit style |
| `civ_survey` | a small probe with a sensor dish (human style) |
| `civ_construction` | a boxy tug with manipulator arms (human style) |
| `civ_colony` | a long hull with habitat rings (human style) |
| `starbase` | a ring station with docking arms (human style) |
| `slowboat` | the old generation ship: a very long hull, a huge shield disc at the front, habitat rings |

**Fallback:** code-drawn polygons.

### 15.9 Brief: title key art, logo and store art

**Title key art (kind `art`, batch 1):**
- `title.png`, 3840×2160, painted diorama.
- **Scene:** the Ember system at dawn, seen from a ridge on Aster.
  - The Ark's old hull stands landed as a monument.
  - Terraced lights of the settlement lie below.
  - A dark, ring-shaped beacon is faint in the sky.
  - The orange K-type star (#FFB870) is rising.
- Keep the left 40% calmer: the menu sits there.
- No text.
- **Optional:** `title_cast.png`, the same scene with three small figures on the ridge, seen from
  behind, looking at the dawn: the archivist (scarf, satchel), the steward (practical coat) and
  the captain (uniform jacket). Silhouettes only; no faces.

**Logo (kind `art`, batch 1):**
- The words "STARFIRE HEARTH" in a geometric sans (custom lettering welcome), with the hearth
  emblem: a gold four-point star inside a thin ring, with a small teal dot.
- Flat vector SVG, with the lettering converted to paths:
  - `logo_light_on_dark.svg`
  - `logo_dark_on_light.svg`
  - `logo_mono_white.svg`
  - `emblem_mark.svg` (the emblem alone, square)
- **Optional:** `logo_title.png`, 2048×1024, transparent: a richer painted or embossed version,
  for the title screen only. Its lettering matches the vector logo exactly.

**Store and platform art (kind `store`, batch 1):** PNG at these exact sizes, built from the key
art and logo in the painted-diorama style. It may feature the cast, consistent with their
portraits.

| Id | Size | Notes |
| --- | --- | --- |
| `app_icon` | 1024×1024 | the emblem on `bg.deep`; no text; readable at 48 px |
| `android_adaptive_fg` | 432×432 | the emblem only, inside the central 264×264 safe zone, transparent |
| `android_adaptive_bg` | 432×432 | a flat `bg.deep` or a subtle starfield |
| `play_feature` | 1024×500 | key art crop plus logo |
| `store_header` | 920×430 | key art plus logo |
| `store_capsule_main` | 1232×706 | key art plus logo |
| `store_capsule_small` | 462×174 | logo-dominant; readable when tiny |
| `store_capsule_vertical` | 748×896 | vertical crop plus logo |
| `library_capsule` | 600×900 | vertical, logo in the top third |
| `library_hero` | 3840×1240 | key art without logo; the subject in the centre 60% |
| `library_logo` | 1280×720 | the logo on transparent |

Also deliver the layered sources where they exist.

### 15.10 How to prompt a generator for these briefs

- **Image generators:** paste the brief, then add this line to each request:
  "Style: painted diorama, stylized chunky 3D forms like a miniature model, soft painterly
  brushwork, warm key light from the upper left, cool blue shadows, glowing windows, luminous
  painted sky, atmospheric haze, hopeful 1960s space-age illustration, calm science fiction".
  For negative prompts: "text, letters, logo, watermark, photorealistic, photograph, film grain,
  noise, lens flare, chrome, anime, cartoon". For standard, hopeful scenes, add "grimdark, horror"
  to keep the tone; leave them out for the dark variant.
- **Consistency:** keep one fixed style line and the same settings for a whole batch. For
  portraits, generate the neutral portrait first and use it as the character reference for the
  expressions.
- **Sound generators:** one sound per request: "single isolated sound effect, soft and musical,
  <description>, no music, no voice", with the duration. Generate 3–5 takes and send the best one
  under the id name.
- **Music generators:** one track per request: "instrumental visual novel soundtrack, piano and
  strings, <mood words from the table>, melodic, gentle, seamless loop, no vocals". If the tool
  cannot loop, keep 4 s of tail.

Everything that comes back goes through §15.2. Nothing is placed into the game by hand.
