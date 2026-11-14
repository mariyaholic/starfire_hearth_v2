# M2F corrected Web persistence retest

Result: PASS on the corrected production Web export. Reloading immediately after the first observed active-game acknowledgment restored the continued expedition before another turn. The earlier rapid-reload failure is preserved as historical evidence in `../rapid-reload`; it is not the current result.

## Setup and actual controls

Fresh export `/workspace/starfire-evidence/m2f-fixed-build/web`, exact Godot 4.7.2. Fresh Chromium/SwiftShader context, 873×393 CSS pixels, DPR 2.75, mobile/touch mode and 200% text. The same explicitly synthetic near-win SaveSerializer fixture and settings were seeded into the previously discovered IndexedDB user directory before first app load. Normal title Continue, End turn and End turn anyway were actual touchscreen taps. Actual victory was verified in the rendered debrief and saved turn 41/win turn 40 record before continuing. There were no post-setup game/state calls and no production test instrumentation.

The decisive action was an actual touchscreen tap on Continue expedition. A tight read-only loop sampled a small real screenshot of the top-left canvas, using the previously verified active topbar RGB(19,38,58) versus debrief RGB(11,22,34). It made no fixed safety sleep. The first sample at 1547.8 ms was still the debrief; the next sample at 3091.23 ms was the active game. The same script immediately called `page.reload()` at the first active sample, with a recorded host-side detection-to-call gap of 0.0018 ms. No human inspection, additional capture, saved-record read or grace period intervened. That tiny host measurement is not a browser/render latency benchmark. Polling cadence limits how precisely the first actual game frame is located.

After page reload, an actual title Continue tap opened active Game, not the victory debrief. Full authoritative-state comparison against the actual winning save passed: only outcome metadata and the two continuation flags changed. Current turn 41, original completion 40, builder Research task 2 and probe progress 2 were unchanged. All resources, other task/travel fields and the rest of the authoritative dictionary matched the expected zero-turn transition. The entire persisted envelope bytes read after page reload were identical to those read after actual title Continue. No further turn was executed in this corrected-export regression.

## Readback timing and evidence

The observer queried IndexedDB before each visual sample. Its last pre-sample read still held the winning state; the browser committed and the game became available between that read and the visual sample. It is retained as `persisted-auto-before-final-visual-sample.json`, explicitly not claimed as a simultaneous at-ack snapshot. The decisive persistence evidence is the successful immediate-after-visual-ack reload and the exact complete continued envelope read after reload/title Continue.

- [Actual corrected-export victory](verified-01-corrected-export-actual-victory.png)
- [Title immediately after acknowledgment-triggered reload](verified-02-reload-immediately-after-active-ack.png)
- [Active continued game after actual title Continue](verified-03-continued-game-after-rapid-ack-reload.png)
- `verified-fixed-persistence-comparison.json`: full-state expected delta, exact envelope equality, preserved task/progress and recorded timing.
- `report.json`: actual input/reload actions, visual poll values and zero browser console/page errors.
- `export_hashes.txt`: exact tested artifacts. The old failed export is separate and unchanged.

All full screenshots above were opened and inspected before receiving their verified filenames. The visual detector crop is also preserved; it is only an acknowledgment timing artifact, not a substitute for the full context frames.

## Limits and cleanup

This is browser touch emulation from a synthetic fixture, not physical-phone validation or a full campaign playthrough. Native actual evidence separately covers both map presentations and unfinished outpost completion. [Saving-state companion observations](saving-companion/SAVING_COMPANION.md) include an actual Saving/disabled-actions screenshot and a duplicate Continue tap; the Return attempt straddled acknowledgment and the reload did not occur while pending, so those behaviors are not claimed. The corrected acknowledgment test browser/context/server closed cleanly. No production source/export, staging, commit, push or delivered video was changed by the playtester.
