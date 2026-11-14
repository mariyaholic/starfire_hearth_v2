# Independent audit review — 14 November 2026

Reviewer: independent Sol reviewer/judge. Baseline: `bb6e993` on
`feat/expedition-continuation`, following the accepted M2F increment. PR #9 was
frozen at `90e3db5` during this work; the owner subsequently merged that exact
head externally into main (`4ac2cd0`). The team did not perform that merge.
Continuation/audit work remains separately reviewable in PR #10; its retargeting
and final validation are recorded by the lead. This audit adds no gameplay features.

**Independent disposition: the reviewed audit fixes are accepted on source and
focused regression evidence, with the residual boundaries listed below.** The
lead's consolidated suite/export record is maintained in [VALIDATION.md](VALIDATION.md).
This is not permission to merge/deploy or a universal security/privacy certificate.
The two source authors own fixes; this reviewer edited only this document.

The preceding M2F baseline passed 390 tests / 14,907 checks under Godot 4.7.2.
That result is not evidence that subsequent audit changes pass. Independent M2F
checks covered 14 continuation tests / 130 checks, golden hashes, native controls
and the corrected Web acknowledgement/reload regression.

**Findings and disposition**

| ID | Boundary and consequence | Evidence status | Disposition |
| --- | --- | --- | --- |
| R1 | Mutable command aliases could change execution after preview; a player-sourced foreign-empire order could also validate against its own foreign colony. | Authors reproduced both paths. Reviewer independently ran the authority suite, including mutation of submitted/exported objects and foreign player versus trusted AI inputs. | Fixed: registry snapshots at both queue boundaries; matching actor rejection in queue, app facade and player processor path. |
| R2 | Release `?smoke=begin` could start Scenario 1 and write `auto_2.json`/thumbnail into normal browser saves. | UI author reproduced release Chromium/IndexedDB writes. Reviewer opened the [before](screenshots/release-before-smoke.png) and [after](screenshots/release-after-guard.png) captures. A screenshot alone does not prove the storage write. The author's release sentinel test preserved exact slot bytes; debug smoke still advanced as intended. | Fixed activation boundary: probes require a debug build. Release and debug exports/tests are separate; debug fixtures still require an isolated profile/origin. |
| R3 | Checksum-valid unknown event chains/steps could load into a blocking overlay with zero choices. Invalid active ship tasks/hulls, designated-player flags and unnormalized growth could also survive the checked boundary. | Reviewer identified the event gap; author reproduced it with a recomputed checksum. Independent authority checks cover rejection plus valid pending-event/task loading and growth-loop prevention. | Fixed named semantic gaps. This is not exhaustive validation of every possible content/entity combination. |
| R4 | Direct terminal processing, a reentrant turn listener or an old checklist confirmation could advance a game again. | Source/reproductions and independent authority/game-screen tests. | Fixed recognized-scenario absorption and app terminal/busy/reentrant/state-identity guards. The committed uncatalogued `test` fixture deliberately retains its historical post-outcome golden behavior; no silent rebaseline. |
| R5 | Autosave failure was silent; ordinary Web manual-save success preceded confirmed persistence. | Independent game-screen/save-service tests cover warning timing and delayed/stale manual acknowledgement. Reviewer opened the actual native [post-turn warning](screenshots/native-after-autosave-warning.png): warning remains readable with the report open. The scripted production-verifier browser result shows two overlapping matches and one timeout, zero remaining operations/page errors. | Fixed autosave error warning and Web manual acknowledgement. Ordinary Web autosave durability remains a known gap; see residual boundaries. |
| R6 | Detached load/delete/advisor callbacks could affect a newer route/session; save deletion was immediate. | Independent flow/game-screen tests and source guards. Reviewer inspected actual phone-200 [confirmation](screenshots/native-delete-confirmation-phone200.png) and post-delete state: `manual_1` disappeared while the independent fixture save remained; both actions fit. | Fixed targeted callbacks and save confirmation. Confirmation checks attachment, session, directory and original bytes; cancel, replacement and detached-confirmation tests preserve the file. No claim that every callback in the application is now capability-secure. |
| R7 | Authored decimal overflow could wrap a positive amount; negative resource costs were accepted. | Independent authority/fixed-point tests cover signed limits and rejection, with clean content validation. | Fixed pre-conversion decimal bounds and nonnegative resource maps; signed effects remain separate. Arbitrary in-memory arithmetic is not certified against all overflow. |
| R8 | Asset batch metadata traversal could write a contact sheet outside the report directory, including in supposed no-write check mode; malformed batches could evade a failure exit. | Author's actual temporary ZIP reproduction; reviewer inspected the fix and independently passed seven Python regressions. | Fixed bounded batch metadata, no-write check mode, failure status and pre-read ZIP ceilings: 1 MiB manifest, 256 MiB per asset, 1 GiB referenced inputs, 4,096 entries. Third-party media decoders remain outside this proof. |
| R9 | Bare shell `wait` could hide a failed worker; incomplete telemetry groups could pass advisory CI. | Adviser reproduced the shell mechanism. Reviewer independently ran child-failure/reaping tests and telemetry coverage/CLI regressions. | Fixed per-PID status aggregation and explicit run/group/seed/scenario/replay completeness. Balance thresholds remain a separate decision; remote CI was not rerun by this reviewer. |
| R10 | Stale allocation counters could overwrite a live capital; an exhausted signed counter produced a negative ID. | Author reproduced both, including legal colonisation from a checksum-valid stale-counter save. Independent final authority suite covers capital preservation, nested queues/events/effects and exhaustion. | Fixed deterministic live-ID skipping and restart before signed overflow, without schema or ordinary ID-sequence changes. |
| R11 | Campaign writes could truncate the previous file or fail without feedback. | Independent campaign and flow regressions cover a blocked pending path, unchanged prior file, retained live win, later retry and warning after debrief. | Fixed checked temporary write/flush/rename and source/revision-guarded deferred warning. Exact Web campaign durability is not established. |
| R12 | A checkpoint turn captured/encoded the viewport twice. | Reviewer read the author's actual-render logs: the redundant second operation took 17–33 ms across ten llvmpipe samples. Updated fixture wrote identical nonempty auto/checkpoint PNG bytes using one capture. | Fixed reuse of captured bytes. This establishes removal of redundant work, not an overall frame-rate or hardware performance guarantee; the disposable profiling harness reported resources in use on exit. |

