# Gameplay Backlog

Current read: the opener is materially healthier than before, but still not fully solved. Measured headless playtests moved the first-board greedy-bot escape rate from about 7.5% to about 54.5%, mainly by softening early pressure and making first-board openings more readable. Remaining work should focus on human-facing clarity and another balance pass after manual play.

## Priority Order

### Done this pass
- Added a dedicated defeat overlay with a restart action.
- Turned pressure into a real loss condition.
- Locked out normal board interaction after defeat so the game over state is unambiguous.
- Reworked the first-board opener to guarantee safer first-ring role mixes.
- Delayed blockers, killers, and redirectors out of the opening board.
- Softened early-board pressure and gave the opening board a longer runway.
- Added a rule-level playtest harness for measuring opener escape rates.

### P1 - Improve turn clarity
- Make the selected action and target rules easier to understand at a glance.
- Reduce invalid clicks by improving the status text for the current mode.
- Make the turn log more useful for learning why a move succeeded or failed.

### P1 - Improve first-run onboarding
- Ensure the opening turns teach the player the basic goal quickly.
- Give the first successful escape or failure a stronger summary.

### P2 - Tuning pass
- Tune upgrade pacing so the run reaches interesting ability combinations sooner.
- Run another balance pass after manual playtesting the new opener.
- Consider whether the pressure cap or warning threshold should be adjusted again after that playtest.

## Notes

- This file should be updated after each implementation/test pass.
- Keep the highest-priority items at the top even if smaller polish items get added later.
