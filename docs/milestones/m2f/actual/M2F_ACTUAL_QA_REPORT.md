# M2F actual native continuation QA

Result: passed the exercised preview victory → continuation → immediate title reload → unfinished outpost completion flow. All verified images were opened and inspected; the independent reviewer accepted the native debrief and continued-flow frames.

## Method and explicit initial setup

Godot 4.7.2, normal app root and real X11 pointer input under a private Xvfb display with Mesa llvmpipe. Audio used Dummy. This is not a full campaign playthrough. `seed_fixture.gd` creates a synthetic near-victory turn-40 save: required objectives already complete, a developed Vesper colony, Halden and Shroud discoveries already resolved with memory, surveyed Veil, a Research outpost task with three turns remaining on the construction ship, and a probe partway from Ember to Vesper (progress 1, remaining ETA 4). Starting resources are supplied. Initial setup uses the normal SaveSerializer through SaveService.

After loading that initial save, every gameplay transition used actual OS clicks: End turn, End anyway, Continue expedition, Quit to title, title Continue, navigation, map presentation switches and Save. No turn, outcome, flag, stock, travel or task was injected after setup. The observer reads UI geometry and the complete authoritative state; it configures capture layout/text scale and saves the actual viewport. The helper sends single clicks without automatic retries.

Desktop captures are 1920×1080. Simulated phone captures are 2400×1080, about 873×393 logical pixels, phone layout and 200% text. These native phone-layout frames are not physical-phone or browser testing; separate fresh-export Web evidence is documented alongside this report when available.

## Actual sequence and checks

1. Title Continue loaded the turn-40 synthetic fixture (01). Actual End turn / End anyway resolved its victory. The simulation's resulting current state is turn 41; its original `outcome_turn` is 40, rendered as Month 4, Year 103 S. This follows the existing completed-turn convention. The builder's task now has two turns remaining and the probe is at progress 2.
2. Victory debrief shows distinct “Continue expedition” and “Return to campaign” controls, both fully visible at desktop and phone 200% (02–03). The original completion date is readable. Return to campaign was inspected but not activated in this actual run; its behavior has separate integration coverage.
3. Clicked Continue expedition once in phone layout (04). The game became active with `outcome == ""`, current turn still 41, builder task still two turns, and probe still progress 2. A complete authoritative-dictionary comparison against the winning state passed: only the three outcome fields and the two continuation flags changed. Every stock, fleet path/progress, ship task/countdown, research field, colony, memory and counter remained equal. See `verified-zero-turn-comparison.json` and paired state observations.
4. Before any further End turn, clicked Menu → Quit to title (05), then title Continue (06). The resumed route was Game, not Debrief, with an exactly identical authoritative dictionary and valid continuation flags. See `verified-immediate-resume-comparison.json`. This demonstrates the new immediate auto-save replaced the winning state before another turn.
5. Opened Objectives. Desktop and phone 200% show “The expedition continues…” and the original Month 4 / turn 40 completion date (07–08), while the current state remains turn 41. Text wraps without horizontal clipping.
6. Opened Galaxy, selected Shroud and focused Veil in the retained 3D presentation. The unfinished outpost still shows two turns remaining (09). Actual End turn / End anyway / Continue reached turn 42 and the task showed one turn left (10). The route remained active Game with no repeated win.
7. A second actual continued turn reached turn 43 and completed the originally unfinished Research outpost (11). The report says “Outpost built on Veil, yielding Research.” The game stayed active, `outcome == ""`, and the original completion flag stayed 40. Current owned output is +2.7 per turn in each research branch with −0.5 GW Energy upkeep, visible in 3D (12) and Strategic (13).
8. Reopened Objectives at phone 200% after those two further turns (14): the historical turn 40 completion date remains intact. Actual Menu → Save created a turn-43 manual save. Read-only inspection confirms the active outcome, both continuation flags and `col_0003` Research outpost on Veil. The immediate turn-41 auto-save also contains active continuation, unchanged task 2 and probe progress 2. Paths and SHA-256 digests are in `verified-saves-summary.json`.

## Evidence

Each `verified-NN-*.png` has a same-named JSON with matching observed context and full authoritative state. The accepted screenshots are:

| Images | Observed state |
| --- | --- |
| [01](verified-01-synthetic-nearwin-loaded.png) | Labelled synthetic starting state loaded normally |
| [02](verified-02-victory-debrief-desktop.png), [03](verified-03-victory-debrief-phone200.png) | Actual victory debrief, distinct actions, original date |
| [04](verified-04-continued-active-phone200.png) | Active continued game, no turn advancement |
| [05](verified-05-immediate-quit-to-title.png), [06](verified-06-immediate-continue-resumed-active.png) | Immediate title round trip before any turn |
| [07](verified-07-original-completion-date-desktop.png), [08](verified-08-original-completion-date-phone200.png) | Continued Objectives preserves original completion date |
| [09](verified-09-existing-outpost-task-after-resume-3d.png), [10](verified-10-next-turn-task-one-no-repeat-win.png) | Existing task two → one turns; continued active game |
| [11](verified-11-original-task-completes-after-continuation.png) | Actual second continued turn completes Research outpost |
| [12](verified-12-owned-output-3d.png), [13](verified-13-owned-output-strategic.png) | Finished outpost in both presentations |
| [14](verified-14-original-date-after-further-turns-phone200.png) | Historical completion date after further turns |

## Limits and cleanup

No blocker or new visual defect was found. This bounded run does not establish full-campaign balance, physical-phone behavior, auditory quality or hardware performance. Return to campaign, stale callbacks, save-failure handling, later loss and legacy saves were not exercised by this actual play run; the lead/reviewer's separate tests cover their own stated scope. No headless test suite is counted as actual play here.

The input helper initially needed a title-screen hit-area adjustment because its game-only top-bar guard prevented a top-positioned Continue button from being clicked. No unintended gameplay occurred and there was no retry/double-click. No game defect is inferred from that harness issue.

Actual Quit closed this owned Godot, observer and private Xvfb session. Isolated saves and private raw evidence remain preserved. No production source was edited, no staging/commit/push was performed, and the previously delivered gameplay video was left untouched.

Fresh production Web results: the first export reproduced a rapid-reload persistence failure, preserved in [the original Web report](web/M2F_WEB_QA_REPORT.md). The corrected export passed immediate reload at the first observed active-game acknowledgment; see [fixed Web retest](web/fixed/M2F_WEB_FIX_RETEST.md).
