# Gameplay Backlog

Current read after the 2026-03-22 production pass: the game is materially more teachable and better at signaling momentum. The shell now tells the player what matters on this turn, clears now read as transitions instead of silent interruptions, and early rewards point toward a readable build. The opener remains stable in headless simulation while early-run pacing improved. Latest sampled metrics:
- Greedy board-1 escape rate: 54.5%.
- Random board-1 escape rate: 43.5%.
- Greedy board-3 reach rate by depth-3 playtest cap: 21.5%.
- Random board-3 reach rate by depth-3 playtest cap: 9.0%.
- Project boot smoke test passes and rule tests pass.

## Priority Order

### Done before this pass
- Added a dedicated defeat overlay with a restart action.
- Turned pressure into a real loss condition.
- Locked out normal board interaction after defeat so the game over state is unambiguous.
- Reworked the first-board opener to guarantee safer first-ring role mixes.
- Delayed blockers, killers, and redirectors out of the opening board.
- Softened early-board pressure and gave the opening board a longer runway.
- Added a rule-level playtest harness for measuring opener escape rates.

### Done this pass
- Replaced generic status text with action-specific guidance and exposed richer HUD guidance fields.
- Added explicit board-one onboarding copy and board-tip messaging.
- Added a dedicated `TURN READ` shell panel for current-action guidance and tactical context.
- Added a board-cleared transition banner so success reads as payoff instead of a silent state change.
- Improved upgrade presentation with context text so rewards read like route choices.
- Improved defeat copy so pressure and role-driven losses are easier to understand.
- Curated the first reward screens toward starter-friendly upgrade sets for more readable early builds.
- Added a structured headless playtest reporter that tracks early-run pacing and provides representative traces.
- Improved hover-card timing language so tiles communicate whether they are hidden, active now, dazed, or acting next turn.

### P2 - Follow-up balance
- Decide whether the pressure curve should loosen slightly for low-information random play without undermining the intended time pressure.
- Review whether `Stay` is carrying enough strategic value or still acting mostly as a forced-pressure tax when legal flips collapse.
- Review whether board-two danger roles should get another telegraphing pass now that transition and hover clarity are stronger.

### P3 - Nice-to-have polish
- Add a short first-loss recap that names the specific learning takeaway for the next run.
- Consider surfacing the upcoming reward route more strongly in the action dock after a board clear.
- Consider expanding the playtest reporter with per-upgrade pick rates once deeper balance work starts.

## Notes

- Core design philosophy lives in [docs/gameplay_principles.md](/Users/haoyang/Projects/game1/docs/gameplay_principles.md).
- This file should be updated after each implementation/test pass.
- Keep the highest-priority items at the top even if smaller polish items get added later.
- Verification completed for this pass:
- `godot --headless --path /Users/haoyang/Projects/game1 --quit-after 1`
- `godot --headless --path /Users/haoyang/Projects/game1 -s res://scripts/living_maze_tests.gd`
- `godot --headless --path /Users/haoyang/Projects/game1 -s res://scripts/balance_playtest.gd`
