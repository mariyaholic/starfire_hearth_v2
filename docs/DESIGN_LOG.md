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
