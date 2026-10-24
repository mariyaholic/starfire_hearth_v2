# M1.1 checkpoint report

**Evidence status as of 2 October 2026.** Implementation and local Stage G
revalidation were performed on the existing M1 lineage at pinned parent
`a160d9d334c59a2796b8c88e8eaca7f49b42c029`. No branch, commit, push, merge, tag or
deployment was created. This report records technical evidence; Owner acceptance
and several hardware gates remain open.

## Evidence matrix

| Area | Status | Evidence and limits |
| --- | --- | --- |
| A–F.1 implementation and verification | **Verified locally** | Stage reports A through F and the F.1 report cover the preserved implementation, save compatibility, 100% / 200% accessibility layouts, input, catalogs and renderer. |
| Regression, data and art manifests | **Verified locally** | Final suite: 221 tests, 12,035 checks, 41 files, zero failures. Data: 20 tables / 328 records / 1,408 strings, zero errors/skips. Asset audit: 367 checks, zero failures. |
| First Light campaign | **Verified by deterministic production-screen harness** | Real title-to-debrief path with event, research, survey, founding, outpost, construction, earned upgrade, save/load and victory; 459 checks, 80 resolved-turn hashes matched. Bot-driven automation is not human Owner playtesting. |
| Simulation regressions | **Verified locally** | The strict 100-run telemetry report passes its invariant, balance and simulation-turn performance gates; its in-report deterministic replay check is marked SKIP because inputs were not replayed. The separate current/baseline comparison matched 8,789 of 8,789 turn hashes/outcomes, and six 60-turn deterministic replays passed. |
| 100-switch lifecycle | **Verified locally on software GL** | 1,106 checks, 0 failures, no stale publications or endpoint node/job/orphan trend; teardown returned to 28 nodes, 0 jobs and 0 cache pins. RSS peak 968,921,088 bytes includes Xvfb/Mesa llvmpipe and exceeds the 400 MB target. |
| WebGL loss fallback | **Reload fallback verified; automatic renderer recovery Pending** | Actual loss exposed the notice, blocked input and suspended/drained generation. The restored-context event left the scene black. Reload and isolated manual-save fields were verified. The checked save is not evidence of latest-autosave durability. |
| Web, Windows and Linux release exports | **Verified locally** | Three release exports built. Web was exercised in Chromium software WebGL. Exported Linux ran for a 20-second Xvfb smoke with no engine/script errors. Windows runtime was not available. |
| Hosted CI | **Pending** | Local equivalents passed; neither GitHub workflow was triggered. Standard CI includes the asset manifest audit. A separate manual `workflow_dispatch` checkpoint defines the campaign, 100-cycle lifecycle, three exports, exported Web interaction/recovery and evidence upload. |
| Target device / GPU performance | **Pending** | No physical Android/iOS or representative GPU was available. Chromium simulation is not mobile-device evidence. Stable-view frame budget, target-device input latency, compression and device RAM remain unverified. |
| Owner art review and playtest | **Pending** | Production reference captures and catalog checks are ready for review; no Owner acceptance or human playtest is claimed. |

## Measured cost and scope

The Web release totals **88,726,668 bytes raw / 54,719,709 bytes gzip**. Bot `end_turn_ms`
is a simulation-only measure: p95 **47.48 ms** across 8,789 turns against the 300 ms
desktop budget. Browser final 512-frame interaction windows had mixed automation/render
p95 **1,106.3 ms phone / 918.4 ms desktop**; those windows include page actions,
generation, screenshots and saves and are not steady-view FPS. The Web 2 ms generation
slice and native/Web process RSS targets are optimization debt. Temporary numeric
performance overruns remain authorized and were not addressed with balance edits.

The complete Verified/Pending discussion, 100-cycle memory trend, browser and recovery
details, saved evidence paths and optimization limitations are in
[the Stage G report](M1_1_STAGE_G_REPORT.md). The runnable checkpoint, source diff,
phone-readable gallery, measurements and checksums are in the local review package
`/workspace/starfire_3d_proposal/m1_1_checkpoint/m1_1_stage_g_review.zip`; the separate
PDF and review folder accompany it. These artifacts do not constitute M1.1 acceptance
or authorize publication.
