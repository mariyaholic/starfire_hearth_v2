# M2D — The Shroud as an optional opportunity

14 November 2026 · continue on the existing PR #9 branch

## Goal

Give exploration beyond Vesper an economic purpose without changing the
required expedition or replacing the canonical second campaign scenario

## Content and decisions

- Connect The Shroud only to Vesper with a 2.00-light-year deep lane
- Keep it unknown initially; use the canonical nebula and derelict landmarks
- Add one gas giant with the existing energy-or-research outpost choice
- Reuse influence cost, construction duration, yields, upkeep and explanations
- Add a preview-only derelict decision through the existing event machinery
- Offer machinery, provisions or a free memorial choice with bounded rewards
- Disclose storage limits and preserve one-shot event memory
- Keep all four required objectives and the existing optional Tessel objective
- Add no new checklist entries and no retroactive map injection into old saves

The proposed event exchanges 30 energy for up to 20 metals, 10 energy for up to
50 food, or no energy for up to 10 influence. These are initial tuning values,
not evidence of balanced alternatives

The machinery cost avoids a simple market dominance: metals sell for four
energy and food costs 1.5 energy. At a 15-energy machinery cost, selling the
20 metals and buying 50 food exactly reproduced the provisions choice while
retaining other spending options. At 30 energy, that conversion costs 25 energy;
recovering provisions directly costs ten

The preview opts into finishing pending player decisions before victory.
Evaluate defeat normally, and do not require visiting this optional system.
Other scenarios retain their existing completion policy

Nebula sensor blocking, additional production bonuses, active beacons and combat
remain separate work. A nebula landmark does not demonstrate those mechanics

## Acceptance

Compare the original automated Vesper survey and settlement timing with the
expanded map. Exercise deliberate Shroud-first and Vesper-first itineraries,
both outpost kinds and actual research-card selection. Check all discovery
branches, affordability, caps, duplicates, Undo and checksum-verified saves

Verify an optional discovery arriving on the final required-objective turn is
shown before debrief. Keep four-system saves unchanged and their original
objectives attainable. Review actual rendered discovery and outpost controls
in desktop and phone-sized 200% layouts, with screenshots and clearly labeled
initial fixtures

Use the existing Astra adviser, at most two concurrent Terra writers, independent
Sol reviewer and Sol playtester. Consolidate exact Godot 4.7.2 checks and exports
before the next push. Preserve PR #9; do not merge or deploy
