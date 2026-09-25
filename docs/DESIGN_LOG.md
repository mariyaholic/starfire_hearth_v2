# Design log

Decisions the brief left open, each with a one-line reason. Newest last. Anything here can be
overruled by the Owner; overruled entries are struck through, not deleted.

## M0

1. **Godot 4.7.2-stable is pinned.** It was the latest stable 4.x release on 2026-09-24 (4.8 is
   not out); the brief asks for the latest stable, 4.3 or newer.
2. **Fonts: IBM Plex Sans 1.1.0 and IBM Plex Mono 2.5.0**, Regular, Medium and SemiBold of each.
   These are the current official releases; the three weights cover the type scale of §8.5.
3. **Licence is "All rights reserved"** until the Owner picks one, as the brief instructs.
4. **Fixed-point rounding floors toward negative infinity** (`Fx.div_floor`, `Fx.mul_bp`). One
   rule everywhere makes breakdown lines sum exactly to their totals.
5. **Units.** Resources, rates and combat stats are centi-units; percentages are basis points;
   lane lengths are centi-light-years; counts (pops, turns, stability and opinion points) are
   plain integers. Everything in state is an integer.
6. **RNG seeding.** The four inputs (seed, turn, stream, salt) are folded with MurmurHash3's
   `fmix32` and `mul32` into one 32-bit key; splitmix32 (golden-ratio increment, fmix32 output)
   expands it into the four xoshiro128** words. Streams are stateless, so nothing about RNG is
   saved; `rng_meta` in a save only names the algorithm. Test vectors come from an independent
   arbitrary-precision reference implementation and include the published xoshiro128** vector for
   state {1, 2, 3, 4}.
7. **`RngStream.range(lo, hi)` is inclusive at both ends** and uses rejection sampling, so it is
   unbiased. String salts use FNV-1a (`Rng.salt_of`), because the engine's `hash()` may change
   between versions.
8. **Canonical JSON is a small custom writer** (sorted keys, no whitespace, integers only). A float
   anywhere in state is an error, so the state hash doubles as the "every value is an integer"
   invariant.
9. **Simulation code iterates collections in sorted-id order** (`DictIO.sorted_keys`), and ids are
   zero-padded (`col_0001`), so a loaded game and a live game visit entities in the same order.
10. **Scripts must be imported before headless runs.** Godot registers `class_name` types during
    the editor's import scan, so CI and the README run `godot --headless --import` first.
11. **The string table is loaded at run time** (`StringTable` into a Godot `Translation`), and the
    CSV's import is set to "keep". Headless tests and tools need the same strings without an editor
    import step, and there is one source of truth.
12. **The Theme is built at run time from the tokens** (`ThemeBuilder`), not kept as a hand-edited
    `theme.tres`. Text scale, the compact layout and high contrast all change sizes and colours;
    a stored resource would drift from `tokens.gd`. *Deviation from the §9.2 file list.*
13. **Icons are rasterised at run time at the exact pixel size** (SVG import set to "keep"), so
    they stay crisp at 2.75x on phones and can be tinted.
14. **UI scale.** PC: `max(1, window height / 1080)` times the user's multiplier, so small windows
    keep readable text. Touch: one logical pixel is one dp (density times the multiplier). The
    compact (phone) layout applies below 1280x700 logical. The §7 reference phone (2400x1080, 6")
    is 440 dpi, which is about 873x393 dp; the tour renders it that way, with a 32 dp simulated
    camera cut-out on the left and a 12 dp gesture bar.
15. **Two autoloads beyond the four in §9.2:** `Layout` (scale, layout class, theme) and `Overlay`
    (breakdown tooltips, toasts, modals, drawers, bottom sheets). One owner each for responsive
    state and for stacking and dismissing floating UI.
16. **The overlay layer carries the theme itself.** Controls under a `CanvasLayer` do not inherit
    the window's theme in Godot 4.7; without this every overlay used engine defaults.
17. **The web export is single-threaded** (no SharedArrayBuffer), so it runs on GitHub Pages without
    cross-origin-isolation headers.
18. **No 2D MSAA.** The Compatibility renderer does not support it; edges use anti-aliased lines and
    StyleBoxFlat anti-aliasing instead.
19. **Icons beside text grow with the text scale** (`SfIcon.scales_with_text`); the icon sheet keeps
    exact sizes.
20. **Breakdowns on phones stack centred**, a nested one cascading over its parent like a
    navigation stack; on PC a nested breakdown opens beside its parent. Both scroll when taller than
    the screen.
21. **The top bar's resources sit in a swipeable strip** so the bar can never widen the screen (it
    did at 200% text on a phone); on phones the "More" drawer lists every resource, the Noise
    meter and the date.
22. **The test runner uses Godot's `Logger`** (4.5+) to turn engine and script errors raised during
    a test into failures of that test.
