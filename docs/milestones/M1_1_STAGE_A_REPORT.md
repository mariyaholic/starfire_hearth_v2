# M1.1 Stage A checkpoint — baseline and non-threaded 3D feasibility

**Status: functional validation passed; Stage A's performance gate remains open.**
Owner approval: 1 October 2026. Stages B–G have not started. No budget or acceptance
gate has been relaxed, and this report does not declare M1.1 complete.

## What now works

An opt-in 3D viewport is part of the normal M1 System screen. It shows the actual
Ember star, planets and owned ships, with the existing navigation, planet inspector
and command controls. Focusing Brume changes selection without mutating the game.
Its 512-pixel seeded surface refines across frames in the real non-threaded web
export. Clicking the existing Survey button queues the actual M1 command. Two real
turns complete it and produce the same state hash as a pure simulation replay on
native, desktop browser and phone-sized browser profiles.

This is the feasibility slice approved for Stage A. The normal route retains M1;
`?smoke=m11-stage-a` opens the integrated test route with persistence disabled.
The globe finish is provisional. Rich final art, integrated cities and unified
globe/terrain geography belong to later approved stages.

## Baseline and source boundary

The existing remote M1 branch `claude/starfire-hearth-build-cs2vb6` was revalidated
at `a160d9d334c59a2796b8c88e8eaca7f49b42c029`. A separate `git archive` snapshot supplied the original M1 tests and
web export. Work remains local and uncommitted in the detached M1 worktree; no new
branch, commit, push, merge, tag or deployment was created. The original M0/study
checkout remains preserved. `sim/` and gameplay `data/` have no changes.

Original M1: **165 tests / 3,129 checks**. M1 plus the prior incorporation study:
**170 tests / 3,236 checks**. Stage A: **174 tests / 3,315 checks**.

## Implementation

- Refactored the existing pixel baker into resumable jobs with bounded batches,
  cancellation and no partial result publication. Desktop synchronous baking drives
  the same implementation. No gameplay RNG, state or node access enters a bake.
- Kept generator version 1 because pre-refactor channel bytes still match: sixteen
  32-pixel type/seed vectors, sixty-four recorded hashes, plus batch/cancellation and
  64-pixel synchronous-versus-cooperative equivalence checks.
- Added a cooperative renderer backend with cheap initial previews, 128-pixel
  overview maps and 512-pixel focused maps. This slice requests 1 ms of generation
  work per frame, uses half-resolution rendering, reduced geometry, no shadows and
  reduced sky reflection resources. These controls do not yet enforce a hard deadline.
- Reused the normal System inspector and Survey command; corrected ray coordinates
  for the reduced viewport. Test-only telemetry records generation/upload time,
  cache estimates, draw counters, state hashes and real canvas control coordinates.
- Added reproducible native profiling, real-export browser interaction tests and
  before/after export-size measurement tools. Matching Godot 4.7.2 web templates
  were installed from the verified official release. Thread support remains disabled.

## Revalidation

| Check | Result | Evidence in the review package |
| --- | --- | --- |
| Full regression suite | 174 passed, 0 failed; 3,315 checks, 33 files | `evidence/tests.log` |
| Content/strings | 20 tables, 328 records, 1,374 strings; 0 errors/skips | `evidence/data.log` |
| Native integrated interaction/layout tour | 30 checks passed; seven captures; PC/compact at 100%/200% text | `evidence/native.json`, `evidence/native_verbose.log` |
| Native tour without PNG readback | 23 interaction/layout checks passed; separate memory measurement | `evidence/native_live.json`, `evidence/native_live.log` |
| Real exported 3D interaction | 24 checks passed, 0 browser/engine console errors | `evidence/web_desktop.json`, `evidence/web_phone.json` |
| Pinned M1 and current ordinary web routes | PC/phone/iPad passed, same one-turn hash `911cdd430061` | `evidence/pinned_m1_web.log`, `evidence/web_regression.log` |
| Two First Light bot playthroughs | Seeds 1/11 win at turns 79/71; 0 invariant problems; deterministic replays | `evidence/bot.log`, playthrough JSONs |
| Source hygiene | `git diff --check` clean; simulation/content diff empty | `package_verification.json` |

The native and two browser survey paths reach
`0e234243c5c9731fd30fd8f50a2ae8452d520f8f21db7ec94d7f9f63407d7f48`. Browser tests click actual canvas planet and Survey
controls; the test hook advances the two turns and compares their result. Phone
emulation exercises the responsive command route with pointer clicks/scrolling;
physical touch gestures, keyboard navigation and physical-device speed are pending.

