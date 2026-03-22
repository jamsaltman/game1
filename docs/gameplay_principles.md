# Gameplay Principles

## North Star

Maximize reward per effort.

For this game, that means good decisions should be easy to notice, feel highly impactful, and clearly outperform random clicking. Players should feel that:
- thinking matters,
- good choices create visible advantage,
- their success comes from understanding the system rather than luck,
- and the game rewards attention more than mindless input.

## Practical Interpretation

The target is a low floor and high ceiling:
- Low floor: a player should usually be able to spot a solid move without solving the whole game.
- High ceiling: expert players should still have meaningful optimization space and non-obvious lines.
- High impact: even if the perfect move is hard to compute, consciously good play should beat random play by a wide and satisfying margin.

This is deliberately not about making every turn complicated. It is about making the payoff for thought feel worth the effort.

## Design Tests

When evaluating a mechanic, UI change, or balance tweak, ask:
- Does this make good moves easier to identify?
- Does it increase the payoff of making a good move?
- Does it reduce the viability of random clicking?
- Does it preserve depth for expert play instead of collapsing into one obvious script?

Changes that increase complexity without increasing decision payoff are usually bad changes.

## Simulation Guidance

The gameplay simulation should be used as a proxy for decision-value, not just survival:
- Compare random play against at least one consciously directed strategy.
- Prefer changes that widen the gap between random and directed play while keeping directed play legible.
- Track not only win rate, but also pacing, pressure, reward timing, and whether the game presents enough meaningful choices.
- Future simulation passes should add metrics that estimate "decision advantage" more directly.

Useful future metrics:
- good-play vs random escape-rate gap,
- good-play vs random depth-reach gap,
- reward timing under different strategies,
- proportion of turns with more than one meaningful action,
- and whether specific mechanics increase or decrease the payoff of deliberate play.

## Agent Note

Future agents should treat this document as the gameplay philosophy for ideation, tuning, and validation work. If a mechanic proposal cannot explain how it improves reward per effort, it is probably not aligned with the current design direction.
