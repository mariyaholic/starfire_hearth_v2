# M1 Report: First Light

**Status:** every M1 task is built. Scenario 1 plays from the title to the debrief on PC and on a
phone layout, with the first delivery of sound, music and art in it. Three balance gates still
fail, on three questions only you can answer (below). Work is stopped here until your verdict.

Claims are **Verified** only where the command that proved them is named. Commands run from the
repository root after `godot --headless --path . --import`.

## How to look at it

- **Web build (PC and phone):** every CI run on the pull request uploads a `web-build` artifact.
  Unzip it and serve the folder (`python3 -m http.server`), then open `http://localhost:8000`; a
  browser cannot run it from disk. Once this branch is merged, CI deploys it to
  `https://mariyaholic.github.io/starfire_hearth_v2/` (**Unverified** until then).
- **Desktop builds:** every CI run on `main` uploads `windows-build` and `linux-build`.
- **Add `?smoke=begin` to the web address** to start Scenario 1 and play one turn at once (the
  browser console says so); it is what the web smoke test uses.

Things to try:
- Title, Campaign, First Light, Begin. The archivist opens with the first report; close it and
  follow her steps. She rings the thing she is talking about.
- On the colony planner, choose a free slot and a district: the preview shows what it would
  change before you commit, and a refused order says why. Hover or tap any number for its
  breakdown; **Why did it change?** lists last turn's causes.
- Give a few orders, then End turn. The checklist lists what still has none. Events open after
  the report and must be answered.
- Research (three cards per branch), Ordinances (try the Festival), System (survey Brume with the
  probe), Objectives. The Market appears once you own a Market Exchange.
- Menu (top right, or Esc): save, load, Codex, settings, quit. Title: Load, Settings, Credits.
- On a phone: the tab bar names only the open tab; **More** holds the rest.

## What was built

| Brief task (§12, M1) | Where |
| --- | --- |
| Rules with breakdowns | `sim/rules/`: economy, production, population, stability, research, construction, governors, ordinances, ships, market, objectives, tutorial, events, effects, modifiers |
| Commands | `sim/commands/`: 22 player commands, each validated with a reason |
| Data and Scenario 1 | `data/`: 15 buildings, 37 techs, 5 ordinances, tiers, full Scenario 1 (objectives, tutorial, loss rules), 3 legacies |
| Story | `data/events/`: 16 chains, 36 steps; the event engine with a paced director |
| Bots and telemetry | `tools/bot/`, `tools/telemetry_report.gd`: four policies, every gate of §12 |
| App shell and flow | `ui/screens/app_root.tscn` and `ui/screens/flow/`: title, campaign, briefing, debrief, settings, load, credits |
| **Game screen** | `ui/screens/game/`: top bar, rail or tab bar, advisor with highlight, Undo, End Turn with checklist; colony planner, system, galaxy, research, ordinances, market and objectives views; event scene, turn report, Why?, menu |
| Audio | `app/audio.gd`, `app/sound_synth.gd`: buses, a fallback for every sound, music cues per screen |
| Saves | `app/save_service.gd`: auto-save each turn, checkpoints, manual saves, thumbnails, Load screen |
| Codex | `ui/codex/`, `data/codex/`: 22 pages with live numbers, breakdown links |
| Planets | `ui/map/planet_sphere.gdshader`: lit spheres |
| Asset intake | `tools/import_assets.py` (DESIGN_LOG 93): 131 ids from 9 delivered batches |
| Tools | the tour visits the whole app; `tools/web_smoke.mjs` plays a turn and matches the desktop's state hash |

## Gate results