23. **`-s` tool scripts load UI classes at run time.** A tool that names UI classes directly hangs
    while compiling, because those classes refer to autoloads that do not exist yet.
24. **Known engine quirk:** headless runs print "resources still in use at exit" when a script uses
    typed arrays of a class and its subclasses. It is harmless (no state leaks; exit codes are
    unaffected) and is left visible rather than filtered.
25. **The player's polity is named "The Ember Compact".** The brief names the origin (Generation
    Ark) but not the colony's government.
26. **Planner colours:** districts take the colour of what they produce; Habitation uses the player's
    teal, because energy yellow and hearth gold are too close to tell apart as hex fills.
27. **Effect keys added for planet traits:** `slots_add` and `ship_cost_bp`; traits also get the
    fields `domes_only` and `blocked_slots`.
28. **District tiers, buildings, techs, the Research Institute unlock and tier III districts are
    deferred to M1**, where the rules that use them are built. M1's plan will put the open choices
    (§10.3 note, §10.4 note) to the Owner.
29. **Balance gates report SKIP for stub scenarios.** Invariants, determinism and end-turn time are
    real gates from M0; hoarding, reach, win rate, pacing and dead turns start with M1's playable
    scenario.
30. **Showcase numbers are sample content** built as real `Breakdown` and `ReportItem` objects in
    `ui/screens/showcase/showcase_data.gd`, following Aster's start in §10.2. The rules that compute
    them arrive in M1.
31. **Icon names live in the string table** as `icon.<id>`; the validator requires one per icon file.
32. **The id audit gained rules:** `broken_word` (a wrapping label narrower than one of its words)
    and overlap checks for hex cells; clipping along a scroll container's scroll axis is scrolling,
    not a defect.
33. **Numeric-label exemptions** use the node meta `audit_numeric_ok` with a reason, listed in
    `audit.json`. Only the text-size setting buttons use it.
34. **The save envelope's `version` is the state schema version** (`GameState.SCHEMA_VERSION`).
35. **Empty content folders are optional at run time.** Folders holding only a placeholder are not
    packed into exports; the validator still requires them in the repository.
36. **On the web, phones and tablets are detected from the browser:** Android or iOS in the user
    agent, or a finger as the main pointer (`pointer: coarse`), which catches iPadOS Safari
    reporting itself as macOS. The web smoke test found an iPad getting the PC layout with
    24-pixel targets.
37. **The web size budget (§9.11, under 40 MB) is measured as the compressed download.** The
    official 4.7.2 web engine alone is 39.5 MB on disk (10.1 MB compressed), so an on-disk budget
    cannot hold past M0 with the official templates §0.2 asks for. *Interpretation of §9.11; the
    M0 report asks the Owner.*
38. **`tools/web_smoke.mjs` is the one tool not written in GDScript.** Only a browser can check the
    exported web build, so it drives headless Chromium through Playwright (Node) as a PC, an
    Android phone and an iPad.
39. **CI runs on pushes to `main` and on pull requests**, not on every branch push, so a pull
    request's branch is not built twice; large artifacts are kept 7 days. A private repository's
    free plan has 2,000 Actions minutes a month and 500 MB of artifact storage.
40. **Breakdown panels widen with the text scale** (360 logical px times the scale, capped by the
    screen), so at 200% a line's source does not wrap to a word per line beside its value.
41. **At M0 the screenshot tour visits the showcase's states**, since no §7 screen exists yet; from
    M1 it loads fixture saves and visits each screen as it is built (§9.9).

## After M0 (Owner feedback)

42. **Display renames and units (Owner request):** Alloys show as Metals, Edicts as Ordinances,
    pops as settlers (one pop is 1,000); Food in kt, Energy in GW, Minerals in Mt, Metals in kt.
    Only strings change: ids, data keys and saves keep `alloys`, `edict` and pops, so nothing
    migrates. Units come from `unit_key` in `resources.json`; top-bar chips stay unitless for width.
43. **Outsourced art, sound, music and VFX are allowed** (Owner request), through the intake
    contract of `docs/BUILD_PROMPT.md` §15. Every asset keeps a code fallback, so a missing
    delivery never blocks a build. *Deviation from the original §8.1 "every asset generated by
    code".*
44. **`docs/BUILD_PROMPT.md` is the rewritten build brief** (Owner request), replacing the original
    prompt; it records the as-built state and the remaining plan.
