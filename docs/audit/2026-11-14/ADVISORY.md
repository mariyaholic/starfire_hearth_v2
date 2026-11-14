# Whole-game advisory audit — 2026-11-14

## Lead closeout note

The advisory below is retained as the Astra baseline review of `bb6e993`, not a
list of defects still present in the final tree. The release hook, worker/matrix,
autosave/campaign feedback and delete-confirmation findings were subsequently
fixed and checked by the implementation and verification agents. See
[APP_AUDIT.md](APP_AUDIT.md), [SIM_AUDIT.md](SIM_AUDIT.md) and
[VALIDATION.md](VALIDATION.md) for current dispositions and actual results.
Settings errors, ordinary Web autosave/campaign durability and large-local-file
bounds remain qualified gaps. PR #9 was frozen at `90e3db5` and later merged
externally into `main` at `4ac2cd0`; this session performed no merge

## Scope and evidence limits

Read-only advisory review of the application entry points, session/persistence contracts, runtime developer probes, local data flows, resource lifetime controls, and CI evidence. Baseline: `bb6e993` (M2F, PR10); PR9 remains frozen at `90e3db5`. Other audit agents were concurrently changing product code. References below describe the baseline unless explicitly marked as a working-tree fix. This adviser changed only this document.

This is source inspection plus the small shell reproduction recorded below. It is **not** a new full test run, browser playtest, visual assessment, penetration test, or network capture. Actual browser reproduction and screenshots belong to the app audit/playtest reports. No visual defect is asserted here without images. Existing M2F test/playtest results are not claimed as tests performed by this adviser.

Ownership: Terra A covers simulation authority/invariants and asset intake; Terra B covers app/UI/save/Web and the release probe reproduction/fix; the lead consolidates their evidence and final verification. This report adds cross-cutting findings and coverage gaps rather than duplicating their detailed test results.

## Priorities and demonstrated/source-confirmed findings

### A1 — High: release URL test hooks can mutate player state and persistence

At `bb6e993`, `ui/screens/app_root.gd:34–92` calls `_web_smoke` on every Web build, without a debug-build check. `?smoke=begin` starts S1 and ends a turn; `SaveService._on_turn_resolved` autosaves when persistence is enabled (`app/save_service.gd:151–153`). The actual reproduction writes `auto_2` in the normal save directory solely from a URL visit: the resolved turn advances the current state to two. This is a concrete local data-integrity exposure, not evidence of remote code execution.

The other accepted smoke values construct root-level Stage A/C/D/E/F or immersive probes. `ui/world/stage_a_probe.gd` and `stage_c_probe.gd` turn `Settings.persist` off; `stage_e_probe.gd:13–20` additionally redirects `SaveService.dir` to a review directory. They do not restore those settings upon normal screen navigation. Consequently a fixture route can leave subsequent ordinary play without ordinary autosaves, or using a review directory. `ui/world/immersive_probe.gd:23` explicitly saves settings despite its initial `persist=false`. Probes poll same-page JavaScript action globals, expose game/renderer diagnostics in `window.__m11*`, and can create generous test fixtures (`stage_e_probe.gd:30–57`). They are stateful controllers, not merely read-only telemetry.

These scripts live under `ui/`, while `export_presets.cfg` excludes `tests/`, `tools/`, `docs/`, `screens/`, `telemetry/`, and `build/`; those exclusions did not prevent probe activation. Query values select fixed actions: no arbitrary URL-to-eval code interpolation was identified.

**Status:** Terra B owns an actual release reproduction and fix. During this review the working tree added `OS.is_debug_build()` to AppRoot's call site and a separate debug smoke export. Treat that as pending until its export/browser evidence is included. Acceptance: every recognized smoke URL leaves a release build at the normal title with ordinary settings/save directory and no probe instance or game/save mutation; ordinary release gameplay still works; debug CI smoke continues to test its intended path. Prefer an isolated browser profile/origin for debug fixtures, since debug builds retain the intentional mutating hooks.

### A2 — Medium: balance CI can hide a failed background worker

`.github/workflows/ci.yml:99–105` launches separate policy/Story processes with `&`, then runs bare `wait`. Reproduced in the audit shell:

