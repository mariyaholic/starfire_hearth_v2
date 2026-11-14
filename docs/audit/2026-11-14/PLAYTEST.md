# Actual playtest audit — 2026-11-14

The exercised fixes passed: native autosave failure now reports a readable warning, deletion requires confirmation and respects Cancel, and the final release Web manual-save success acknowledgment survives immediate reload. The normal release network trace recorded no third-party HTTP destination or WebSocket. These are bounded actual-input results, not a claim that every gameplay/platform path has been audited.

## Builds, profiles and method

- Baseline Web: immutable M2F fixed release `/workspace/starfire-evidence/m2f-fixed-build/web`, associated with the pre-audit `bb6e993` baseline. Fresh disposable Chromium context, 1920×1080/DPR 1, requested SwiftShader, normal URL without smoke hooks or an injected save. Actual mouse/keyboard controls reached title → campaign → S1 briefing → game → Settings → actual turn 2 → Load screen.
- Native before/after: exact Godot 4.7.2 under private Xvfb/Mesa llvmpipe with Dummy audio. An explicitly synthetic preview turn 2 fixture was loaded through the title. Only its disposable save-directory path was temporarily replaced with a regular file to cause real filesystem failures. No SaveService runtime override was used. Relevant source hashes are in the before/after evidence directories. Other audit work was concurrent; the after process predates the final campaign-progress write-warning adjustment, which is not part of its visual claims.
- Final Web: full consolidated release `/workspace/starfire-evidence/audit-final/build/web`, not the earlier manual-only `final2` artifact. A fresh profile was seeded before app load with the actual S1 turn 2 save produced by the normal baseline play. Subsequent Continue, Menu, Save, reload and Load controls used actual input. This shortcut is a labelled initial fixture, not another full normal campaign playthrough.

All accepted full screenshots were opened and inspected before naming/copying them. Native paired JSON contains read-only UI/state observations. Web records are read-only IndexedDB snapshots; no game/state method was invoked after initial setup. Source/export fingerprints distinguish the artifacts; no production source was edited by the playtester.

## Native save failure and deletion

A normal manual Save first produced “Game saved.”. With only the disposable saves path blocked, actual manual Save produced “The game could not be saved.”. The same baseline actual End turn advanced2→3 but showed “Nothing to report” without any save-error label, despite no automatic save being possible. This genuinely silent failure was sent to the UI author.

The updated native process repeated that failure. Its actual turn 3 now displayed “An automatic save failed. Please save your game.” in the desktop report. A second actual blocked-path turn displayed the same readable warning at phone layout and 200% text. The toast temporarily covers a small edge of the report's Continue button; its label and most of its target remain exposed, and the actual Continue control worked.

After restoring the disposable directory, actual Save created `manual_1`. At phone 200%, actual Delete opened the confirmation; actual Go back preserved `manual_1.json`. Reopening Delete on that same slot and clicking Confirm removed it while preserving `fixture_audit_start.json`. The remaining row in the after image is the original fixture, which the app labels “Manual save”; paired button paths identify it unambiguously. This was not a deletion of owner data.

| Evidence | Actual state |
| --- | --- |
| [Before manual success](playtest/native-baseline/verified-01-manual-save-success-before-block.png) | Normal save before fault injection |
| [Before manual failure](playtest/native-baseline/verified-02-manual-save-failure-feedback.png) | Existing failure feedback worked |
| [Before silent autosave failure](playtest/native-baseline/verified-03-autosave-failure-no-feedback.png) | Actual turn advanced without error feedback |
| [After desktop warning](playtest/native-after/verified-01-autosave-failure-warning-desktop.png) | Updated warning is visible |
| [After phone 200% warning](playtest/native-after/verified-02-autosave-failure-warning-phone200.png) | Warning wraps and is readable |
| [Phone 200% confirmation](playtest/native-after/verified-03-delete-confirmation-phone200.png) | Both confirmation choices fit |
| [Only target removed](playtest/native-after/verified-04-delete-confirmed-only-target-removed.png) | Original fixture remains; manual_1 is absent |

The independent reviewer also inspected these after frames and checked their paired slot paths. The filesystem block was restored and native processes were closed.

## Normal Web network and local storage

The context-wide trace captured 7 requests: 6 same-origin HTTP GETs and 1 same-origin `blob:` request. The HTTP resources were the document, app icon/splash image, JavaScript, Wasm and packed game data. The blob is a local in-memory URL, not an external server. There were no request bodies, other destinations, WebSockets, cookies or console/page errors in this bounded flow. This is browser-context observation, not a host-wide packet capture or proof that every unexercised feature is offline.

