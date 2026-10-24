# M1.1 Stage G validation report

**Measured 2 October 2026** on the existing M1 checkout, detached at
`a160d9d334c59a2796b8c88e8eaca7f49b42c029`. The campaign and Web tests used
Godot 4.7.2, Chromium with software SwiftShader, and native Xvfb/Mesa llvmpipe.
The measurements below are cloud evidence, not representative GPU or mobile-device
certification. No balance edits were made.

## Verified locally

| Gate | Result | Evidence |
| --- | --- | --- |
| Playable First Light route | **459 checks, 0 failures.** The real title, campaign, briefing, research, event, survey, founding, outpost, construction, earned Advanced Districts unlock and upgrade, save/load, and win debrief were exercised through production screens and the Game command bus. Seed 1 won at turn 79; all 80 resolved turn hashes matched BotRunner. | `build/stage_g/campaign/verification.json`, `run.log`; fresh captures are listed in `verification.json`. |
| Command / Immersive parity | The same settled, current-finish city was captured in both layouts at turn 35. Toggling the production layout control retained renderer, camera, simulation hash and geometry. The campaign and lifecycle runs use the same game state and command path. | `campaign_turn_35_3d_command.png`, `campaign_turn_35_3d_immersive.png`; campaign verification. |
| Automated regression suite | **221 passed, 0 failed, 12,035 checks, 41 files.** Includes save, data, boundary, golden, responsive UI and the new cooperative/worker scheduler-suspend tests. | `build/stage_g/validation/tests.log`. |
| Data and authored visual assets | Data: **20 tables, 328 records, 1,408 strings, 0 errors / 0 skipped checks.** Asset manifest/catalog audit: **367 checks, 0 failures**. | `build/stage_g/validation/data.log`, `build/stage_g/asset_audit.json`. |
| Bot telemetry and pinned M1 comparison | **100 scenario runs:** 20 seeds each for Balanced, Economy, Turtle and Random-Legal on Normal, plus 20 Balanced Story runs. The strict report's invariant, balance, and simulation-turn performance gates pass: 0 invariant problems; end-turn resolver p95 **47.48 ms / 300 ms**; no hoarding **0/40**; all scoped content used; Normal Balanced **15/20**, Random-Legal **0/20**, Story **20/20** wins; median Balanced win turn **78** (expected 70); median dead-turn share **5%**. Its combined deterministic-replay check is **SKIP** because these 100 inputs were not replayed in that report. All 100 current/baseline runs have **8,789/8,789 per-turn hashes and outcomes matched**. Six separate 60-turn replay jobs passed determinism. | `build/stage_g/validation/telemetry_report.log`; baseline/current JSON runs and six replay JSON files are in the review package's `evidence/telemetry/`; the reproducible comparison is `evidence/telemetry_comparison.json`. The bot end-turn timing is simulation-only; it does not measure player input-to-render latency. |
| 100-cycle lifecycle | **1,106 checks, 0 failures.** The run exercised map contexts and 100 real layout switches, 66 selections, 12 queue-submit/Undo rounds, Load, new game, accessibility settings, cancellation of a running 2048 px continental job and teardown. Stale publications **0**. Settled endpoints each had **267 nodes / 0 orphans**, one active cache pin, 0 pending/retiring jobs; teardown had **28 nodes / 0 orphans**, no jobs and no pins. Static memory rose 68.34→70.14 MB (70,142,738 bytes final); cache estimate 4.17→9.76 MB within the 64 MiB budget. | `build/stage_g/lifecycle/verification.json`, `run.log`. |
| Native lifecycle process memory | RSS peak **968,921,088 bytes** across Xvfb, Godot and descendants. Timestamp-aligned settled RSS rose **935,288,832→965,328,896 bytes** (+30,040,064 bytes) across warmup to cycle 100; the measurement stayed within the harness's documented 140,293,324-byte endpoint tolerance. It includes software GL and exceeds the 400 MB target. | `build/stage_g/lifecycle/verification.json` → `whole_process_memory`. |
| Browser interaction on the exported Web build | **127 checks, 21 captures, 0 browser errors** across touch-phone and desktop profiles. Actual canvas input covered layouts, selection, pinch/orbit/pan, construction preview, Build/Cancel/Undo, turn resolution, save/load, page destruction/reload, quality and portrait 200% text. | `build/stage_g/web_interaction/verification.json` and its listed PNGs. |
| WebGL-loss fallback | On a live exported game, the notice remained hidden while healthy. An actual `WEBGL_lose_context` loss exposed the accessible 48 px Reload control, blocked canvas input, suspended and drained generation jobs, preserved the simulation hash and stayed paused after a `webglcontextrestored` event. The recovery smoke reloaded and restored the isolated manual save fields. **The 3D scene remained black after restore**, so automatic Godot GPU-resource reconstruction is Pending; use Reload. The checked reload used an isolated manual save, not proof of latest-autosave durability. | `build/stage_g/recovery/verification.json`, four listed screenshots and `profile_run.log`. |
| Web recovery-test process memory | RSS peak **2,201,718,784 bytes** over 38 samples in the 19.5 s recovery test. This sums the Python test runner, Playwright driver and Chromium/SwiftShader descendants during recovery and screenshot work. It is not WebAssembly heap, app-only memory, or physical GPU RAM. | `build/stage_g/recovery/verification.json` → `web_process_memory`. |
| Web / Windows / Linux RELEASE exports | All three exports completed from the release presets. Web export includes the inline recovery listener with no separate-script dependency. Web files total **88,726,668 bytes** raw and **54,719,709 bytes gzip**. Exported Linux binary ran for a 20-second Xvfb smoke with no engine/script errors. Windows export is structurally present; Windows runtime was unavailable. | `build/stage_g/web/`, `build/stage_g/windows/StarfireHearth.exe`, `build/stage_g/linux/StarfireHearth.x86_64`; export logs and `linux_runtime.log`. |

