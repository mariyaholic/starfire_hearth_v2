# M2C — Stop at the next system

14 November 2026 · follows `93f8cb3` on PR #9

## Behavior

An owned civilian fleet can shorten a valid journey to its next system. The
command removes later waypoints and switches automatic exploration off, while
preserving the current lane, departure system and elapsed movement. Normal
arrival processing completes that lane on its original turn

The shared travel drawer names the next destination with the existing fog-safe
label. It explains the difference between this action and stopping automation,
which preserves the entire planned route. A one-leg fleet without automation is
already stopping and cannot submit another redundant order

No save fields were added. Command serialization, preview Undo and session
guards follow the existing order pipeline

## Verification

Pinned Godot **4.7.2-stable**, after import:

| Check | Result |
| --- | --- |
| Full suite before Shroud changes | 356 tests / 14,547 checks / zero failures |
| Data validation | 20 tables / 391 records / 1,545 strings / zero errors or skipped checks |
| Independent focused review | Eight tests / 87 checks / zero failures |
| Source consistency | Matching digest before and after the full suite |

Source/test digest:
`2a1afcbb6af46572b97d39c2da3226ce2991f353f56e95a83b5be1cfed9b7279`

Tests cover mid-leg arrival timing against the original journey, checksum-verified
save/resume, Undo restoring both route and intent, same-turn Move then Stop,
single-leg automated travel, invalid or foreign requests, stale callbacks and
unknown-system disclosure in both map presentations

The M2B head `93f8cb3` independently passed every nondeployment CI job in
[run 43568733880](https://github.com/mariyaholic/starfire_hearth_v2/actions/runs/43568733880).
That result does not establish CI acceptance of later changes

## Actual-control acceptance

A separate Sol playtester loaded an explicitly labeled four-system initial
fixture, then used OS mouse and keyboard controls. Stopping automation preserved
the full route; stopping at the next system removed the later leg; Undo restored
the original route and automatic intent. Enabled and already-stopping controls
fit the rendered 200% phone-sized layout

The actual subsequent turns advanced current-leg progress from one to two,
arrived only at Tessel on the original completion turn, and remained idle there
on one extra turn with automation off and Halden still unknown

See the [scoped QA report](m2c/actual/M2C_ACTUAL_QA_REPORT.md),
[shortened route](m2c/actual/03-stop-next-strategic-truncated.png),
[Undo](m2c/actual/04-undo-restores-route-and-auto.png),
[phone control](m2c/actual/06-phone200-stop-button-full-width.png),
[arrival](m2c/actual/12-arrived-tessel-3d.png) and
[extra turn](m2c/actual/13-extra-turn-no-auto-resumption.png).
The lead and independent reviewer inspected the rendered controls

This uses a synthetic initial fixture and software rendering. Save/resume for
this command was checked through the actual serializer in automated tests;
it was not repeated through the manual Save menu in this playtest. Native
Windows, physical-phone and hardware-GPU interaction remain unverified. Preserve
the existing PR; no merge or deployment was performed
