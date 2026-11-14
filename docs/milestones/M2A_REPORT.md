# M2A — Exploration preview

14 November 2026 · source base `2c478cb`

This records the first iteration at `0a3ce61`. The subsequent
[M2B report](M2B_REPORT.md) supersedes its current-feature status while retaining
these test results and screenshots as historical evidence

## What works

Launch **M2A Exploration Preview** from Campaign without completing First Light.
Send the three civilian fleets from Ember toward Tessel, Vesper and Halden's Gate.
Survey a frontier planet, establish a mineral outpost and develop Vesper's ocean
colony. Halden's dormant beacon is a landmark; restoring it is not implemented

Routes resolve in the existing movement phase, using integer turn counts and
the slowest ship. The drawer explains the route and remaining time. Arrival
reveals a system without surveying its planets. Known intermediate systems may
connect a journey to one unknown destination; undiscovered waypoints cannot
provide hidden shortcuts

Busy ships cannot depart. Travelling ships cannot work at their retained origin,
appear idle in the turn checklist or receive replacement routes. Corrupt routes
freeze with an explicit warning. Save/load preserves progress in the existing
fields; no simulation schema migration or golden rebaseline was introduced

Preview wins do not modify canonical campaign wins, carried legacies or Scenario
3 availability. Canonical Scenario 2 remains unfinished. First Light retains its
lane restrictions and golden results

## Verified checks

All engine commands below used **Godot 4.7.2-stable**, matching `.godot-version`

| Check | Result |
| --- | --- |
| Baseline full suite at current main | 310 tests / 14,100 checks / zero failures |
| Final import | Exit 0 |
| Final data validation | 20 tables / 391 records / 1,522 strings / zero errors or skips |
| Final full suite | 328 tests / 14,244 checks / zero failures |
| Independent preview check after final fixes | 12 tests / 68 checks / zero failures |
| Independent travel check | 13 tests / 105 checks / zero failures |
| Expedition itinerary, seeds 1–3 | Every required and optional objective done at state turn 30 |
| Expedition replay | Entire per-turn logs identical on a second run for each seed |
| Expedition safety | No invariant failures, command rejections or validation waits |
| First Light baseline bots, seeds 1–3 | Wins at turns 79, 77 and 70; deterministic replay; zero invariant problems |
| Web, Windows and Linux release exports | All three exit 0; exporting Windows is not a Windows execution test |
| Packaged Linux title startup | Headless, Dummy audio, eight frames, exit 0 |
| Exported Web preview entry | Actual mouse clicks: title → Campaign → preview briefing; zero browser errors |
| Phone Web preview entry | Touch taps at 873×393 CSS / DPR 2.75; preview reached; zero browser errors |
| Desktop Web regression | 29 checks / zero failures or browser errors; real order, turn parity and IndexedDB save/reload |
| Full two-device Web regression | Incomplete: eight-minute outer limit after desktop completed and phone booted |

The expedition is a fixed command-driven itinerary with emergent events disabled.
It verifies reachability and determinism, **not** strategic variety or campaign
balance. Earlier turn-25 traces preceded the final ocean-world correction and
are superseded by the turn-30 results

```sh
godot --headless --path . --import
godot --headless --path . -s tools/validate_data.gd
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tools/expedition_bot.gd -- --seed 1 --trace
```

The existing CI checks job now replays expedition seeds 1–3 and compares the full
traces. No separate scheduled workflow was introduced

## Actual rendered inspection

A separate Sol playtester used genuine OS mouse and keyboard input on the Godot
window under Xvfb and Mesa llvmpipe. This differs from a headless bot and from
injected screenshot fixtures. Phone captures emulate layout and text settings;
they do not establish physical-phone performance or touch behavior