The final verbose native tour has a clean shutdown. Other native runs intermittently
reported four ObjectDB instances/two resources still in use at process exit, including
the no-capture profile. These warnings are retained in the evidence and are unresolved;
passing interaction checks alone does not certify resource lifecycle.

## Budget measurements

MB below means decimal megabytes; MiB is used only where the approved cache budgets
use it. Browser numbers describe software WebGL in this cloud environment.

| Metric | Measured result | Gate |
| --- | --- | --- |
| Web export, gzip-9 per served file | 48.0 MB; pinned M1 47.3 MB; increase 0.743 MB | Pass: <150 MB total, <=25 MB visual increment |
| Native peak RSS, PNG capture tour | 451.2 MB | Exceeds 400 MB; includes screenshot readback |
| Native peak RSS, no PNG capture | 441.3 MB | Exceeds 400 MB on this software-GL configuration |
| Pinned M1 native System/layout tour | 373.9 MB | Baseline context; tour omits 3D refinement, captures and Survey replay |
| Focused texture cache estimate | 2.83 MiB | Inside proposed 16 MiB low-profile cache allowance for this slice |
| First renderer frame, desktop/phone web | 182.2 / 190.2 ms | Inside preview target; excludes engine boot/download |
| Cooperative generation p95, desktop/phone web | 3.5 / 3.8 ms | Exceeds <=2 ms target |
| Cooperative generation max, desktop/phone web | 18.2 / 15.6 ms | Outliers remain |
| Texture upload p95, desktop/phone web | 1.8 / 9.1 ms | Upload still synchronous; needs staged work |
| Software frame p95, desktop/phone web | 126.7 / 112.9 ms | Does not meet 60/30 fps targets; actual GPU/mobile pending |
| Focused draw calls, desktop/phone web | 87 / 50 | Under proposed low limit in this scene |
| Reported render primitives, desktop/phone web | 9,360 / 8,236 | Small slice; largest colony/complete scene not measured |
| Headless desktop simulation end-turn p95, seeds 1/11 | 48.18 / 45.17 ms | Under 300 ms; active-renderer latency still needs later profiling |

Native RSS uses Linux `RUSAGE_CHILDREN` in a fresh profiling process and includes
Godot plus the software OpenGL driver. The no-capture run suppresses image readback
while retaining focus, command resolution and layout changes. The pinned M1 tour
uses the same window/text profiles but is not an allocation-isolating identical
workload, so its difference is not claimed as measured renderer memory.

Godot static-memory counters exclude driver/GPU allocations; the focused cache is
a conservative RGBA+mipmap estimate, not a GPU measurement. Web release static
memory counters return zero here. CDP browser/renderer/GPU RSS is recorded separately
and includes browser/software-driver overhead. It does not establish game-only
WASM/GPU memory or mobile certification. Timing is indicative cloud evidence;
the desktop browser run overlapped the final headless regression suite briefly.

## Open gate and next work

Stage A remains open because memory and generation/frame timing have not met the
approved limits. No budget change is requested or assumed. Next Stage A work is to
profile persistent allocations and shutdown references, stage texture upload, reduce
rendering work and measure on representative GPU hardware where available. Missing
hardware evidence stays pending.

The slice still recreates its renderer after orders/settings refreshes and restarts
refinement. Byte-budgeted shared caching, persistent host/controller ownership,
epoch/revision-based stale-job rejection and lifecycle stress tests are Stage B.
They have not been presented as complete. Galaxy integration, saves/region anchors,
city incorporation, final art, full exports and actual device validation remain
Stages C–G. Prior city-study assets are retained, but browser city feasibility was
not certified by this System-only slice.

## Review and reproduction

Open the package's `index.html` for thirteen actual Godot/browser captures. Its
`source.patch` is the complete uncommitted study-plus-Stage-A diff against pinned
M1, including assets; patch verification is recorded separately. `web/` contains
the local release export in the ZIP. Serve it locally and open
`index.html?smoke=m11-stage-a` for the opt-in test route. Ordinary `index.html`
uses the existing M1 game route. No public endpoint was deployed.

See [`../M1_1_CLOUD_SETUP.md`](../M1_1_CLOUD_SETUP.md) in the source tree for commands.
The package includes `cloud_setup.md` and the pinned-M1 memory/Chromium helpers so
the baseline can be reproduced without altering the original M1 source.