45. **Art direction: painted diorama** (Owner, a mix of the "cozy diorama" and "painterly space
    age" options): a flat interface over a painted world, sharing one palette. Rendered art may use
    any shades of the key colours and is checked by eye and a dominant-hue report rather than exact
    hex; SVG stays for icons and the logo. The flat outsourced art read as too simple, and the
    Owner wants 2.5D depth. This replaces the flat-only asset rules under entry 43.
46. **Visual-novel soundtrack** (Owner): a main theme, era tracks, a theme per named character,
    mood pieces and endings. Event steps name a theme or mood that crossfades in, and music moves
    from M4 to M1. UI sounds are tuned to D major pentatonic so they sit inside the score.
47. **Ship sprites are drawn straight from above,** with light baked in from the upper left.
    Battle replays rotate ships, and a tilted three-quarter view looks wrong when turned.
48. **Portraits have a neutral base and optional warm, worried and stern expressions;** an event
    step picks one. Generators keep a character consistent when the neutral one is the reference.
49. **The web build budget is 150 MB** as the compressed download (Owner), so the soundtrack and
    the painted art ship inside the web build.
50. **Outsourced assets are on hold** (Owner, before M1): M1 onward builds against the code
    placeholders, addressing every asset by its §15 id through `data/asset_manifest.json`, so
    delivered files drop in later. The intake tool waits for the first batch.

## M1

51. **Rules read content through `Content.db()`**, a static accessor loaded once from `data/`;
    tests can swap it. Rule and command signatures stay unchanged, and content is constant during
    a game, so determinism holds.
52. **State schema 2**, with the migration `v1_to_v2` filling defaults for every new field, so the
    M0 fixture save still loads.
53. **Modifiers stack additively:** output = base × (1 + the sum of bonuses), so each bonus is one
    readable breakdown line on the same base.
54. **A resource never goes negative.** An energy shortfall clamps at 0 and costs −10 stability on
    every colony while it lasts; Industry uses only the minerals available and slows
    proportionally. Both show in breakdowns and are warned two turns ahead.
55. **Every capital produces 2.00 research in each branch,** so research cards (tutorial T3) move
    before the first Research district.
56. **Buildings: 4 per colony, +1 at City.** The Ark Hull and the Archive of Sol are landmarks that
    take no hex slot and do not count, which gives the City stage's "+1 building slot" a meaning
    and story buildings a home.
57. **Construction is one build at a time per colony, in a queue.** The cost is paid when an item
    is queued, and cancelling refunds it in full; demolishing is instant and refunds nothing.
58. **A Research district's branch is chosen when it is placed** (§5.4).
59. **Planets start unsurveyed** apart from the capital's. A Survey Probe takes 2 turns to reveal
    traits and slots; colonising and outposts need a survey. This makes tutorial beat T8 an
    action.
60. **Outposts:** an asteroid belt makes 6.00 minerals; a gas giant 6.00 energy or 3.00 research in
    each branch (the player picks). Upkeep is 0.50 energy. Building one takes the Construction
    Ship 4 turns (Orbital Construction halves it) and 50 influence.
61. **Founding a dome world needs Habitat Domes;** the founding places its Habitat Dome and charges
    the dome's cost. This avoids a chicken-and-egg problem.
62. **Tutorial progress lives in state flags,** set by a no-effect `acknowledge` command: saved,
    deterministic, and ignored by the rules.
63. **"Winnable" in telemetry means every required objective is done within 1.5× the expected
    duration;** without a deadline a competent bot always wins eventually.
64. **"Everything matters" covers what the scenario teaches** (its `teaches` list), not the whole
    tech tree; military techs and war buildings have no use in Scenario 1.
65. **The Research Institute unlocks with Research Network,** a new tier II Society tech (37
    techs). Tier III: Habitation with Arcology Design; the other districts with Foundry
    Automation's "Industrial Megaplex" effect. These settle the two open questions of §10.3 and
    §10.4 with the build prompt's defaults.
66. **Cinder is small, not tiny.** A tiny dome world has 6 slots and its Habitat Dome takes one,
    so it could never hold the 6 districts a developed colony needs. A small dome world has 8.
    Brume gets one blocked slot, as §5.4 asks of every planet.
67. **Where each bonus applies** (refines 53). Tier, adjacency and district traits raise that
    district's own job output. Resource, output and research bonuses raise the colony's whole
    output of that resource, flat building output included. Upkeep, what settlers eat and
    industry's mineral input are flat lines applied after both (a new `flat` breakdown line
    kind), so no bonus ever scales a cost. Within a level, percentages add up.
68. **Inside a job group, the most productive district fills first,** then the lowest slot, so a
    new Research district next to Energy districts is never left idle behind an older one.
69. **Hex layout:** slot 0 is the centre, rings fill in order, and a partly used ring spreads its
    slots evenly around the ring. Adjacency is the six axial neighbours. The planner draws the
    same coordinates, so what looks adjacent is what counts.
70. **Research progress belongs to the branch** and carries over. Switching cards loses nothing.
    When a tech completes, the two unpicked cards stay and one new card is drawn; a reroll
    keeps the picked card and story cards.
71. **A governor's budget is a share of the minerals income** (default 50%), not of the stock.
    Revised by 80.