- [Baseline system map below the fold](m2a/baseline-system.png)
- [Galaxy labels before correction](m2a/galaxy-labels-before.png)
- [Numbered destinations and travel drawer](m2a/galaxy-and-travel.png)
- [Phone drawer at 200% text](m2a/phone-200-drawer.png)
- [Phone action reached by scrolling](m2a/phone-200-action.png)
- [Travel after resolving a turn](m2a/transit.png)
- [System map with travelling ships removed from the origin](m2a/system-transit.png)
- [Correct arrival report after a real turn](m2a/arrival-report.png)
- [Arrival report arrow opens the correct system](m2a/arrival-jump.png)
- [Survey completed after travelling](m2a/survey-completed.png)
- [Frontier colony founded through the actual controls](m2a/frontier-colony.png)
- [Strategic map at 200% phone text after scrolling](m2a/phone-200-strategic.png)
- [Preview briefing in the exported Web build](m2a/web-preview-briefing.png)
- [Preview briefing through mobile Web touch input](m2a/web-phone-preview.png)

Actual mouse/keyboard play reached Month 11, surveyed Vesper Haven and founded
its colony. Halden arrival, the optional outpost and full preview victory were
checked by the expedition bot rather than manually played to completion

The arrival captures came from a continued manual save made before the final
ocean-world content correction. They verify current report and navigation code;
they do not prove a freshly generated ocean-world appearance

The [full-suite log](m2a/tests.log), [data validation log](m2a/data.log) and three
expedition traces ([1](m2a/expedition-seed1.log), [2](m2a/expedition-seed2.log),
[3](m2a/expedition-seed3.log)) preserve the final numerical results

The independent [Web entry record](m2a/web-entry.json) covers the exported canvas
in Chromium/SwiftShader through actual mouse input, without a smoke probe or
injected gameplay state. It does not cover Web turn resolution or save/reload
The [phone entry record](m2a/web-phone-entry.json) covers actual touch-emulated
title and campaign controls, scrolling to the preview card and opening its
briefing in 64.2 seconds. It does not certify a physical phone or later gameplay

The separate [desktop regression record](m2a/web-desktop-regression.json) verifies
those operations through the existing explicit review fixture, including a real
Jobs order, appearance-state isolation, reachable controls at 200% text, parity
with the pure simulation and destroyed-page IndexedDB reload with matching
state/orbit positions. It completed 29 checks in 431.3 seconds with SwiftShader.
The [combined run log](m2a/web-regression.log) stopped at its outer 480-second
limit after capturing the phone's initial view; this is not a completed phone
regression or evidence of a phone assertion failure

Screenshot review led to corrections for the oversized appearance controls,
ambiguous unknown-star labels, off-screen phone drawer controls and an arrival
report placeholder. Independent source review also corrected stale session
callbacks, arrival navigation retaining another system's planet, false idle
warnings, foreign-fleet report disclosure and invalid-route recovery

The Web regression harness now attempts a failure screenshot and records the
failing stage without masking the original error. Its Python syntax check passes

## Limits and next work

- No combat, pirate AI, active beacon transit, Noise changes or diplomacy
- No stop-at-next-system or auto-explore order yet
- Invalid-route warnings preserve evidence; there is no repair UI yet
- No physical GPU, native Windows device or audible audio acceptance
- No full campaign balance study or owner playtest acceptance
- Full phone Web turn/save/reload regression remains incomplete
- Source review notes generic choose-a-planet copy in empty Halden; it does not
  block travel or the visit objective, and no actual empty-Halden capture was made

Astra recommends a consequential Halden discovery next, then survey auto-explore,
an optional competing destination, safe stop-at-next-system orders and a bounded
beacon-restoration project. These are recommendations, not implemented features

## Agent roles

Sol led integration; two Terra xhigh workers split simulation from interface and
content. Astra High advised gameplay. A separate Sol xhigh reviewed the code and
another Sol xhigh performed rendered playtesting. The requested 5.6 playtester
was unavailable; the owner authorized the 6.1 Sol fallback. Fast routing was not
exposed by the available selector
