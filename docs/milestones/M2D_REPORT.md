# M2D — The Shroud and informed outpost choices

14 November 2026 · follows M2C on the existing PR #9 branch

## What changed

New expeditions include The Shroud, connected only to Vesper by a 2.00-light-year
deep lane. It is an optional branch with the canonical nebula and derelict
landmarks, a gas giant and the existing energy-or-research outpost decision.
Unknown intermediate systems remain forbidden, and automatic exploration surveys
Vesper before entering this branch

The preview-only derelict offers 30 energy for up to 20 metals, ten energy for up
to 50 food, or a free memorial choice granting up to ten influence. Every reward
obeys storage caps. Event memory prevents repeated rewards, and the free choice
remains available without energy. The machinery cost avoids a direct market
conversion that would otherwise reproduce the provisions choice at the same cost

All four required objectives and the optional Tessel objective remain unchanged.
The preview now waits for pending player decisions before victory, after evaluating
defeat. Visiting The Shroud is never required. Other scenarios retain their
existing completion policy

Surveyed outpost sites show expected production and upkeep even before a builder
arrives. The same simulation reports provide both projected and operating output.
Energy net explicitly includes upkeep; research is shown separately in physics,
society and engineering. Current modifiers apply, including the Ark origin and
Halden's temporary research effect

No save fields or outpost production rules changed. Old previews retain their
saved four-system topology. Start a new expedition for the fifth system. Nebula
sensor blocking, additional nebula production bonuses, active beacons and combat
are not implemented by this increment

## Verification

The consolidated M2D/M2E snapshot uses Godot **4.7.2-stable**

| Check | Result |
| --- | --- |
| Full suite | 376 tests / 14,777 checks / zero failures |
| Data validation | 20 tables / 391 records / 1,565 strings / zero errors or skipped checks |
| Source consistency | Same relevant source/test digest before and after the full suite |
| Exports | Web, Windows and Linux succeed |
| Packaged Linux | Headless embedded-package startup exits zero |
| Fresh web smoke | Desktop, phone and tablet all pass, with no reported browser errors |
| Web/native one-turn parity | `911cdd430061` on all three browser profiles |

Source/test digest:
`676f26742ff11fdeebf109f2dfe710ef118ef4caeb99ba188f57516243c49a89`

Tests cover discovery costs and uncapped amounts, storage clipping, affordable
fallbacks, paid-choice Undo, duplicate/revisit rejection, pending-event and midbuild
checksum-verified saves, and arrival on the final required-objective turn. Defeat
takes priority, foreign decisions do not delay victory, and the policy flag must
be a boolean

The historical fixture uses the scenario JSON from `93f8cb3` with the unchanged
loader, serializer and turn processor under the pinned engine, advanced four
normal turns. It loads with four systems. Its isolated completion test marks the
original objectives before advancing; this is compatibility evidence, not a full
historical playthrough

Outpost projections are checked against operating output, including mining tech,
global and scoped modifiers, a synthetic-ID collision and state-hash nonmutation.
UI tests cover fog labels, both outpost actions, no-builder projections, owned
production, both map presentations and simulated phone 200% layout

## Itinerary evidence

The original automated seed-1 route still surveys Vesper on turn 21 and founds
the colony on turn 22. The expanded default route still completes at turn 44

The optional harness routes select real research cards with the same policy for
both outpost kinds. They deliberately hold Vesper development until the requested
Shroud outpost exists, to prevent victory from skipping the tested investment

| Seed-1 route, free discovery choices | Energy outpost | Research outpost |
| --- | --- | --- |
| Shroud-first completion turn | 40 | 40 |
| Vesper-first completion turn | 36 | 36 |
| Shroud outpost completion turn | 20 | 20 |

Each of these four full per-turn traces matched its repeat. The Vesper-first
pair completed three technologies in each case; final empire energy income was
19.80 versus 13.20 per turn, and total research was 5.40 versus 13.50 per turn.
The minimum end-of-turn food and energy stocks in those runs remained at their
initial 300 and 120. These are one-seed coverage runs with explicit policy holds,
not optimal strategies, proof of equal value or a balance verdict

The existing gas-giant base research is three per branch, reduced to 2.70 by the
Ark origin before other effects. The interface shows the actual modified value
rather than a hard-coded base. Expected initial no-route waits on undiscovered
waypoints are reported by the harness; they are not rejected validated orders

Reproduce with:

```sh
godot --headless --path . -s tools/expedition_bot.gd -- --seed 1 --trace
godot --headless --path . -s tools/expedition_bot.gd -- --seed 1 --route vesper-first --outpost research --trace
```

## Rendered acceptance and limits

A separate Sol playtester started from an explicitly declared five-system fixture:
the gas giant was already surveyed, and the survey and construction fleets were
staggered on the Vesper–Shroud lane. Later actions used OS input, not direct state
or turn calls

The pending discovery was captured on desktop and at phone-sized 200% text.
Choosing provisions paid ten energy and added 50 food. Before the builder arrived,
both projected outpost reports were visible. Once it arrived, Energy paid 50
influence and queued four turns; Undo restored the influence and idle ship;
Research then paid 50 once and completed after four actual turn confirmations.
Both map presentations showed the operating 2.70 research in each branch and
0.50 energy upkeep. A manual save contained the completed research outpost and
the resolved provisions flags

The playtest process loaded before the final subtitle-only clarification. A
separate [phone fixture](m2d/subtitle/phone200_energy.png) verifies the updated
**Projected per turn with current modifiers** subtitle. The lead and independent
reviewer inspected the actual and fixture images. Actual-save creation is not
an actual-menu reload claim; automated tests independently cover save/resume

See the [actual-control QA report](m2d/actual/M2D_ACTUAL_QA_REPORT.md),
[pending discovery](m2d/actual/verified-01-discovery-desktop.png),
[phone choices](m2d/actual/verified-03-discovery-phone200-choices.png),
[projections](m2d/actual/verified-04-projections-before-builder-3d.png),
[Undo](m2d/actual/verified-10-undo-energy-order.png) and
[operating outpost](m2d/actual/verified-14-owned-output-3d.png)

The first attempt's capture helper retried a Continue click and unintentionally
accepted the first discovery choice before capturing. Its provisional images
were rejected. The clean attempt removed retries, verified the pending overlay
before each action and deliberately chose provisions. Rejected captures are not
included in the repository evidence

The [full test log](m2d/tests.log), [data log](m2d/data.log),
[export manifest](m2d/export-manifest.json), [web smoke](m2d/web-smoke.log) and
[replay comparison](m2d/expeditions/replays.json) preserve the consolidated checks.
The existing PR's Checks tab supplies CI status for each pushed head; earlier
green runs are not substituted for the current head

The web smoke uses current exported assets in system Chromium with software
WebGL. Its private adapter differs from the committed smoke script only by
selecting `/usr/bin/chromium`. It checks startup, layout and one scripted Scenario
1 turn, not the full Shroud interaction or browser save/reload flow. Native UI
playtests and direct rendered fixtures have their own scoped evidence

Native Windows/Wine execution, hardware graphics, physical phones and audible
audio remain unverified. No main merge, deployment or public release was performed
