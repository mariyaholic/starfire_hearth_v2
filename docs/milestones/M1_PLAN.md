# M1 Plan: First Light

## Goal

Scenario 1, First Light, playable from the title screen to the debrief, on PC and on a phone
browser. The player builds up the Ember colonies, researches, handles stability, uses governors and
ordinances, founds colonies and an outpost, and plays the Scenario 1 story. Every number explains
itself. Bots play the scenario and the balance gates of §12 are real.

Outsourced assets are on hold: every scene, portrait, sound and music cue uses its code
placeholder, addressed by its §15 id.

Gate: the M1–M3 gate of `docs/BUILD_PROMPT.md` §12.

**Status:** tasks 1–8 are built, except the tuning half of task 8: three balance gates still
fail. Tasks 9–12 remain: the screens, audio, tooling and the report. The details and the order
to resume in are in `docs/BUILD_PROMPT.md`, "M1 progress and where to resume". Decisions made
while building are DESIGN_LOG 66–84.

## Decisions taken to start (each goes into DESIGN_LOG; the Owner may overrule)

| # | Decision | Reason |
| --- | --- | --- |
| 51 | Rules read content through a static `Content.db()`, loaded once from `data/`; tests can swap it | Keeps rule and command signatures unchanged; content is constant during a game, so determinism holds |
| 52 | State schema 2, with the migration `v1_to_v2` filling defaults for every new field | Exercises the migration chain; the M0 fixture still loads |
| 53 | Modifiers stack additively: output = base × (1 + Σ bonuses) | Each bonus is one readable breakdown line on the same base |
| 54 | A resource never goes negative. An energy shortfall clamps at 0 and costs −10 stability on every colony while it lasts; Industry uses only the minerals available and slows down proportionally | The brief allows negatives only through famine; both penalties show in breakdowns and are warned two turns ahead |
| 55 | Every capital produces 2.00 research in each branch | Research cards (tutorial T3) need progress before the first Research district |
| 56 | Buildings: 4 per colony, +1 at City. The Ark Hull and the Archive of Sol are landmarks: they take no hex slot and do not count | Gives the City stage's "+1 building slot" a meaning, and gives story buildings a home |
| 57 | Construction: one build at a time per colony, in a queue. The cost is paid when an item is queued, and cancelling refunds it in full. Demolishing is instant and refunds nothing | A visible, undoable queue; no hidden reservations |
| 58 | A Research district's branch is chosen when it is placed | §5.4 says "in the branch chosen for that district" |
| 59 | Planets start unsurveyed, apart from the capital's. A survey takes 2 turns with a Survey Probe and reveals traits and slots. Colonising and outposts need a survey | Makes tutorial beat T8, "Survey Brume", a real action |
| 60 | Outposts: an asteroid belt makes 6.00 minerals; a gas giant makes 6.00 energy or 3.00 research in each branch (the player picks). Upkeep is 0.50 energy. Building one takes the Construction Ship 4 turns (Orbital Construction halves it) and 50 influence | The brief gives outposts a role but no numbers |
| 61 | Founding a dome world needs Habitat Domes. The founding places its Habitat Dome and charges the dome's cost | "Required to settle one" otherwise makes a chicken-and-egg problem |
| 62 | Tutorial progress lives in state flags, set by a no-effect `acknowledge` command | Saved with the game, deterministic, and ignored by the rules |
| 63 | "Winnable" in telemetry means every required objective is done within 1.5× the expected duration | Without a deadline, a competent bot wins every run eventually, and the 60–90% band would be meaningless |
| 64 | "Everything matters" covers what the scenario teaches (its `teaches` list), not the whole tech tree | Military techs and war buildings have no use in Scenario 1 |
| 65 | The Research Institute unlocks with Research Network, a new tier II Society tech (37 techs). Tier III: Habitation with Arcology Design; the other districts with Foundry Automation's "Industrial Megaplex" effect | The two open questions of §10.3 and §10.4, with the defaults from the build prompt |

## Tasks

1. **Data.**
   - Buildings (15), techs (37), ordinances (5), district tiers, three legacies, the governance
     choices.
   - The full Scenario 1: objectives, tutorial beats, scripted events, loss rules and `teaches`.
   - `data/asset_manifest.json`: every §15 id with its kind and status.
   - The schema grows to match. The reachability check becomes real.
2. **State.** Schema 2 adds:
   - research state per branch
   - build queues
   - governors
   - active ordinances
   - surveyed planets
   - timed modifiers
   - pending and scheduled events
   - the event log
   - objective progress
   - famine and autonomy counters

   Migration `v1_to_v2`, a v2 fixture save, and the invariants extended.
3. **Rules** (`sim/rules/`, each with a Breakdown for every derived value and unit tests against the
   numbers of §5):
   - `modifiers.gd`: gathers effects from techs, traits, buildings, ordinances, the origin, timed
     modifiers and the stability band
   - `economy.gd`: jobs filled by priority, output with adjacency, upkeep, industry input, market
     (off in S1), caps, overflow and forecasts
   - `population.gd`: housing, growth, homelessness, famine
   - `stability.gd`: every §5.4 source, stages, the output bands, Unrest and autonomy
   - `research.gd`: hands, the seeded draw, costs, catch-up, rerolls, story techs
   - `construction.gd`: queues, tiers, adjacency previews, demolition
   - `governor.gd`: focus, budget, veto, planned build with a reason
   - `ordinances.gd`: slots, activation, upkeep, ticks
   - `influence.gd`: income and costs
   - `ships.gd`: civilian ships only in M1 (build, survey, outposts, colony ships)
   - `objectives.gd`: required and optional objectives, victory, loss, legacies
