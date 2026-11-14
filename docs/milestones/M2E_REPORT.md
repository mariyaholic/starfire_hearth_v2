# M2E — Readiness and banked research

14 November 2026 · part of the consolidated M2D/M2E snapshot on PR #9

## Behavior

An eligible idle survey probe with automatic exploration enabled no longer
produces the warning that it needs manual orders between assignments. Pending
player decisions still block End Turn, and the travel drawer continues to show
automatic-exploration status. Disabled automation retains the normal idle warning

Research panels now show stored points when no card is selected. A funded selected
card says **Completes next turn**, including when current research income is zero.
The estimate and bank breakdown come from read-only simulation helpers. The
research phase, income, card selection and save representation remain unchanged

The linked research Codex explains banking and next-phase completion. Selected
progress shows all stored points, including excess that will carry forward

## Verification

The consolidated Godot 4.7.2 suite passes **376 tests / 14,777 checks**, with zero
data errors. See [M2D's report](M2D_REPORT.md) for the shared source digest, exports
and browser smoke scope

Focused checks include four research-helper tests / 22 checks, one readiness
integration test / seven checks and one banked-research UI test / 14 checks.
The actual research phase completes a funded card at zero income; no helper
mutates state. UI cases cover unselected and funded cards, inactive and opted-in
probes, busy/travelling fleets, pending events and both layout profiles

## Visual evidence

Four direct deterministic renders use the production UI under private Xvfb and
software OpenGL: desktop and phone-sized 200% text, showing a 12.34-point bank
without a selected card and a funded card with zero income. The lead and
independent reviewer inspected the phone renders; the stored value and next-turn
label are readable and the meter stays within its frame

See the [fixture manifest](m2e/manifest.json),
[desktop](m2e/captures/desktop100_banked.png),
[phone bank](m2e/captures/phone200_banked.png) and
[phone funded card](m2e/captures/phone200_funded_zero_rate.png)

These are seeded fixture renders with scrolling, not manual gameplay or physical
phones. The fixture deliberately sets research income to zero. An initial direct
quit left four Ogg playback objects alive; the same captures rerun through explicit
screen/session cleanup and the existing graceful audio shutdown exited without
leak, resource-in-use, timeout or ERROR lines. No production change was needed;
this does not certify every shutdown path

Actual Shroud gameplay is documented separately. No merge or deployment was performed
