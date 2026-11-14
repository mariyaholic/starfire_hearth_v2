# M2F actual Web continuation QA

Historical result on the first export: ordinary before-next-turn page reload passed, but rapid page reload failed. The corrected production export now passes immediate-after-active-acknowledgment reload; see [fixed retest](fixed/M2F_WEB_FIX_RETEST.md). The original failure evidence below is preserved.

## Actual setup and method

Fresh production export `/workspace/starfire-evidence/m2f-build/web`, exported with Godot 4.7.2. Actual headless Chromium with SwiftShader, viewport 873×393 CSS pixels, DPR 2.75, mobile mode and `has_touch`; all gameplay uses real `touchscreen.tap` inputs. Text is 200%. This is browser touch emulation, not physical phone testing. There is no smoke probe or production instrumentation.

Each accepted run starts in a fresh browser context/origin. Before its first app load, the normal SaveSerializer near-victory fixture from the native setup and a text-size settings file are seeded into IndexedDB. The mount root is `/userfs`, but the actual game user directory is `/userfs/godot/app_userdata/Starfire Hearth/`. That prefix was derived from an engine-created settings file after a diagnostic actual settings touch, not guessed from the mount root. Parent directory records, the fixture under `saves`, and `settings.cfg` are created before app load. No game or state method is invoked after setup. Persisted files are inspected read-only through IndexedDB.

Initial diagnostic bootstraps that put files directly under the mount root did not load the fixture and are excluded from gameplay claims. Those private attempts also contained harness-only screenshot/serialization problems; none substantiates a game defect. Accepted runs use the discovered prefix. The HTTP test server answers the optional favicon request with HTTP 204; accepted runs recorded zero browser console/page errors.

## Before-next-turn run

Actual title Continue loaded the synthetic near-win game, actual End turn / End turn anyway produced the victory debrief, and the saved `auto_1.json` showed current turn 41, original win turn 40 and builder task 2.

Actual Continue expedition opened active Game with unchanged displayed stocks. An IndexedDB read after a requested 500 ms wait still held the previous winning snapshot. After screenshot and record inspection, an actual `page.reload()` occurred 21.6 seconds after the continuation tap, before any further turn. Actual title Continue then opened active Game, not Debrief. Full persisted authoritative-state comparison passed: the winning snapshot changed only in outcome metadata and the two continuation flags; all stocks, travel/progress and ship tasks remained equal. The same dictionary survived reload and title Continue. See `verified-web-persistence-comparison.json` and saved-record observations.

One actual continued End turn reached 42, with the original win turn 40 retained, outcome empty and builder task 1. The report had no repeat victory; closing it returned to active Game. This is the scope of the successful first Web run, not proof of instant tab-close durability.

Inspected screenshots 01–10 show seeded title, loaded fixture, turn confirmation, victory debrief, continued active game, reloaded title, resumed active game, subsequent confirmation, subsequent report and active game after that report. `report.json` records actual taps/reload/timestamps and zero errors.

## Rapid-reload reproduction

A separate fresh context repeated the same normal fixture load and actual End turn victory. The winning `auto_1.json` was verified durable before the experiment. The visible debrief and choice positions were inspected.

Then a single actual touchscreen tap on Continue expedition was followed by `page.reload()` after 1059.8 ms, measured from the start of the input call (the requested wait after the tap returns was 500 ms), in the same script with no intervening screenshot, read, or model inspection delay. No further turn or state injection occurred. After reload, read-only IndexedDB still held the winning snapshot with no continuation flags. Actual title Continue returned to the victory debrief with Continue expedition offered again.

- [Verified victory before reload](rapid-reload/verified-01-actual-victory-before-rapid-reload.png)
- [Title after rapid reload](rapid-reload/verified-02-title-after-rapid-reload.png)
- [Repeated debrief after actual title Continue](rapid-reload/verified-03-repeated-debrief-after-title-continue.png)
- `rapid-reload/after-rapid-title-continue.json`: matching persisted outcome `won` and missing continuation flags.
- `rapid-reload/report.json`: measured delay, actual touch/reload actions and zero errors.

The rapid-reload experiment intentionally has no intermediate active-game screenshot because taking one would alter its timing. The ordinary run independently demonstrates that the same actual tap activates continuation; the rapid run demonstrates loss across an immediate reload. The evidence supports a persistence timing gap, not a failure of the native zero-turn transition.

## Cleanup and limits

Both accepted browser contexts, Chromium instances and private HTTP servers were closed cleanly. No production code/export was modified. No staging, commit, push or video change occurred. This check does not validate a physical phone or audio/performance. The native run supplies actual unfinished-task completion and both map-mode evidence; the Web run only advanced one continued turn.

Rapid-reload failure was sent immediately to the lead and independent reviewer. The subsequent corrected-export retest passed; see the linked fixed retest report.
