# M2E — Expedition readiness and research feedback

14 November 2026 · continue the same preview expansion on PR #9

## Goal

Show what needs the player's attention without treating opted-in automation as
an unassigned manual task, and expose research that has already accumulated

## Contract

- Do not flag an eligible idle auto-exploration probe as needing manual orders
- Keep pending player decisions and actual blocked or paused status visible
- Keep existing feedback for disabled automation, busy and travelling fleets
- Show stored research even before the player chooses a card
- Derive completion estimates in simulation code rather than UI arithmetic
- Show a funded selected card as completing on the next research phase
- Preserve production, research selection, turn phases and save behavior

Verify enabled/disabled automation and pending events, selected/unselected cards,
funded cards at zero production, and desktop/200% phone UI. Keep this a small
feedback improvement, with no additional mechanics or destinations