No finding above is described as a remotely exploitable vulnerability without an
actual input path and reproduction. Game state and preview objects remain mutable
by design: trusted callers must observe the read-only contract. Command snapshots
do not provide memory isolation against arbitrary in-process code.

**State-machine inventory and coverage**

| Area | Transitions and important invariants | Existing evidence inspected / next acceptance |
| --- | --- | --- |
| Application routing | Title → campaign → briefing → game → report/events → debrief; load/retry/checkpoint and canonical legacy/unlock rules. Removed screens must not act on a newer session. | `test_flow_screens`, graphics save routes, lifecycle regressions, M2F native/Web controls. Independently re-review stale callback fixes. |
| Session and command bus | Base state → queued preview → Undo → authoritative turn; session serial and continuation generation; terminal/busy/reentrant requests. A queued order must be an immutable snapshot. | Command/authority, processor purity/phase/golden, M2F delayed acknowledgement and app reentrancy/state-identity regressions. |
| Economy and colony work | Paid construction → countdown → completion, cancel/refund, rush, governor budget/veto; production → upkeep → market/caps; growth/famine/autonomy thresholds. | Construction, economy, population/stability, governor, ordinance and economy-state-machine tests; S1 deterministic policy traces. No new balance verdict. |
| Research | Hand → selected card → banked progress → completion/new hand; rerolls/costs; already-funded card completes at the next phase, even at zero income. | Research/ETA/banking tests, golden hashes, repeated post-win technology trace. |
| Fleets and civilian tasks | Idle → route/progress → arrival → discovery; local task countdown; frozen malformed route; auto intent/manual override; Stop-auto versus Stop-next; Undo and save/resume. | Travel/auto/stop/ship tests; screenshot-backed M2A–M2F OS control reports. No combat/transit-beacon coverage claim. |
| Events and objectives | Trigger → pending/scheduled → choice/cost/reward/memory → timed modifiers; optional goal progress; defeat before victory; post-win continuation suppresses repeat victory. | Event/objective/preview/Shroud/continuation tests and actual discovery controls. R3 adds malformed checked-save rejection. |
| Save/load | Checked JSON types/checksum/migrations → semantic validation → live session; atomic temporary-file rename, ring/checkpoint/manual policy; optional graphics transport/future fallback. | Save-boundary/migration/envelope and new invalid-state tests; ring/error/confirmation tests; exact local continuation/manual readback, including a scripted overlapping-verifier browser fixture. |
| Presentation | Snapshot fog disclosure → renderer patch; 3D/Strategic/immersive transitions; viewport input; text scaling, settings preview/apply/cancel and workspace geometry. UI must not compute simulation yields. | Existing UI/audit/input/appearance/transport tests and actual screenshots. New visual/performance claims need rendered evidence. |
| Resources and shutdown | Owner pins/epochs → queued/running/cancelled/retired generation → delivery; session restart/cache eviction; voice replacement/mute/finish; graceful audio and quit. | Scheduler/cache/retirement/voice tests and prior graceful-shutdown logs. Actual driver/VRAM/audio behavior remains platform-limited. |
| Content and developer tools | Closed content IDs/effects → validation → runtime lookup; asset batch validation/conversion → delivered manifest; explicit review probes must not mutate release user saves. | Data validation, overflow/negative-resource rejection, seven asset-intake regressions, child/matrix coverage and separate release/debug browser evidence. |