```text
bash -c '(exit 17) & (exit 0) & wait; printf "bare_wait_status=%s\n" "$?"'
bare_wait_status=0
```

`tools/telemetry_report.gd:33–37` rejects only an entirely empty set. It aggregates files present, and `_winnable` skips absent policy/difficulty groups (around lines 198–200). It does not enforce the CI's expected 100-run manifest. A worker failure leaving other workers' output can therefore escape the process gate and produce a partial report without a completeness failure. This reproduces the shell mechanism and establishes the report gap from source; no failed GitHub run was induced.

Recommended acceptance: collect each PID and fail if any exits nonzero; independently require the expected scenario/policy/difficulty/seed tuples before applying telemetry gates. A missing or truncated run must fail completeness even in `--balance advisory`; advisory balance thresholds should remain a separate decision. Inject one failing worker in a test of the orchestration and show nonzero status.

### A3 — Medium: autosave and campaign persistence failures are silently discarded

`app/save_service.gd:26–48` checks open/write/rename failures and returns an Error, but `_on_turn_resolved:151–153` ignores the returned autosave Error. `app/campaign_progress.gd:103–115` returns a file-open error, then `_changed` discards it; writes also have no explicit post-write error check. Thus the simulation/campaign UI can proceed with no player-visible indication that progress was not saved. This is a source-confirmed error propagation gap. No disk-full or browser-quota failure was reproduced by this adviser.

Recommended acceptance: simulate an unwritable save destination; the player gets a clear failure notice and no false success message, the previous valid slot remains loadable, and play/retry remains usable. Test campaign failure separately from turn autosave. Do not claim `FileAccess.flush` success proves Web durability: M2F explicitly treats that as a different boundary (A5).

### A4 — Medium: permanent save deletion lacks the specified confirmation

`ui/screens/flow/load_screen.gd:63–80` wires Delete directly to `SaveService.delete`, which removes both save and thumbnail (`app/save_service.gd:77–80`). There is no confirmation or undo at this call path. `docs/BUILD_PROMPT.md:1110`, screen 14, explicitly says deletion needs confirmation. This is source-confirmed accidental data-loss exposure and a specification mismatch; no visual claim is necessary.

Recommended acceptance: the first click opens a confirmation naming the selected save; cancel preserves both files; confirm deletes only that slot; stale confirmation from a detached/rebuilt screen cannot delete a newly selected slot. This is an existing-flow safeguard, not a request for another gameplay feature.

## Important coverage gaps, not demonstrated defects

### A5 — Web persistence beyond M2F and multi-instance interactions

M2F's `Game.continue_expedition` saves before publishing the continued session (`app/game.gd:100–149`). Its asynchronous completion checks operation generation, state identity, session serial and the empty queue. `app/web_save_verifier.gd:9–87` performs read-only IndexedDB transactions, compares exact expected bytes and acknowledges on transaction completion; it never creates a second save store or transmits content. It has a 15-second deadline and cancellation/cleanup. The known ordinary Web write-then-immediate-reload concern should not be conflated with this specifically guarded path.

Ordinary turn/manual saves, campaign progress and most settings do not use that acknowledgement path. Source alone does not establish the probability or timing of reload loss. Targeted acceptance still needed: real Web turn/manual save and campaign change followed by immediate reload; denied persistence/quota failure; two tabs sharing the same origin; a continuation acknowledgement racing a newer write to the same ring slot; new-session navigation while acknowledgement is pending; retry after timeout followed by late disk commit. Preserve state identity and generation checks rather than adding fixed delays.

The verifier depends on concrete IDBFS names (`/userfs`, `FILE_DATA`, `contents`) and exact stored bytes. This is an engine-upgrade compatibility seam. Verify it against each actual export template/browser supported; a native unit test cannot prove it. The code polls at animation-frame cadence and compares bytes on the main thread: measure large saves and suspended/background tabs before claiming a general responsiveness bound.

### A6 — Large local saves/thumbnails and long sessions lack an end-to-end resource budget