| Check | Command | Result |
| --- | --- | --- |
| Data valid | `godot --headless --path . -s tools/validate_data.gd` | **Verified:** 20 tables, 328 records, 1,356 strings, 0 errors, 0 skipped checks |
| Tests | `godot --headless --path . -s tests/run_tests.gd` | **Verified:** 165 passed, 0 failed, 3,126 checks in 31 files, 40 s (unit, integration, golden, saves, boundary) |
| Game screen | `--filter game_screen` | **Verified:** 5 tests, 119 checks: a game played from its first report, orders from every view, events block End Turn, and every view and overlay passes the audit as a PC and a phone at 100% and 200% text |
| Explanation and layout audit | `xvfb-run -a -s "-screen 0 2560x1600x24" godot --rendering-driver opengl3 --path . -s tools/screenshot_tour.gd -- --out screens/` | **Verified:** 176 screenshots, 0 audit issues. 325 numbers carry an exemption with its reason (see "Known issues") |
| Balance telemetry | `tools/balance_loop.sh <dir> 1-20` (CI's balance job) | Below. Advisory in CI until you decide |
| Performance | the same runs | **Verified:** end-turn p95 42 ms on desktop (budget 300 ms). Phone: **Unverified** (no device) |
| Exports | `godot --headless --path . --export-release "Web" build/web/index.html` (also Windows and Linux) | **Verified:** [CI run 36599451008](https://github.com/mariyaholic/starfire_hearth_v2/actions/runs/36599451008) on commit `5ea653c`: all five jobs passed (the deploy job is skipped off `main`) |
| Web size | CI's "Web build size" step; `gzip -9` of each file | **Verified:** 48.2 MB as a compressed download when measured locally with the delivered assets in (48,201,796 bytes); the CI `web-build` artifact is 47.5 MB. Budget 150 MB. Music is 27.8 MB of it |
| Web smoke | `node tools/web_smoke.mjs --build build/web --out screens/web --expect-hash <hash>` | **Verified in CI:** the export job's smoke step passed on the three devices, and the browser's state hash after one turn matches the desktop's |
| Look and feel | Owner playtest on PC and a phone browser | Waiting for you |

### Balance gates (20 seeds per policy on Normal, plus balanced on Story)

| Gate | Result | Band |
| --- | --- | --- |
| Invariants | PASS: 0 problems in 100 runs, 8,987 turns | 0 |
| Performance | PASS: end-turn p95 42 ms | < 300 ms |
| Winnable, balanced on Normal | **FAIL:** 20 of 20 won | 60–90% |
| Winnable, random-legal | PASS: 0 of 20 | < 20% |
| Winnable, balanced on Story | PASS: 20 of 20 | 85–100% |
| Pacing | PASS: median win turn 74 | 56–84 |
| No dead turns | PASS: median 1% | < 25% |
| No hoarding | **FAIL:** 80 of 80 runs (longest streaks: food 84, metals 80, influence 51, energy 33) | ≤ 20% of runs |
| Everything matters | **FAIL:** Foundry 0%, Research Institute 3% (every other building and tech passes) | buildings ≥ 25%, techs ≥ 15% |

## Screenshots

From real renders: the tour under xvfb with OpenGL 3. All 176 are in the `screens` artifact of
each CI run.

| | |
| --- | --- |
| ![Title](m1/pc_title.jpg) The title, with the delivered key art and logo | ![Colony](m1/pc_colony.jpg) The colony planner on a game 24 turns in |
| ![Slot](m1/pc_slot.jpg) A slot chosen: the preview (+10.4 on the hex) and each district's cost | ![System](m1/pc_system.jpg) The system view: Brume chosen, its trait and what can be ordered |
| ![Research](m1/pc_research.jpg) Research: three branches, cards with their cost breakdowns | ![Market](m1/pc_market.jpg) The market, on a finished game |
| ![Event](m1/pc_event.jpg) An event: the painted scene, the speaker, three choices with costs and effects | ![Report](m1/pc_report.jpg) The turn report |
| ![Why](m1/pc_why.jpg) Why? for a colony | ![Settings](m1/pc_settings.jpg) Settings |
| ![Phone colony](m1/phone_colony.jpg) Phone: the advisor is one strip, the tab bar names the open tab | ![Phone event](m1/phone_event.jpg) Phone: an event |
| ![PC 200%](m1/pc_text200_colony.jpg) PC at 200% text | ![Phone 200%](m1/phone_text200_research.jpg) Phone at 200% text: little room, and it still reads |

What I checked in the screenshots:
- Text is never cut off, overlapping or broken mid-word (also audited).
- Painted scenes are cropped around their centre rather than stretched; portraits sit on their
  discs; the hex grid keeps its tiles apart and a preview never covers its neighbours.
- The phone's tab bar, advisor strip and End turn fit at 200% text.
- Refused orders are disabled and say why, in the negative colour and never by colour alone.

## Known issues

- **Three balance gates fail** (questions 1 to 3). They are advisory in CI.
- **325 numbers in the tour are exempt from "every number is an Explainable",** each with its
  reason (listed in the tour's `audit.json`). The largest classes: the text size setting (102, in
  the showcase), objective wording that states its targets (49), effect lines that state a promise
  (21), a colony's settlers and jobs counted from its districts (48), settings shown as a
  percentage (16), the Codex quoting the rules (16), and about 30 progress counts, estimates,
  build times and turns left. The settlers and jobs counts could become breakdowns of the districts
  and buildings behind them; say if you want that stricter.
- **Not tested on a real phone,** nor the Windows build. The phone layouts are audited in the
  simulator at 2400x1080 and 440 dpi.
- **A colony cannot be renamed** in the UI yet (the command exists). **The galaxy is a static map**
  in Scenario 1: every lane is locked, with the reason shown.
- **A manual save holds the game as the last turn left it,** not this turn's unspent orders (the
  menu says so).
- **End Turn lists idle ships and empty research branches on most early turns.** It is meant to
  nag, and it can be waved through.
- **Headless and tour runs sometimes print "resources still in use at exit"** for a music track
  that was playing (DESIGN_LOG 24). It does not affect results.
- **Assets still on their code fallbacks:** 18 story scenes (batch 2), the 18 portrait
  expressions, `title_cast` and `logo_title`. `logo_dark_on_light` uses two shades outside the
  palette; the game does not use that file.

## Deviations from the brief

Each is in `docs/DESIGN_LOG.md`.

- The asset intake is a Python tool, not a Godot script (93): Godot cannot encode Ogg Vorbis.
- Settings, Load and Credits are routes with a `back` argument, shared by the title and the game
  menu (94); the galaxy has no travel yet (Scenario 1 locks it).
- The game screen has no side context panel: each view carries its own (94).
- Against the M1 plan: the Foundry and the Research Institute do not earn their place yet
  (question 3).

## Decisions you can overrule

The reasons are in `docs/DESIGN_LOG.md` (51–94). The ones that shape play most:
- A resource never goes negative; an energy shortfall costs stability (54).
- One build at a time per colony, paid when queued, refunded in full when cancelled (57).
- Tutorial progress is saved with the game, as acknowledged orders (62).
- "Winnable" means every required objective within 1.5 times the expected duration (63).
- The balance pass: cheaper early techs, a leaner start, a Market Exchange paid partly in metals
  (92).
- Music is encoded at Ogg quality 6, about 70 kbps on average; the web build carries all 28 tracks
  (93).
- End Turn opens an unanswered event instead of ending the turn (94).

## Questions for you

1. **Normal is too easy:** the balanced bot wins 20 of 20. I measured my own proposal: **events
   at 125% or even 150% severity on Normal change nothing** (still 20 of 20, median win turn 74),
   so severity is not the lever. What makes it "trivial" is the deadline in my definition of
   winnable (DESIGN_LOG 63): a win counts within 1.5 times the expected 70 turns, and the balanced
   bot's slowest of 20 runs is turn 96. Its win turns are 69 to 80 for 17 runs, then 85, 95 and
   96. Counting a win within 1.25 times the expected duration (turn 87) gives 18 of 20 (90%, the
   edge of the band); with events at 125% as well it gives 16 of 20 (80%, mid-band). I recommend
   both: a tighter deadline (a competent player finishes in about 70 turns, not 100) and Normal
   events at 125%. The scenario itself has no way to lose for a competent player except autonomy,
   which is a design fact you may want to change instead (a real deadline or a harsher status
   chain).
2. **Hoarding.** The gate counts the lopsided bots too, and reads a stock saved for a lump
   purchase (a Colony Ship, a 40-metal building) as hoarding. I measured it per policy over the
   same 20 seeds: **even the balanced bot on Normal hoards in 20 of 20 runs**, nearly always
   metals (the longest streak above ten turns of income has a median of 38 turns), because metals
   have almost no sink in Scenario 1: two Colony Ships and a handful of buildings. So applying the
   gate to the balanced bot only would not make it pass. Options: (a) real sinks for metals, for
   example district tier upgrades paid partly in metals; (b) apply the gate to the balanced bot
   only, which changes the gate and not the game; (c) keep the gate and let the market (which buys
   metals) open much earlier. I recommend (a), and (b) as well for the gate's definition, since
   the economy and turtle bots are lopsided on purpose.
3. **The Foundry and the Research Institute.** Metals have few uses in Scenario 1 and +20%
   research cannot beat a research district. Options: move Foundry Automation out of Scenario 1's
   technology pool (metals matter from M2's fleets); give the Institute a flat research bonus as
   well. I recommend both.
4. **Merge and deploy?** Say so and I mark the pull request ready, merge it, and CI deploys the
   web build to GitHub Pages for your playtest. I have not, because it publishes the build.
5. **The delivered assets:** the story scenes' licence says only "CC0" (the other image batches
   name ChatGPT Plus). Please confirm they were made on the same plan. The public GitHub Release
   holding the 1.8 GB zip can be deleted now.
