# Gameplay Backlog

Current read: the core loop is functional, but the game did not originally communicate failure with enough force. Pressure now ends runs, resets each board, and defeat is modal, so the biggest remaining work is turn clarity and onboarding polish.

## Priority Order

### Done this pass
- Added a dedicated defeat overlay with a restart action.
- Turned pressure into a real loss condition.
- Locked out normal board interaction after defeat so the game over state is unambiguous.

### P1 - Improve turn clarity
- Make the selected action and target rules easier to understand at a glance.
- Reduce invalid clicks by improving the status text for the current mode.
- Make the turn log more useful for learning why a move succeeded or failed.

### P1 - Improve first-run onboarding
- Ensure the opening turns teach the player the basic goal quickly.
- Give the first successful escape or failure a stronger summary.

### P2 - Tuning pass
- Rebalance the frequency and placement of punishing roles after the end-state work lands.
- Tune upgrade pacing so the run reaches interesting ability combinations sooner.
- Consider whether the pressure cap or warning threshold should be adjusted after more playtesting.

## Notes

- This file should be updated after each implementation/test pass.
- Keep the highest-priority items at the top even if smaller polish items get added later.
