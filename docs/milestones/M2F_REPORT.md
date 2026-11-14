# M2F — Continue a completed expedition

14 November 2026 · `feat/expedition-continuation`, based on `90e3db5`

## Behavior

The preview victory debrief now offers Continue expedition alongside Return to
campaign. Continuing retains the map, stocks, tasks, routes, automatic intent,
events, research and objective dates. It records the original victory turn in
existing namespaced integer flags and clears the active terminal outcome on a
clone. Neither time nor production advances

Continued play still records optional objectives and checks defeat. It does not
award another victory or unlock the canonical campaign. The Objectives view shows
the original completion date. Previously won four-system previews remain eligible
without gaining new systems or recomputing their old victory against later goals

The app captures live visual presentation and writes one replacement auto-save.
On Web it keeps the debrief visibly saving until a read-only IndexedDB transaction
confirms the exact envelope bytes, then resumes through the normal session
boundary. A failed or unconfirmed write leaves the winning session open;
uncertain writes are not rolled back. Checkpoints are untouched. No fabricated
turn result is emitted

Both continuation and the old return action reject detached or stale debriefs.
Repeated activation cannot reset the new session or discard newly queued orders

PR #9 remains frozen at `90e3db5` and ready for review. This work belongs to a
separate branch and PR; nothing was merged or deployed

## Consolidated checks

All engine validation uses Godot **4.7.2-stable**

| Check | Result |
| --- | --- |
| Full suite | 390 tests / 14,907 checks / zero failures |
| Data validation | 20 tables / 391 records / 1,579 strings / zero errors or skipped checks |
| Independent continuation checks | 14 tests / 130 checks |
| Independent canonical goldens | Four tests / six checks |
| Source consistency | Matching relevant source/test digests before and after the full suite |
| Platform exports | Web, Windows and Linux succeed |
| Standard fresh web smoke | Desktop, phone and tablet profiles all pass |
| Standard one-turn parity | `911cdd430061` on all three profiles |

Source/test digest:
`e7b6828e8b264de6d134e396a9c3a3e008a5b445bc1644f2d85aac25c9415e08`

Focused cases cover zero-time cloning and independent objects; old authoritative
wins with missing newer goals; copied/malformed flags; later defeat; serializer
round-trips; one auto-slot replacement; byte-identical checkpoints; nonpersistent
mode; deterministic write failure; nonempty queues; live orbital/groundworks
presentation; immediate routing after load; same-seed replacement; identity
replacement without a serial change; and duplicate/stale actions

Controlled delayed-verifier tests also cover blocked duplicate orders, disabled
actions surviving a phone-layout rebuild, unconfirmed storage and stale
completion preserving a newer session's generation and busy state

## Command-driven and longer-horizon evidence

The ordinary command-driven route reaches a winning state at current turn 44,
whose completed victory turn is 43. It continues without changing that state or
advancing time, immediately serializes/reloads, then completes the previously
unfinished Shroud outpost on resolved turn 62. A separate Shroud-first route
with an existing research outpost completes an additional technology on resolved
turn 51 while retaining original victory turn 39. Both full traces match their
respective repeats. These are simulated command-driven runs, not manual play

```sh
godot --headless --path . -s tools/expedition_bot.gd -- --seed 1 --continue --trace
godot --headless --path . -s tools/expedition_bot.gd -- --seed 1 --route shroud-first --outpost research --continue --trace
```

A separate synthetic seed-1 victory fixture continued for 200 legal queued turns.
All per-turn invariants and 20 periodic serializer round-trips passed, no victory
was repeated, and the original completion turn stayed one. It remained active
at current turn 201. Final save size was 7,453 bytes, with a 7,454-byte maximum

On this cloud machine, `TurnProcessor.run` measured 7.99 ms mean, 20.34 ms p95
and 29.40 ms maximum. This is one seed and one simple policy. It excludes UI/frame
rendering, command preparation, invariant checks and serialization; it is not
evidence of physical-phone frame performance

## Actual native acceptance

A separate Sol playtester used an explicitly synthetic near-win turn-40 save,
then actual OS controls. One real End Turn produced victory turn 40 and current
state turn 41. Continuing retained exactly that current turn, stocks, task
countdown and movement progress. Full dictionary comparison found only the three
outcome fields and two continuation flags changed

Before another turn, Quit to title → Continue loaded the identical continued
state directly into Game. Two later real turns completed the previously unfinished
research outpost without returning to victory debrief. Desktop and phone-sized
200% captures show both debrief actions, historical completion date, retained
tasks and completed production in both map presentations

The [actual-control report](m2f/actual/M2F_ACTUAL_QA_REPORT.md) includes inspected
screenshots and paired observations. The lead and independent reviewer inspected
the debrief, immediate reload, completion date and later construction frames.
This is a labeled initial fixture with software OpenGL, not a full campaign or
physical-device playthrough

## Browser acceptance

The standard three-profile smoke checks startup and a scripted Scenario 1 turn.
Separate production-export touchscreen runs seed only an initial normal save and
settings into IndexedDB, then use actual UI actions with no runtime game calls

The first implementation failed a real rapid reload: 1.06 seconds after the input
started, reloading restored the old victory debrief. A delayed 21.6-second reload
passed, which did not clear that failure. Both cases are retained in the
[Web QA report](m2f/actual/web/M2F_WEB_QA_REPORT.md)

Godot 4.7.2's [force-sync method](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/os_web.cpp#L247)
only marks the filesystem dirty. Its asynchronous synchronization cannot be
treated as a durable-write acknowledgement. The fix verifies committed bytes
locally, without a second save store or network request, and rechecks operation
generation, session and source state after awaiting confirmation

In the corrected fresh export, the tester detected the first rendered active-game
frame 3.09 seconds after tapping, then requested reload in the same script with
no added wait, screenshot or record inspection. Title Continue reopened active
Game before another turn, with current turn 41, original completion 40, task two
and probe progress two preserved. The checksum and full authoritative dictionary
matched. No browser errors were recorded

The preceding read-only storage query raced before the visual transition and
still saw the old winner; it is not presented as an at-acknowledgement match. The
decisive evidence is successful immediate-after-active reload and the complete
verified state afterward. This is Chromium touch emulation with software WebGL,
not a physical phone or universal browser certification

See the [corrected retest](m2f/actual/web/fixed/M2F_WEB_FIX_RETEST.md) and
[active game after rapid reload](m2f/actual/web/fixed/verified-03-continued-game-after-rapid-ack-reload.png).
The companion run captured Saving with disabled actions and a duplicate Continue
attempt while pending. Its Return tap straddled completion, so it does not prove
that Return was exercised while disabled or that a reload occurred while saving

The barrier currently protects continuation's auto slot. Ordinary End Turn and
manual-save durability remain separate whole-game audit work. An interrupted
save before acknowledgement may reopen either complete snapshot; it must not
falsely announce successful continued play

## Remaining limits and next phase

Native Windows/Wine, hardware graphics, physical phones and audible audio remain
unverified. A later simulated loss and failure rollback have automated coverage;
they were not performed in the accepted native walkthrough

At 08:00 UTC / 4 PM Manila, finish the current feature task and start no more
features. The next phase assesses the whole game's implicit state machines,
responsiveness, security and privacy. Deferred feature work belongs to a later
session, including sensor visibility/history separation and a complete beacon
restoration/link/transit/Noise package