4. **Turn phases.** Fill phases 2, 3, 4, 5, 8, 9, 12, 13 and 14 in the §9.4 order. Phases 6, 7,
   10 and 11 stay empty until M2 and M3.
5. **Commands**, each with validation reasons and tests:
   - districts: place, upgrade, demolish
   - buildings: build
   - the build queue: cancel an item, move an item up
   - research: pick a card, reroll
   - ordinances: activate, cancel
   - governors: set the focus, set the budget, veto a build
   - ships: build, survey, build an outpost, found a colony
   - events: choose an option
   - the tutorial: acknowledge a step
   - already built: set job priority, rename a colony
6. **Events engine** (`sim/rules/events.gd`):
   - triggers from a closed set of conditions, each with a readable reason
   - scripted steps, and the director for emergent events (at most 1 every 4–6 turns, seeded,
     never in the turn of a scripted event)
   - weights, cooldowns and flags
   - choices with costs and effects
   - "Uncertain" choices, with outcome ranges
   - chains and delays
   - the speaking character (a portrait id and expression) and a music cue
   - the event log
7. **Scenario 1 story.**
   - Scripted chains: The Founders' Vote, Cold Sleepers, Labor Strike, The Sealed Order steps 1–2,
     The Ark's Last Engine.
   - Emergent chains usable in one system: Solar Flare, Crop Blight, Mine Collapse, Founding Day,
     The Frontier Doctor, Refugee Slowboat, Ice Comet Capture, Orbital Debris Cascade.
   - Every body is 60–140 words, written to §10.6's standard, with advisor hints for each
     mechanic.
8. **Bots and telemetry.**
   - Policies: balanced, economy, turtle, random-legal.
   - The balanced policy also drives the governor's choices through a shared advisor.
   - Telemetry per turn as in §13.7, and all five balance gates real.
   - Tuning passes until the gates hold, or an honest report of where they don't.
9. **Screens**, PC and phone, 100% and 200% text:
   - title
   - campaign select
   - briefing and debrief (with the legacy pick)
   - galaxy view (Ember plus six fogged neighbours)
   - system view
   - colony planner (adjacency ghost, deltas, queue, jobs, governor)
   - research (cards and the tree)
   - the event scene (card layout, with the speaker's portrait)
   - turn report
   - Why?
   - advisor tutorial
   - Codex (the Scenario 1 subset, generated from data plus prose)
   - settings
   - save and load (auto-saves, checkpoints, manual saves, thumbnails)
   - the End Turn checklist and alerts

   Placeholders for scenes, portraits and music. The planet renderer upgraded to lit spheres. The
   showcase becomes a debug entry.
10. **Audio.** Buses for UI, effects and music, with sliders and mute. Synthesised placeholder
    blips on every §15.4 id. Music cues with crossfades; each cue is silent until its track
    exists.
11. **Tooling.**
    - The screenshot tour visits every screen from fixture saves.
    - The id audit covers all of them.
    - The web smoke test also starts a new game.
    - CI runs the full telemetry gate set: 20 seeds × 4 policies.
12. **Report.** `docs/milestones/M1_REPORT.md`, then stop for the Owner's playtest.

## Files expected to touch

- `sim/**`, especially `sim/rules/*`, `sim/commands/*`, `sim/core/*`, `sim/save/migrations/*`,
  `sim/data/*`
- `data/**`, `strings/en.csv`
- `app/*`
- `ui/screens/*` (new), `ui/components/*`, `ui/map/*`
- `tests/**`, `tools/bot/*`, `tools/telemetry_report.gd`, `tools/screenshot_tour.gd`,
  `tools/web_smoke.mjs`
- `.github/workflows/ci.yml`
- `docs/DESIGN_LOG.md`, `docs/milestones/M1_*`, `CHANGELOG.md`, `README.md`

## Risks

| Risk | Mitigation |
| --- | --- |
| Scope: M1 is most of the game's machinery | Build in the order of the task list, with tests green at every commit. The screens come after the rules they show, and the bot plays each system as soon as it exists |
| The balance gates may not land in their bands on the first tuning passes | Telemetry per turn, run locally in about a minute; tune data first; report honestly if a band is missed |
| Story writing quality | Every body is written to the §10.6 standard and read back in the tour screenshots |
| The golden hashes change with every rule | Re-baselined through `tools/regen_golden.gd --reason`, logged in CHANGELOG each time |
| Phone layouts for dense screens (planner, research) | Compact layouts first, checked at 200% text by the audit and by eye |
| Web build size with fonts, data and placeholders | Well under the 150 MB budget; checked in CI |

## How each gate item is verified

| Gate item | Command / evidence |
| --- | --- |
| Tests and data | `godot --headless --path . -s tests/run_tests.gd`, `... -s tools/validate_data.gd` |
| Explanation audit | the screenshot tour (every screen at both sizes and text scales), the id audit, and the web smoke test |
| Balance telemetry | `tools/bot_run.gd` with 20 seeds per policy on `s1`, then `tools/telemetry_report.gd` |
| Performance | the telemetry report's end-turn p95 (budget 300 ms desktop) |
| CI green, deployed | the GitHub Actions run on the pull request and on `main` |
| Owner playtest | the Owner, on PC and a phone browser |