After an actual Settings change and actual turn, localStorage held only `starfire_hearth.view_mode.v1 = command`; sessionStorage and cookies were empty. IndexedDB contained database `/userfs` version 21 with `FILE_DATA`, using `/userfs/godot/app_userdata/Starfire Hearth/`. Observed files were `settings.cfg` (614 bytes), `saves/auto_2.json` (15,763 bytes) and its PNG thumbnail (17,360 bytes), plus directory records for the engine shader cache.

The settings file contains display/accessibility/play/audio preferences. The JSON save envelope records format/version/checksum, game version, scenario, seed, turn, RNG metadata, presentation and simulation state. Its state holds the fictional empires, colonies, resources, ships, movement/tasks, events, objectives and outcome. No account, authentication cookie or entered owner information was present in these disposable profiles. This inventory concerns the observed origin storage, not the whole browser profile or an encryption guarantee.

[Classified requests](playtest/web-baseline/classified-network-requests.json), [network summary](playtest/web-baseline/network-summary.json), [storage inventory and field names](playtest/web-baseline/storage-inventory.json), and original snapshots/actions are preserved. Settings and autosave snapshots illustrate asynchronous browser persistence: an early snapshot lacked save files that appeared in later readback. They are not instant-close durability assertions.

The baseline run later encountered a 20-second screenshot/readback timeout under shared software GL. Two earlier coordinate Save attempts did not establish a successful manual save and are excluded from success and action-specific performance claims. No product defect is inferred from those unverified inputs or the capture timeout. The final-release manual-save regression below supplies the accepted save/reload proof.

## Responsiveness observations and their limits

A passive browser input/requestAnimationFrame observer recorded trusted inputs. Screenshots/readback were disabled during each timing window and happened afterward. These numbers measure mouse-up dispatch → next JavaScript animation callback, with a sampled callback interval. They do not measure visible-paint acknowledgment, physical input latency, GPU rendering cost or hardware FPS. Shared cloud CPU/software-GL load and small sample counts limit interpretation; no before/after speed claim is made.

| Actual control | Mouse-up → next rAF callback (ms) | Sampled rAF interval p95 (ms) |
| --- | ---: | ---: |
| title Campaign | 137.2 | 116.6 |
| S1 Begin | 1144.9 | 383.2 |
| game Menu open | 2069.5 | insufficient samples |
| game Settings open | 946.1 | 866.6 |
| End turn checklist | 812.9 | 883.2 |
| confirm End turn (with autosave) | 1359.3 | 1150.0 |

[Qualified raw samples](playtest/web-baseline/qualified-input-timings.json) and [TSV](playtest/web-baseline/qualified-input-timings.tsv) also record the actual observation-window duration and CDP main-thread task/script/layout durations. A missing interval percentile means too few callbacks, not zero frame cost. Manual-save acknowledgment polling is functional ordering evidence and includes screenshot overhead; its elapsed time is not a performance benchmark.

## Final release manual-save acknowledgment and reload

The final release test loaded the labelled S1 turn 2 fixture through normal title Continue. Actual Menu → Save was followed by a visual-region loop that waited for the green “Game saved.” toast. The first observed success frame immediately triggered `page.reload()` in the same script, with no human inspection or fixed safety delay after acknowledgment. The captured success region visibly contains “Game saved.”; a fading Saving toast is also present.

Post-reload read-only IndexedDB contains `manual_1.json`. Its complete authoritative simulation dictionary exactly matches the initial S1 turn 2 state (seed 1183028510), with no time/resource/task advancement. Actual title Continue opened the game, and the manual slot was also opened through the Load screen. The final accepted evidence, exact state/envelope comparisons, actual timing and cleanup are recorded under [final Web evidence](playtest/web-final/README.md). The resumed frames show active UI/date while the terrain viewport remains gray; they do not validate completed world rendering or visual quality.

## Scope limits and cleanup

The playtester did not execute the destructive release `?smoke=begin` experiment. Its source/validation results belong to the separate audit records; no slot-overwrite result is claimed here. No owner data was imported or used. The after native process does not establish the newer campaign-write-warning visual behavior. Ordinary Web autosave/settings/delete immediate-close durability, storage quota denial, background tab behavior, mobile browsers, audio and physical-device performance were not tested by this bounded run. Prior M2F continuation evidence remains in its separate milestone report.

All owned native/observer/Xvfb/browser/HTTP-server sessions were closed after these checks. Disposable saves and private raw evidence remain preserved. No production edit, stage, commit, push, merge, deployment or delivered-video change was performed. Accepted evidence and SHA-256 manifests are under `playtest/`.