This is a subsystem inventory and risk-based review, not exhaustive exploration
of every possible combination of state, input order or malformed file.

**Privacy and security data flow — initial source assessment**

The runtime scan covered `app/`, `sim/`, `ui/`, `project.godot` and export settings.
It found no application HTTP client/request, upload/analytics beacon, multiplayer
transport, microphone capture, OS/cloud TTS, account login, contacts access,
username lookup or stable device-identifier call. The voice service plays local
manifest audio clips; unavailable clips stay unavailable. These are bounded
source observations, not proof about the engine binary, browser, operating
system, hosting infrastructure or dependencies.

The reviewer also read a bounded [normal release browser request record](playtest/web-baseline/network-summary.json):
seven asset/blob GETs on the local origin, no request-body payload and no external
endpoint observed in that window. The associated 21-action capture later ended
on a screenshot timeout; it is not a complete passing playthrough or exhaustive
network audit. That runtime sample supports, but does not replace, the source
data-flow assessment.

| Data | Read or persisted | Purpose / transmission observed |
| --- | --- | --- |
| Gameplay state | Seed/date, stocks, map/fog, colonies, player-entered colony names, commands' resulting state, research, events, objectives and flags in local `user://saves/*.json`. | Resume/deterministic simulation. No runtime upload path found. User-entered names can contain personal text even though none is requested. Queued unspent orders are intentionally outside the save. |
| Save images and metadata | App viewport thumbnails, file modification times, scenario/seed/turn summaries. | Save selection and ordering. Thumbnail reads the Godot app viewport, not the user's desktop. No upload path found. |
| Campaign | Difficulty, canonical wins and chosen legacies in `user://campaign.json`. | Local progression. Preview remains excluded from canonical unlocks. |
| Device preferences | Text/UI size, motion/contrast, volumes/mute, graphics settings, native window dimensions/position/monitor index in `settings.cfg`. | Presentation/accessibility. Browser `localStorage` contains the scalar command/immersive view preference, not a duplicate full save. |
| Workspace/appearance | Immersive panel geometry/state in local config; deterministic presentation profiles/anchors/road/orbit recipes in optional save-envelope strings. | Preserve player layout and visual continuity. Unknown presentation payloads are transported, not executed. |
| Browser capabilities | Viewport/screen size, pixel ratio, pointer/touch capability, fullscreen/context-loss status and filesystem persistence availability. | Choose supported controls/rendering and recover graphics. No application transmission found. |
| Save verification | A transient expected envelope and read-only checks of existing IndexedDB files; at most eight independent verification operations. | Confirm exact local committed bytes before continuation/manual success. No extra persistent full-save copy or network request. Timeout is explicitly unconfirmed; each operation cleans its own polling/connection state. |
| Diagnostics/developer evidence | Layout/debug messages, engine logs and opt-in local probe metrics. | Development/debugging. Release probe isolation is R2; developer automation may capture screenshots, but this is separate from player runtime collection. |

Browser asset fetching is necessary to load the exported application. Hosting
access logs, browser storage eviction, extensions, OS crash reports, and behavior
inside shipped engine/media dependencies are outside the reviewed application
source. A save checksum detects alteration/corruption; it is not authentication
and does not make a user-supplied save trustworthy. Semantic validation and
resource limits remain necessary.

**Independent verification ledger**

All Godot runs below used `/workspace/.starfire-setup/bin/godot`, exact
`4.7.2.stable.official.ed1daf0bf`, in isolated userdata directories. These are
focused checks, not a duplicated consolidated suite.

| Check | Independent result |
| --- | --- |
| `--filter sim_audit_authority` (final allocator/identity changes) | 16 tests / 76 checks, pass |
| `--filter game_screen` | 22 tests / 289 checks, pass |
| `--filter flow_screens` (including campaign warning) | 6 tests / 106 checks, pass |
| `--filter campaign_progress` | 6 tests / 31 checks, pass |
| `--filter save_service` | 4 tests / 60 checks, pass |
| `--filter test_fx` | 5 tests / 29 checks, pass |
| `--filter test_golden_hashes` | 4 tests / 6 checks, pass; lead consolidation also covers the final allocator revision |
| `--filter telemetry_coverage` | 3 tests / 13 checks, pass |
| Python asset-intake security tests | 7 tests, pass |
| `bash tools/test_wait_all.sh` | Failed child detected, all children reaped, success case passes |
| Production-verifier browser fixture | Author executed; reviewer read [result](fixtures/web-verifier-result.json): two matches, one timeout, zero pending operations and page errors. Scripted fixture, not manual gameplay. |

