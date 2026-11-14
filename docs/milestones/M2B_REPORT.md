# M2B — Halden discovery and survey automation

14 November 2026 · continue from `0a3ce61` on the existing PR #9 branch

## What changed

Survey probes can receive an explicit automatic-exploration order. Idle probes
survey a legal local target first, then choose a reachable unknown star or an
incompletely surveyed known system by journey time and stable ID ordering.
Unknown planet payloads do not influence the choice. Probe reservations avoid
duplicating work without letting slower colony or construction ships suppress
scouting

Automation is saved as namespaced integer intent in the owning empire's flags.
It assigns at most one task after commands, waits while a player decision is
pending and emits one completion report when no target remains. Accepted manual
move/survey orders override it; rejected orders do not. Disabling automation
preserves the complete current route, movement progress and survey. Undo and
save/reload preserve those distinctions

Halden now offers a preview-only maintenance-cache scene through the existing
event system. Salvage costs 15 energy for up to 40 minerals within storage;
study costs 20 energy for ten production turns of 50% additional research;
leaving the cache intact is free. All three resolve a separate required
objective. The one-shot ledger prevents duplicate rewards, and the new objective
prevents arrival or an older completed visit flag from skipping the decision

The beacon remains dormant; this does not reveal the canonical Dark Beacon
story or implement beacon travel, Noise or combat

## Verified checks

All engine checks use Godot **4.7.2-stable**

| Check | Result |
| --- | --- |
| Final full suite | 348 tests / 14,457 checks / zero failures |
| Final data validation | 20 tables / 391 records / 1,539 strings / zero errors or skipped checks |
| Independent preview check | 19 tests / 201 checks before the final two visual guard checks |
| Final focused preview check | 19 tests / 203 checks |
| Independent auto-exploration check | 12 tests / 67 checks |
| Automated expedition | All goals at turn 44 for three seed-1 choices and default-choice seeds 2–3 |
| Replays | Matching complete per-turn traces for each checked seed/choice pair |
| Safety | No invariant failures, rejected commands or validation waits in those runs |
| Platform exports | Web, Windows and Linux succeed |
| Source consistency | Relevant source/test digest matches before and after the final full run |

Tests include actual checksum-verified `SaveSerializer` envelopes for a pending
decision and mid-buff state; paid-choice undo and reselect; one-shot revisit;
ten producing phases of the research modifier; capped salvage; fog invariance;
ownership and reservations; manual override; and stale-session callbacks

Source/test digest:
`3bb6adac2a9ed31dd677c058d02c2aacff813e643a22fa07f30baed28f0d351d`

The expedition is a deterministic smoke itinerary, not a balance study. It does
not choose research cards, so identical finish times do not imply equivalent
strategic value. The expanded route's expected duration is 50 turns; a person
can choose a different manual itinerary

```sh
godot --headless --path . --import
godot --headless --path . -s tools/validate_data.gd
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tools/expedition_bot.gd -- --seed 1 --choice 0 --trace
```

## Visual evidence

The new fixture renders use the actual production UI in a private Xvfb display
with software OpenGL. Their initial state is set directly for coverage. They
are **not** manual playthroughs or physical-phone evidence

The captures exposed a procedural vignette drawing outside its frame and a
dormant-beacon label wrapping into a one-character column. The corrected renders
retain the art, keep it inside the illustration and show a readable caption

- Event overflow before: [desktop](m2b/before/desktop100_halden_event_top.png),
  [phone 200%](m2b/before/phone200_halden_event_top.png)
- Corrected event: [desktop](m2b/captures/desktop100_halden_event_top.png),
  [phone 200%](m2b/captures/phone200_halden_event_top.png)
- Scroll to choice effects: [desktop](m2b/captures/desktop100_halden_event_choices.png),
  [phone 200%](m2b/captures/phone200_halden_event_choices.png)
- Auto-exploration control: [desktop](m2b/captures/desktop100_fleet_auto.png),
  [phone 200%](m2b/captures/phone200_fleet_auto.png)
- Gate caption: [before](m2b/before/desktop100_empty_gate_strategic.png),
  [Strategic after](m2b/captures/desktop100_empty_gate_strategic.png),
  [3D after](m2b/captures/desktop100_empty_gate_3d.png)

The [full test log](m2b/tests.log), [data log](m2b/data.log) and source digest
preserve the consolidated checks. The three seed-1 traces cover
[salvage](m2b/expedition-salvage.log), [study](m2b/expedition-study.log) and
[leave intact](m2b/expedition-leave.log)

## Actual-control follow-up

A separate Sol playtester also used the normal app with an explicitly declared
initial fixture: a new seed-17 preview, Construction one turn from Halden,
Tessel known and bounded stocks. The fixture was saved with the normal serializer;
all later actions used OS mouse/keyboard input, not direct game calls

It verified enabling automation, actual turn assignment and travel, the cache
opening, Study paying 20 energy, and stopping automation without changing the
current path/progress. After re-enabling and resolving another turn, actual
Save → Quit to title → Continue retained enabled travel and its remaining turn.
The saved study flag and 5000-basis-point modifier were present with nine turns
remaining after that production turn. The empty-system captions were checked in
both map presentations, and the controls were scrolled at 200% phone text

See the [scoped playtest report](m2b/actual/README.md) and actual screenshots:
[enable](m2b/actual/02-auto-enabled-desktop.png),
[cache](m2b/actual/03-halden-event-desktop.png),
[phone choices](m2b/actual/06-halden-event-phone200-study.png),
[travelling](m2b/actual/07-auto-travelling-after-study.png),
[stopped](m2b/actual/08-auto-stopped-route-preserved.png),
[phone stopped](m2b/actual/09-auto-stopped-phone200.png) and
[save/reload](m2b/actual/10-resumed-auto-travel.png)

Only Study was selected through actual controls. The other branches and complete
automation itinerary were tested through the simulator. This follow-up is not
ordinary campaign play, M2B browser acceptance or a physical-phone test

## Recording and scope

A separate actual gameplay walkthrough records stable M2A commit `0a3ce61` from
an ordinary new game using OS mouse and keyboard input. It shows exploration,
arrival, survey and colony founding, not M2B automation or the new discovery.
The 97.918-second silent 720p copy was saved privately to Library, with full
decode verification. Four real capture segments were joined with cuts to remove
waiting and retries; no generated imagery, state injection or fake turns were used

## Remaining work

The original `0a3ce61` CI run passed every nondeployment job. The consolidated
follow-up needs its own CI result. Native Windows execution, physical graphics,
physical phones, audible audio and the complete phone Web save/reload regression
remain unverified

Use a new preview to exercise the added discovery path; these changes do not
retroactively replay a completed earlier preview

Astra recommends a safe stop-at-next-system order before adding The Shroud as
another optional destination. The current automation-off control does not cancel
an already planned multi-leg journey. Neither feature is implemented here

No main merge, live deployment or release was performed
