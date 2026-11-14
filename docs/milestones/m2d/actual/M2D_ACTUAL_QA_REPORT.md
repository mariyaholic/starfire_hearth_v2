# M2D actual rendered QA

Result: passed the exercised Shroud discovery and gas-giant Research outpost flow. No blocking visual or control defect was observed in the verified captures. Independent reviewer inspected the actual event, projections, orders, Undo, completion and owned-output frames.

## Scope and provenance

This is actual native Godot 4.7.2 rendering with real X11 pointer input under a private Xvfb display and Mesa llvmpipe. It is not a normal campaign playthrough: `seed_fixture.gd` creates a clearly synthetic turn-2 initial save with the probe and builder already travelling from Vesper to Shroud, Veil already surveyed, and supplied resources. The probe has two turns remaining; the builder has four. After loading that fixture through the normal title Continue control, gameplay actions, event selection, Undo, map switches, turn confirmations and Save were actual OS clicks. No turns or outcomes were injected after setup.

The observation harness only reads state/UI geometry, configures desktop or phone layout/text scale, and captures the actual game viewport. Phone captures use the game's phone profile at 200% text, 2400×1080 pixels (about 873×393 logical pixels). They are native desktop renderings of the phone layout, not physical-device or browser-touch validation. Desktop captures are 1920×1080.

This process loaded source before the final subtitle-only clarification from “Projected per turn” to “Projected per turn with current modifiers”. These frames validate mechanics and layout before that wording change. Final wording has separate author-render evidence. Runtime source fingerprints are recorded in `source_hashes.txt`; native window identity is in `window_identity_v2.txt`.

## Actual controls and results

1. Continued the synthetic turn-2 save and clicked End turn / End anyway through turn 4. The probe arrived in Shroud while the construction ship remained in transit. Before closing the turn report, the observer showed one pending Shroud event and no discovery flags. One Continue click opened “The Quiet Freighter”; the event remained unresolved in screenshots 01–03.
2. Inspected all three desktop choices: recover hull costs 30 Energy and grants 20 Metals; recover provisions costs 10 Energy and grants 50 Food; honour the crew grants 10 Influence. The prose warns that rewards obey storage limits. Scrolled the actual event at phone 200% to inspect its choices; no horizontal overflow was observed.
3. Deliberately clicked recover provisions once. Energy changed 218 → 208 and Food 226 → 276; only `m2a_shroud_resolved:4` and `m2a_shroud_supplies:4` flags appeared. The other two branches were inspected but not executed in this accepted run.
4. Opened Galaxy, selected Shroud and focused Veil in 3D; switched through the actual Strategic control. Before builder arrival, both projections were present: Energy net +5.5 GW/turn, with −0.5 GW upkeep explicitly included; Research +2.7 per turn in each of Physics, Society and Engineering, with −0.5 GW Energy upkeep. No-builder guidance was visible in both modes (04–05).
5. Continued actual turns to turn 6, when the builder arrived. Both outpost actions showed 50 Influence and four turns to build (06). Actual phone scrolling exposed the full Energy and Research labels, costs and four-turn duration (07–08); both labels fit horizontally.
6. Clicked the Energy outpost order: Influence 116 → 66, builder task `outpost`, parameter `energy`, four turns remaining (09 and paired JSON). Clicked Undo: Influence restored to 116 and builder became idle (10). Clicked the Research outpost order: Influence 116 → 66, parameter `research`, four turns remaining (11). Both order controls then correctly disabled with a busy-ship explanation.
7. Clicked End turn / End anyway / Continue through turns 7, 8 and 9; task countdown was 3, 2 and 1. The fourth actual turn produced the turn-10 report “Outpost built on Veil, yielding Research.” (12). No research or completion was injected.
8. Closed the report and inspected the finished Research outpost in Strategic (13) and 3D (14). Both showed current output +2.7 in each research branch and −0.5 GW Energy upkeep. The builder was idle. The Energy projection and research projection had been replaced by the owned Research output.
9. Used Menu → Save. `manual_1.json` was created at turn 10. Read-only inspection confirmed `col_0002` is a Research outpost on `pl_shroud_giant`, the planet links to that colony, and the provisions/resolution flags persist. `verified-save-summary.json` records the save path, digest and relevant fields. This task verified saving, not reloading.

## Verified evidence

Every PNG listed below was opened and inspected before receiving its final filename. Its same-named JSON records UI/state observations from the capture. Rejected provisional captures are excluded.

| Evidence | Observed state |
| --- | --- |
| [01](verified-01-discovery-desktop.png) | Pending unresolved Shroud discovery, all three choices |
| [02](verified-02-discovery-phone200-top.png), [03](verified-03-discovery-phone200-choices.png) | Phone 200% event top and actual scrolled choices |
| [04](verified-04-projections-before-builder-3d.png), [05](verified-05-projections-before-builder-strategic.png) | Both projections before builder arrival, both map modes |
| [06](verified-06-builder-arrived-orders-desktop.png) | Arrived builder, both outpost orders with cost/time |
| [07](verified-07-energy-order-phone200.png), [08](verified-08-research-order-phone200.png) | Actual scrolled phone 200% order labels/costs/durations |
| [09](verified-09-energy-order-queued.png) | Energy order queued, Influence 66; JSON identifies Energy task |
| [10](verified-10-undo-energy-order.png) | Undo restored Influence 116 and idle builder |
| [11](verified-11-research-order-queued.png) | Research order queued, Influence 66; JSON identifies Research task |
| [12](verified-12-research-outpost-completion-report.png) | Actual turn-10 completion report |
| [13](verified-13-owned-output-strategic.png), [14](verified-14-owned-output-3d.png) | Finished Research outpost current output in both modes |
| [Save summary](verified-save-summary.json) | Actual saved turn-10 outpost/flags and digest |

## Limits and observations

No blocker remains for this scope. One pre-existing copy nit remains: “Build a Energy outpost”. No production fix was requested for this wave.

The first provisional attempt is excluded: an input helper retried the report-close click and accidentally selected the first newly opened discovery choice before capture. Those frames did not show their intended states. They were quarantined privately under `rejected/attempt1`; they substantiate no visual defect or branch test. The accepted fresh run removed automatic retries, used single pointer inputs, checked pending-event/flag guards, and inspected each image before naming it.

This run did not construct an Energy outpost to completion, execute Salvage/Honour, exercise a Halden timed research modifier, test storage overflow, reload the M2D save, play a full campaign, or run browser/physical-phone/performance/audio checks. Headless regression results belong to the lead's separate test run and are not counted here. Software GL emitted only its unsupported V-Sync warning; no script error was logged. Audio used Dummy.

The owned Godot process, observation harness and private Xvfb session were closed through actual Menu → Quit controls after saving. Isolated saves and private raw evidence remain preserved. The delivered M2A gameplay video was left unchanged.