The final release also passed an actual mouse-driven Menu → Save → first visible
green “Game saved” toast → same-script immediate page reload, then Title Continue
and explicit manual-slot Load. The initial S1 turn-2 snapshot came from earlier
actual normal play and was seeded before this disposable run; no runtime game
methods or smoke hooks drove the actions. Reviewer opened the acknowledgement
crop, reloaded title and active-game frames, then independently verified that
persisted `manual_1` equals the initial authoritative dictionary and its canonical
checksum. The browser report records no page errors and no added post-ack grace
wait. Its coarse first-success sample is not an exact save/input-latency measure.
The post-load frames still show a gray background-generation placeholder, so
they establish active UI/date restoration, not completed terrain rendering.
The playtester retains the original captures, input timeline and storage records;
the [actual-control report](PLAYTEST.md) links the packaged evidence.

The source authors' detailed reproductions are retained in [SIM_AUDIT.md](SIM_AUDIT.md)
and [APP_AUDIT.md](APP_AUDIT.md); baseline advisory leads are in [ADVISORY.md](ADVISORY.md).
The lead owns consolidated source digests, full tests, export status and actual
control captures in [VALIDATION.md](VALIDATION.md) and [PLAYTEST.md](PLAYTEST.md).
The reviewer read the final logs/manifest, without rerunning the entire suite:

| Final consolidated check | Recorded result |
| --- | --- |
| [Full suite](validation/tests.log) | 418 passed / zero failed / 15,038 checks / 74 files; 91.9 seconds |
| [Data](validation/data.log) | 20 tables / 391 records / 1,587 strings; zero errors or skipped checks |
| Source consistency | Matching before/after test digest `7b1f583c2fe00acdc18bc74bd08eca8245c769f0e424b85c88a7ae75a136e79e` |
| [Asset audit](validation/asset_audit.json) | 367 checks / zero failures |
| [Exports](validation/build_manifest.json) | Web, Linux and Windows release exports plus a separate debug Web export succeed |
| [Release URL guard](validation/browser-release.log) | Existing `auto_2` bytes preserved; smoke did not run |
| [Debug browser smoke](validation/browser-debug.log) | Desktop, simulated phone and iPad profiles pass; turn-2 hash `911cdd430061` matches native |
| [Six short bot runs](validation/telemetry_report.log) | Replayed deterministically; zero invariants; strict expected scenario/group/seed/replay coverage passes |

The exported source aggregate preceded one test-only correction in
`test_stop_fleet.gd`: direct validation still checks foreign fleet ownership,
while the player queue now checks actor authority first, with an additional
unchanged-preview assertion. Reviewer inspected this strengthening. The lead's
manifest records the unchanged production/tools digest and the aggregate
reconciliation; no product source changed after export.

The 60-turn bot smoke is **not a balance pass**. `everything_matters` and balanced
Normal `winnable` failed advisory thresholds; Story winnability and pacing were
not measured by that short matrix. The report preserves those failures/SKIPs.
A successful export is not proof of native execution on that platform. Earlier
M2F tests are not substituted for final audit checks.

**Residual failure points and coverage limits**

- Ordinary Web autosaves still acknowledge virtual filesystem writes, without
  the exact-byte barrier used by continuation/manual saves. Immediate page close
  can race browser persistence. Campaign writes are atomic/error-checked locally,
  but do not have exact Web persistence acknowledgement. Storage denial, eviction,
  quota exhaustion, late completion and multi-tab writers remain separate risks.
- Settings-file write failures remain unsurfaced. This report does not claim that
  every preference or progress change survives disk/browser failure.
- Save/list/thumbnail decoding, manual-slot counts, event history and arbitrary
  opaque presentation strings lack an end-to-end byte/latency budget. No new
  arbitrary cap was introduced that would invalidate supported saves. Existing
  schema/reference checks do not prove bounded work for all hostile files.
- The synthetic unknown `test` scenario preserves historical terminal simulation
  semantics, and unknown synthetic scenarios can still pass generic serialization.
  Supported playable scenarios and the app facade have the new terminal guards.
- Cache accounting is an estimate, with a 64 MiB target that pinned entries may
  exceed; it is not a total GPU/process memory ceiling. Scheduler bounds and
  cancellation/source tests do not establish a universal frame-time limit.
- The thumbnail profiling harness reported four leaked ObjectDB instances and
  two resources at exit. Its timing/PNG evidence is not clean-shutdown evidence
  or proof of a production leak. Graceful retirement/audio tests and actual quit
  evidence are separate.

Native Linux/Xvfb software OpenGL and Chromium software WebGL evidence are
available. Synthetic initial fixtures, automated command traces, headless checks
and actual OS/touch controls remain separately labelled. Physical phones,
hardware GPU/driver behavior, native Windows/macOS execution, audible output and
long-duration/multi-tab storage behavior have not been certified by this review.
No merge, deployment or broad privacy/security certification is implied.
