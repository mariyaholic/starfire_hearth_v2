# M1.2 pause inventory

**Historical inventory from 3 October; superseded after resumption on 4 October.**
Current implementation and checks are in [M1.2 progress](M1_2_PROGRESS.md) and the
[D–G revalidation report](M1_2_D_G_REVALIDATION_REPORT.md).

Paused at the Owner's request on 3 October 2026, after Stage C finishes.
No further stage is running. Continue on the existing M1 lineage; no new branch,
source push, tag or M1.2 release was created.

| Stage | State | Result or remaining work |
| --- | --- | --- |
| A | Complete for progression | Separate versioned road/orbit presentation components; actual archived M1.1 writer roundtrip; overlay/unknown-extension preservation and future-authority protection. [Report](M1_2_STAGE_A_REPORT.md). |
| B | Implemented and locally revalidated | Shared terrain-aware streets, external entrances, junctions, smoothing, cached refreshes and explicit old-save road upgrade. Five fresh production captures and 28 native checks. [Report](M1_2_STAGE_B_REPORT.md). |
| C | Implemented and locally revalidated | Native modes/monitor/window sizes, borderless desktop, manual sizing, maximize/restore, Apply/Keep/Revert countdown and recovery, independent UI/text scaling, supported graphics settings and unknown-settings retention. [Report](M1_2_STAGE_C_REPORT.md). |
| D | Draft preserved; implementation gate pending | Finish simultaneous management windows/docks, persistent essential controls, input/focus/Escape handling, responsive layouts and device preference persistence; revalidate real orders and take desktop/phone captures. |
| E | Unstarted | Optional character voice registry/service, Voice bus/controls, safe missing-asset behavior and dialogue lifecycle/localization checks. |
| F | Unstarted | Saved orbital recipes, turn-derived/offscreen-correct positions, subtle orbit graphics, visible turn interpolation, moving attachments/camera and update/save compatibility. |
| G | Planned | Integrated campaign and full compatibility matrix, platform checks, art review package and checkpoint exports. |

The final headless suite passes **242 tests / 12,242 assertions / zero failures**.
Stage C's native X11 display checks pass **6 tests / 34 assertions / zero failures**.
Root's final import and full suite were rerun after withdrawing the Stage D
draft from production, so these counts do not certify that draft.

Native testing uses Linux/X11 software OpenGL. Physical Windows, browser
fullscreen/user-gesture and target-device validation remain open. VSync changes
are rejected by llvmpipe in this environment. Compatibility rendering does not
support the additional 3D render-scale API, so its slider is hidden; existing
visual-quality resolution choices and supported world-viewport MSAA remain.
Initial city network generation takes approximately 0.6–0.7 seconds in the
production cloud fixtures; optimization/worker scheduling is tracked debt.

The Stage D draft is preserved at
`/workspace/starfire_3d_proposal/m1_2_stage_d_draft/`, with source, narrow patches,
verified pre-draft files and a resumption README. Current production
`immersive_world_view.gd` and `game_screen.gd` retain their validated M1.1
behavior. The draft requires review and tests before reintegration.

Root implemented B and prepared the D draft. The requested subagent completed
A and C, then stopped; E was not started. F was not started by root. On resumption,
the next implementation stage is D, followed by E and F with their individual
reports. The existing GitHub desktop ZIP remains the M1.1 Stage G review build;
the local M1.2 source changes have not been exported or published as a new build.