72. **Outpost discounts stop at −75%.** Colonial Administration and Frontier Charter together would
    otherwise make outposts free; the breakdown notes the floor when it applies.
73. **Stability is recomputed every turn from its sources,** with no drift, so its breakdown is the
    whole story. A colony at 5 or below counts down five warned turns before declaring autonomy.
74. **Homeless settlers keep growing at half speed** with no cap (§5.4), so a housing shortfall
    shows up in stability rather than silently stopping growth.
75. **Radio Silence is locked in Scenario 1** (the scenario's `locked_ordinances`): Noise arrives in
    Scenario 2.
76. **Civilian ship tasks:** a survey takes 2 turns, an outpost 4 (Orbital Construction halves
    it), and a colony is founded at the end of the turn the landing is ordered. In M1 a ship
    works only inside its own system.
77. **A colony ship's hull becomes the first shelter,** free: a Habitation district on an open world,
    the Habitat Dome on a dome world (revises 61, which charged for the dome). A new colony
    otherwise starts with two homeless, jobless thousands and falls below the stability
    objective at once.
78. **The market is in M1** (brought forward from M3): a Market Exchange (Colonial Administration)
    opens it at §5.3's fixed rates, in lots of 10.00, and every trade shows its rate. Scenario 1
    has few sinks for energy and food otherwise. Dynamic prices and trade deals stay in M3.
79. **A scenario's tech pool** can exclude military techs and name techs that are always offered
    once their prerequisites are met, like story techs. Scenario 1 always offers Habitat Domes,
    because its objectives need a dome world and a seeded draw could hide the card for many
    turns.
80. **Governors pay from a purse.** The production phase sets aside each governor's share of the
    minerals income into its colony's purse, shown as a line of the minerals breakdown; the
    governor pays a build's minerals from it, and turning the governor off returns it. With a
    shared stock the player's own orders (phase 1) always spent the minerals before the governor
    (phase 2) could, so governors silently never built.
81. **Rushing a build:** pay energy to take one turn off the build in progress, once a turn,
    never finishing it before the end of the turn. The cost is the item's price per turn of
    work, valued at the market's buying rates. Construction is one item at a time, so minerals
    outrun build slots while energy has few uses in Scenario 1; rushing trades one for the
    other.
82. **Telemetry measures gross income** as production before the flat lines (upkeep,
    consumption, inputs). The hoarding gate leaves out random-legal runs, which never manage
    their stocks by design. While M1 is tuned, CI prints every balance gate but only
    invariants, determinism and performance fail the build.
83. **The stability objective counts turns with two or more colonies:** "every colony at 40 or
    more for 10 turns in a row" would otherwise complete in the first ten turns, before the
    player has learned anything.
84. **Event titles carry no placeholders** because they name modifiers in breakdowns; bodies are
    checked by the validator for §10.6's 60–140 words. A string argument ending in `_c` is an
    amount in centi-units that the string layer shows as a short decimal.
85. **The app offers only screens that exist.** The title lists a menu entry once its screen is
    routed by the `AppRoot` (Load, Codex and Settings arrive with their tasks), so no button
    leads nowhere. Until the game screen is built, the game route shows a stand-in that names
    the game Begin started. The showcase is a debug-build entry; release exports leave it out.
86. **Campaign progress** (difficulty, wins, legacy picks) lives in `CampaignProgress`, owned by
    the `AppRoot`; it is written to `user://campaign.json` when the save rings land. A win counts
    as soon as the debrief opens, so leaving before picking a legacy keeps it; the legacy is
    recorded on Continue, and winning a scenario again lets the player pick a different one.
87. **Difficulty is picked on the campaign screen** (the three presets of §5.13, each with its
    description), shown again on the briefing, and passed to the scenario loader when Begin
    starts the game. The per-value sliders of §5.13 wait for the settings screen.
88. **Audio before assets:** the buses are made at start-up, so no bus layout file is needed.
    Until a sound is delivered it plays a blip synthesised from a recipe (22,050 Hz mono,
    rendered once and cached); the ambient ship hum is a bed, not a blip, so it stays silent
    until delivered, like music. Music cues are tracked per screen even while silent, so a
    delivered track starts in the right place with no code change. Hover sounds play only with a
    pointer. Mute silences Master, so every sound respects it.
89. **Save rings are keyed by turn:** the auto-save for turn T goes to slot `auto_(T mod 10)` and
    the checkpoint to `checkpoint_((T / 5) mod 6)`, so the rings need no index file and always
    hold the newest turns. A loss offers the newest checkpoint of the same game (scenario and
    seed) from before the losing turn. Manual saves are numbered and never overwritten. Ironman
    mode (a single save) waits for the settings screen. Nothing is written while
    `Settings.persist` is off (tests and the screenshot tour).
