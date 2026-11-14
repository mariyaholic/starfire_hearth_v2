# M2C Stop at next — actual-control QA

Passed the scoped native rendered checks. Godot 4.7.2, Xvfb/Mesa llvmpipe. The process started on WIP `93f8cb3` with the four-system map, before the separate Shroud content changes. No production source was edited by the playtester.

**Synthetic initial setup, then actual OS controls:** `seed_fixture.gd` builds preview seed 23 at Month 4. The Survey Probe starts in Ember, already one turn into the three-turn lane to Tessel, on the route Tessel → Halden, with automatic exploration enabled. Tessel is known, Halden remains unknown. Initial remaining journey is five turns. The normal save serializer writes this fixture; Continue, navigation, orders, Undo and End Turn afterward use real pointer/keyboard events. The harness only observes UI/state and captures rendered frames.

| Actual action | Observed result | Screenshot |
|---|---|---|
| Open Fleet Travel in 3D | Auto on; final Unknown star 2, route Tessel → Unknown star 2; remaining 5; current Ember/progress 1 | `01-initial-multihop-3d.png` |
| Stop auto-explore | Auto off; both hops, current system, progress and ETA 5 preserved | `02-stop-auto-keeps-full-route.png` |
| Undo, switch to Strategic, Stop at next system | Only Tessel remains; Auto off; current Ember/progress 1 unchanged; remaining 2 | `03-stop-next-strategic-truncated.png` |
| Actual Undo | Both hops and Auto on restored; Ember/progress 1, remaining 5 match the initial observation | `04-undo-restores-route-and-auto.png` |
| Phone 200%, scroll to Stop at next | Complete button and drawer close remain inside viewport | `06-phone200-stop-button-full-width.png` |
| Stop at next on phone, reopen drawer | Single-hop Auto-off action is disabled with a fully wrapping explanation | `07-phone200-singleleg-off-disabled.png` |
| Enable Auto on that single hop | Stop at next is enabled; actual click switches Auto off while preserving Ember/progress 1, ETA 2 | `08-phone200-singleleg-auto-on-allowed.png`, `09-stop-final-preview.png` |
| Resolve one real turn | Still Ember, progress 2, remaining 1, Auto off | `10-after-one-actual-turn.png` |
| Resolve second real turn | Report says arrived in Tessel; path empty, progress 0, Auto off | `11-arrival-at-tessel-report.png`, `12-arrived-tessel-3d.png` |
| Resolve an extra real turn | Still idle in Tessel, path empty, Auto off; no resumed travel or survey | `13-extra-turn-no-auto-resumption.png`, `14-arrived-tessel-strategic.png`, `15-idle-at-next-system-auto-off.png` |

Every cited screenshot was opened and inspected. Matching JSON files record read-only observations, including system, path, progress, automation and ETA. The Month 7 autosave also leaves Halden unknown, confirming no later-hop arrival. No new visual defect was found. Phone presentation is forced 2400×1080 / Layout.PHONE at 200% text, with actual wheel scrolling and OS clicks, not a physical phone. No browser, audible audio, performance, malformed-route, or long-duration automation claim is made; automated tests belong to the lead's separate validation. The delivered M2A video is untouched.