`SaveService.load_slot:68–74` reads the complete file before validation. `list_saves:98–118` parses every envelope, while `LoadScreen.build_screen:19–31` constructs every card and `_card:42–51` decodes every available thumbnail synchronously. Manual save numbering is unbounded (`SaveService:59–65`). Neither these paths nor `SaveSerializer.from_text:70–138` impose an input byte/entity/thumbnail-dimension budget. The parser, recursive canonicalization, presentation validation, reconstruction and invariants all run before a save is accepted. Validating shape/checksum does not bound work.

This is a local resource-exhaustion/responsiveness gap, not an identified network attack: normal UI selects local slots, not arbitrary remote files. Test many legitimate manual saves, a large malformed JSON file, oversized presentation strings and an oversized PNG; measure menu load/input responsiveness and memory. The BUILD_PROMPT's under-1-MB POC / under-5-MB 50-system targets (line 957) are useful acceptance targets, not enforced limits. Any limit must preserve existing valid saves and future presentation transport.

Long-lived simulation event history is appended at `sim/rules/events.gd:315` and serialized in `GameState` (`sim/core/game_state.gd:41,89,142–143`). Repeated events can grow it with playtime; determine practical bounds with continuation stress tests instead of deleting history opportunistically. This review does not establish a currently harmful growth rate.

### A7 — Deferred UI callbacks and reentrant signals need explicit ownership tests

The main guarded paths are good: `GameScreen.end_turn`, `resolve_turn`, and `next_event` check attachment/session, with `resolve_turn` now also checking the expected state identity; event choices capture session and overlay ownership. The continuation action checks old screen/state/session before and after await. The working tree also adds `_turn_resolving` to prevent recursive `Game.end_turn` from signal listeners.

A remaining source seam is `GameScreen._acknowledge:676–677`, which submits directly without the attachment/session guard used elsewhere. `ui_event` funnels tutorial/report acknowledgements there. A retained old callback might affect a newly loaded session with the same player/tutorial IDs; this adviser has not reproduced it. Flow screen layout rebuilds are deferred (`ui/screens/flow/flow_screen.gd:132–154`), and load/delete callbacks do not carry a session/screen generation. Check stale callback behavior explicitly before promoting these to confirmed defects.

Useful tests: queue a callback, replace the screen or load the same seed, invoke the retained callback and prove no current-session mutation; double-click End Turn/checklist; change layout while a modal callback is deferred; begin a new session from a turn-resolved listener. Current runtime listeners do not establish a harmful reentrant submit/undo path merely because those methods are callable.

## Runtime state and data-flow inventory

| Boundary | State / destination | Relevant contract and observation |
| --- | --- | --- |
| Boot / routes | `project.godot` autoloads; `AppRoot` title/campaign/briefing/game/debrief/load/settings/codex | AppRoot owns screen replacement and closes overlays. Showcase is debug-gated. Release smoke gate is the audit fix described in A1. |
| Turn commands | `Game.state`, `CommandQueue`, `TurnProcessor`, `TurnResult` | Queued preview and authoritative state are separate; session serial changes on resume. Simulation authority/invariant audit is Terra A's scope. |
| Outcome / continuation | `Objectives`, `ExpeditionContinuation`, `Game.continue_expedition`, `DebriefScreen` | Preview continuation preserves completion history without canonical campaign unlocks; asynchronous persistence must succeed before the live session changes. Loss remains possible later. Existing M2F evidence is in the feature report. |
| Save load | Local JSON -> envelope/schema/checksum/shape -> migration -> reconstructed state -> invariants | `sim/save/serializer.gd:70–138` rejects malformed shape and missing player. Checksum establishes consistency, not trusted authorship. Migration script path uses a numeric version under the fixed bundled migration directory. |
| Presentation | Independently versioned graphics strings -> `Worlds` / appearance store | Graphics are outside the simulation checksum, and unknown representations are transported. Do not trust them solely because gameplay validated. Separate visual-input validation remains necessary. |
| Progress / preferences | `user://campaign.json`, `user://settings.cfg`; Web `starfire_hearth.view_mode.v1` localStorage scalar | Contains scenario wins/legacy/difficulty and display/audio/accessibility/device settings. Settings clamp/type-check recognized values. No account identity is needed by these flows. |
| Save storage | `user://saves/*.json`, thumbnails; Web-backed user filesystem | Auto ring 10, checkpoint ring 6. Save slot paths use `validate_filename`. Save snapshots include game progress and player-entered colony names; thumbnails are images of the game viewport. Manual saves are unbounded. |
| Audio / voice | Bundled asset IDs or local synthesized fallback -> audio players | Fixed player pools (`app/audio.gd:47–58`), one voice player; `VoiceService` registers authored cue metadata and does not contact a speech service. Audio shutdown uses a bounded asynchronous drain. |
| Runtime diagnostics | Same-page `window.__m11*`, console; Web save verifier status | Probe telemetry includes state hashes, turn/entity/render metrics, viewport/device timing and UI geometry. No runtime transmission endpoint found; local exposure still merits release gating. |
| Offline tooling | `tools/`, tests, telemetry directories; CI artifacts | Developer outputs and local review servers are distinct from exported game behavior. Asset importer input review belongs to Terra A. Export excludes tools/test/docs/telemetry directories. |

