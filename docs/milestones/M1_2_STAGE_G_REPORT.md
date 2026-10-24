# M1.2 Stage G — Integrated checkpoint validation

**Status: locally complete, refreshed after owner UI/space review on 4 October 2026.**
Source remains on the existing M1 lineage. No new branch, commit, push, tag or
publication was created. Latest changes and screenshots are in the
[D–G follow-up report](M1_2_D_G_REVALIDATION_REPORT.md).

## Latest evidence

- Full Godot 4.7.2 suite: **255 tests / 12,392 checks / zero failures**.
- Data validation: **20 tables / 328 records / 1,485 localized strings / zero errors
  or skipped checks**.
- Focused D: **8 tests / 144 checks**; E: voice **3 / 24**, audio **5 / 187**;
  F: **5 / 76**. All pass. Final F coverage includes ambient-pause follower continuity
  and asteroid-belt transition/camera tracking.
- Updated desktop and touch-emulated phone browser flow: **58 checks / zero failures /
  zero browser, script or shader errors**. Each profile has 29 checks. Actual mouse/touch
  Jobs orders, finish parity, 200% text, turn resolution, overview framing and
  destroyed-page IndexedDB reload passed. Saved turn positions reconstruct identically.
  [Machine results](../../screens/m12_owner_revalidation_web/verification.json).
- Eleven actual native captures and twelve browser captures replace concept pictures
  as implementation evidence. See [system spacing](../../screens/m12_owner_revalidation/05_spaced_system.png),
  [compact city](../../screens/m12_owner_revalidation/01_compact_city_default.png),
  [Jobs window](../../screens/m12_owner_revalidation/03_management_jobs.png),
  [phone after reload](../../screens/m12_owner_revalidation_web/phone_06_system_after_reload.png).
- Windows x86_64 and Web Release exports succeeded with the pinned engine/templates;
  final exports were refreshed after the pause/belt corrections. The targeted browser
  flow covers the unchanged normal UI/camera/save path; those edge corrections were
  revalidated through final native tests. Artifact size/checksum are in the follow-up report.

## Earlier broad checkpoint evidence

Before the compact UI/spacing follow-up, desktop Chromium passed **167 checks** and
phone touch emulation passed **169 checks** (336 total, zero failures/browser errors).
That broader campaign covered placement/construction, upgrades/demolition,
3D/Strategic action parity, pinch zoom, graphics controls, turns and save/reload.
It is historical coverage, not a claim that the entire campaign was rerun for this
follow-up. The previous native D/F smoke had 10 passing checks.

## Review build and limits

The refreshed [Windows review ZIP](../../build/m12_review/StarfireHearth_M1_2_Windows.zip)
contains the standalone executable and README, compressed to approximately 79 MiB.
Web export remains approximately 85 MB. These are local review artifacts, not uploaded
or tagged releases. Full details and checksum: [follow-up report](M1_2_D_G_REVALIDATION_REPORT.md).

Windows display-mode behavior has not been run on Windows. Cloud browsers use SwiftShader,
native captures use llvmpipe, and phone coverage is viewport/touch emulation. Owner hardware
performance and art/playtest acceptance remain open. No recorded dialogue was delivered.
The existing native shutdown cleanup warning remains tracked in the follow-up report.
