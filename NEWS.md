# decideR 0.0.0.9000 (development)

First development version. `decideR` is the shared Bayesian decision layer of the
ORCHESTRA analytics framework: it maps a posterior into an action under an
explicit utility and a hard constraint, with calibrated abstention and an
Independent Oracle Principle grounding firewall.

## New features

* `decide()` chooses the feasible action of greatest expected utility over
  posterior draws, abstaining to a safe action on any of four triggers --
  un-grounded input, no feasible action, low effective sample size, or a move
  that is not clearly better than the status quo.
* `decide_input_rate()` and `decide_position_size()` are two reference decisions
  -- a crop nitrogen rate chosen by expected profit, and a trading position size
  chosen by drawdown-capped expected log-growth -- that route through the same
  engine, demonstrating one decision layer across two domains.
* `decision` is the S7 result class, carrying the chosen action, the candidate
  ledger, the grounding label, and the abstention record, with `print()` and
  `is_grounded()` methods.
* `grounding_grounded()`, `grounding_unverified()`, and `combine_grounding()`
  are the canonical provenance vocabulary, hardcoded to match the ORCHESTRA
  federation's `[unverified]` / `grounded` tokens (worst-case combination: one
  un-grounded input taints the decision).