The current exported browser tour's last 512 frame intervals were mixed with UI actions,
scene generation, screenshots and save/load. Their p95 values were **1,106.3 ms on the
phone profile** and **918.4 ms on desktop** (maxima 3,828.3 and 3,529.6 ms). These are
not steady-view FPS figures. The planned 16.7 ms desktop / 33.3 ms low-phone frame
budgets and user-visible input latency remain unverified on this software renderer and
are carried as optimization debt. The bot's 47.48 ms p95 measures simulation turns
only. The 6 ms Web generation slice also exceeds the proposed 2 ms target. The
Owner-authorized temporary performance overrun remains documented; no gameplay tuning
was used to compensate for render cost.

## Reused prior verified evidence

Stage G reuses the completed F.1 **319 native / 127 browser checks**, including 100% /
200% layouts, touch, keyboard, renderer retention, management contexts and graphics
save/load, from `docs/milestones/M1_1_IMMERSIVE_VIEW_REPORT.md` and the existing
`/workspace/starfire_3d_proposal/m1_1_immersive*` artifacts. The earlier D/E/F
reports and checks continue to support permitted Intel/topology, catalog/geography,
legacy-save, archived-writer and art-provenance claims; they are not relabeled as new
Stage G reruns. The independent comparison confirms all 62 data files and all golden
files remain unchanged against pinned M1. `sim/save/serializer.gd` changes only
graphics-envelope transport; `presentation_envelope.gd` is the separate schema.

## Pending gates and limitations

- Actual Android Chrome, iOS Safari and representative discrete/mobile GPU tests,
  memory/performance profiling, device-specific quality selection and hardware texture
  compression were unavailable. Emulated Chromium profiles are reported separately.
- Godot's scene/renderer resources did not produce visible pixels after the simulated
  WebGL context-restored event. The shell guidance, input block, generation suspension
  and reload/manual-save route work; automatic GPU-scene recovery remains Pending.
- Windows is export-verified only; no Windows runtime was available. Linux runtime was
  smoke-tested locally, and Web was run through Chromium software WebGL.
- Neither GitHub-hosted workflow was run. Local equivalents passed. The ordinary CI
  workflow includes the asset catalog audit; the new manual `workflow_dispatch`
  checkpoint also defines campaign, 100-cycle lifecycle, three release exports,
  exported Web interaction/recovery and evidence upload. Hosted execution remains
  Pending; deployment was not triggered.
- The campaign route is a deterministic BotPolicy-driven production-screen and
  command-bus walkthrough, not a human Owner playtest. Owner art and playtest acceptance
  remain Pending; 3D counts and captures do not substitute for that review.
- Stable-view performance and real input-to-render latency on target hardware remain
  Pending. The mixed browser p95 and software-renderer memory peaks above identify the
  optimization work to do next.

The Stage G report and evidence do not constitute M1.1 acceptance or a release. The
checkpoint remains local and uncommitted on the pinned M1 lineage.