## Privacy assessment

A source search across `app/`, `ui/`, `sim/`, project and export settings found no application `HTTPRequest`/`HTTPClient`, WebSocket/TCP/UDP transport, `fetch`/`sendBeacon`, shell/process execution or clipboard-export call carrying player data. The inspected browser bridges handle local settings, rendering/display capabilities, local test globals and local IndexedDB verification. No login/email/profile collection, remote voice/TTS request, analytics SDK, or unnecessary personal-data transmission was identified in those flows.

This is a constrained source finding, **not** a claim of zero network traffic: loading a Web game downloads its assets; hosting access logs, browser/engine behavior, all packaged third-party binaries and actual network requests were not independently audited here. Colony names and game thumbnails can contain user-authored content and should remain local unless a future explicit sharing/export action authorizes otherwise. The continuation verifier adds no duplicate PII store.

## Resource and lifecycle controls already present

- `ui/world/generation_scheduler.gd:78–107` validates dimensions and limits pending tasks to 32; native concurrency is two workers. Tasks carry epoch, owners and cancellation tokens. Navigation retires work without waiting on unfinished tasks; only shutdown drains unfinished workers (`:200–203`). Samples are capped at 1024. The Web region slice target is 18 ms plus one indivisible step, so it is not a promise of 60 fps.
- `ui/world/visual_resource_cache.gd` provides an estimated 64 MiB LRU target and releases unpinned entries. Pinned entries can exceed that target by design, and other GPU/CPU resources are outside its accounting. Do not describe it as a hard total-memory cap.
- `ui/world/visual_session.gd:8–22` bounds stored camera positions to 32 and clears transient state on restart. `Worlds` restarts scheduler/cache epochs with sessions; stale generated results are discarded.
- Overlay tooltip levels/toasts and renderer sampling arrays have explicit caps. Audio players are pooled; voice deduplication uses authored stable IDs, so a retained voice registry alone is not evidence of an accumulating per-turn leak.

A meaningful responsiveness check is repeated real navigation, mode changes, load/new-session replacement and 200+ continuation turns with memory/frame/input samples. A quiet headless run does not establish visual-worker behavior, browser main-thread latency, GPU texture lifetime or shutdown driver behavior.

## Recommended closeout order

1. Finish and verify the release probe gate with actual release exports and persistent storage seeded before opening hostile/accidental smoke URLs.
2. Close demonstrated command-authority, asset-intake and lifecycle defects from the assigned code audit owners; retain their negative regression tests and reproducible evidence.
3. Correct the balance orchestration/completeness gate; keep balance policy failures distinct from missing evidence.
4. Either fix silent persistence failure/deletion confirmation, or explicitly record them as remaining known limitations with narrow follow-up acceptance. Do not imply they were fixed by M2F's continuation verifier.
5. Report save-size/many-slots, cross-tab Web persistence, hardware/browser responsiveness and residual callback tests as coverage gaps until measured. Stop feature expansion; preserve PR9 and the separate PR10 review boundaries.
