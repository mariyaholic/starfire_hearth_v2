# M1.1 staged implementation progress

Owner approved implementation on 1 October 2026, with revalidation and reporting
after each stage. On 1 October 2026 the Owner clarified the priority: deliver visual
quality first and optimize afterwards. Temporary performance overruns are authorized;
the numerical targets remain tracked. Correctness, intel filtering, compatibility and
usable controls still require revalidation.

| Stage | Current status | Gate evidence |
| --- | --- | --- |
| A — Baseline and renderer feasibility | Complete for progression; performance debt carried forward | 174 tests, 30 native checks, 24 browser checks pass. Measured memory/timing overruns and intermittent native exit warnings remain recorded. [Report](M1_1_STAGE_A_REPORT.md). |
| B — Production foundation | Complete | 180 tests / 3,360 checks pass; persistent host/controller, filtered revisions, both scheduler backends, pinned cache, epoch/lifecycle and fallback checks. [Report](M1_1_STAGE_B_REPORT.md). |
| C — Integrated space | Complete for progression; final art/device optimization remains | 185 tests / 3,576 checks; 117 native and 70 browser checks pass. Actual Galaxy/System commands, all eight worlds/seven stellar families, owned ships/outposts, touch pinch and Strategic restoration. [Report](M1_1_STAGE_C_REPORT.md). |
| D — Shared geography and saved appearance | Complete for progression; art/device optimization remains | 204 tests / 10,067 checks; 20 native and 38 browser checks. Independent versioned graphics transport, retained future payloads, frozen profiles/anchors, shared globe/region field and real browser-storage reload. [Report](M1_1_STAGE_D_REPORT.md), [compatibility contract](M1_1_GRAPHICS_SAVE_CONTRACT.md). |
| E — Integrated city | Complete for progression; final art/device optimization remains | 209 tests / 11,676 checks; 187 native checks and 275 browser checks. Normal anchored planner, all canonical sizes/buildings/tiers, real orders, committed clearings, page-reload continuity and actual older Stage D writer roundtrips. [Report](M1_1_STAGE_E_REPORT.md). |
| F — Art and responsive finish | Implemented and revalidated; Owner art acceptance open | 216 tests / 11,918 checks; 290 native + 119 supplemental checks, 343 browser checks, 367 asset and 27 archived-E compatibility checks. Current reference gallery and measured costs. [Report](M1_1_STAGE_F_REPORT.md). |
| F.1 — Command / Immersive layout | Implemented and revalidated; Owner review open | 219 tests / 12,015 checks; 319 native and 127 desktop/touch Web checks pass. Same renderer/camera/orders, page-reload layout/save continuity, real construction/space controls and 100–200% desktop/phone layouts. 42 fresh captures. [Report](M1_1_IMMERSIVE_VIEW_REPORT.md). |
| G — Checkpoint validation | Locally implemented and revalidated; checkpoint acceptance remains pending | 221 tests / 12,035 checks; 459-check production-screen First Light campaign to a turn-79 win; strict 100-run telemetry with 8,789/8,789 baseline hash matches and six deterministic replays; 100-switch lifecycle 1,106 checks; current exported Web tour 127 checks / 21 captures; Web / Windows / Linux exports. See [Stage G report](M1_1_STAGE_G_REPORT.md). |

Stage A's original report remains a historical measurement record. Its performance
gate no longer blocks progression following the Owner's explicit instruction.
Stages B through G have been implemented and locally revalidated. Stage E integrates
anchored terrain into the normal Colony planner; Stage F supplies the current art
and responsive reference finish. Stage G records local checkpoint evidence. Hosted
CI, automatic WebGL renderer recovery, physical-device and Owner art/playtest gates
remain open. The Owner's intervening showcase request produced
seven fresh Blender Cycles concept renders from the newer M1 sources: Aster's
developed settlement and habitat close-up, a Vael architecture/terrain study,
Aster and Brume orbital views, ringed Dross and Ember's photosphere. All seven are
2560×1440 PNGs at 128 samples and have been visually inspected. They depict offline
lighting/material explorations; the city is an illustrative tier-three arrangement,
not a saved gameplay state. They do not establish completion of production stages.
The local review package is `starfire_3d_proposal/m1_showcase/`, with original PNGs,
a portable gallery, a seven-page PDF and source/render provenance. The archive is
`starfire_3d_proposal/m1_concept_showcase.zip`. M1.1 is not yet complete.
The smaller original-picture download is `starfire_3d_proposal/m1_showcase_images.zip`.
The current B/C review package is `starfire_3d_proposal/m1_1_stages_b_c/`, with 36
game verification captures, a playable web export, stage reports, evidence and the
complete local M1 source delta. Its ZIP is `starfire_3d_proposal/m1_1_stages_b_c_review.zip`.
All seven full-size gallery views, desktop/phone layouts, keyboard/touch controls,
PNG download, PDF image/page counts and ZIP integrity passed artifact verification.
No new branch, push, merge, tag or deployment was created;
all implementation changes remain local and uncommitted on the existing M1 lineage.

The Stage D review is `starfire_3d_proposal/m1_1_stage_d/`, with eighteen native/browser
save-continuity captures, a readable gallery/report, verified web build, full source
delta and compatibility evidence. The archive is `starfire_3d_proposal/m1_1_stage_d_review.zip`.
Original M1 can load its gameplay envelope, but an original M1 resave drops graphics
metadata; exact downgrade/resave continuity requires the Stage D transport contract.

The Stage E review is `starfire_3d_proposal/m1_1_stage_e/`, with 36 current native/browser
planner captures, a mobile-readable report/gallery, playable web build, complete local
source delta and catalog/clearing continuity evidence. The archive is
`starfire_3d_proposal/m1_1_stage_e_review.zip`. New games pin city kit 2; kit 1 stays
supported. The archived Stage D writer preserves both via supported/fallback views.
Stage E is a historical checkpoint. Stage F implementation and revalidation remain
available for Owner art review. No release action is taken.

The Stage F review is `starfire_3d_proposal/m1_1_stage_f/`, with 81 fresh in-game captures, a phone-readable report/gallery, playable Web export, complete local source delta and graphics-upgrade/older-writer evidence. Its archive is `m1_1_stage_f_review.zip`; `m1_1_stage_f_images.zip` contains twenty current 1920×1080 art pictures. New games pin city kit 3 and planet/stellar/civilian finish 2. Supported old looks remain pinned until explicit upgrade. The actual E writer preserves the F original and adds completed/demolished clearing history that F restores. Owner artistic acceptance and Stage G remain open.

The Owner-approved F.1 addition supplies the two independently selectable screen
compositions before Stage G. The phone-readable report/gallery, eight-image ZIP,
playable Web export and complete local source delta are in
`starfire_3d_proposal/m1_1_immersive*`. Device layout survives browser page closure
without changing the campaign or graphics save contract. Stage G cloud validation
now passes locally; its campaign, lifecycle, export, Web, save-continuity and
performance evidence is recorded in the [checkpoint report](M1_1_REPORT.md) and
[Stage G report](M1_1_STAGE_G_REPORT.md). Open the mobile-readable review at
`starfire_3d_proposal/m1_1_checkpoint/review/M1_1_STAGE_G.pdf` or its full
resolution [capture gallery](../../starfire_3d_proposal/m1_1_checkpoint/review/gallery/index.html).
The complete review archive is
`starfire_3d_proposal/m1_1_checkpoint/m1_1_stage_g_review.zip`. The cloud review is
ready; owner art/playtest acceptance, hosted CI, target devices, Windows runtime,
and automatic WebGL scene restoration remain pending. No release action is taken.
