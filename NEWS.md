# decideR 0.1.0

First formal release. `decideR` is the decision layer of the ORCHESTRA
analytics framework: the loss-optimal, grounding-aware closer of the
inference-to-decision loop. It maps a posterior -- or an upstream member's
`orchestra_manifest` inference result -- into an action under an explicit
utility and a hard feasibility constraint, with calibrated abstention and an
Independent Oracle Principle grounding firewall. This release adds the
manifest-native pipeline tail and the grade-band loss primitive, and formalises
the decision engine, grounding vocabulary, and reference decisions that the
development series exercised.

## New features

* Add a manifest-native pipeline tail. `decide_from_manifest()` turns an
  upstream `orchestra_manifest` into a `decision` by reading the predictive
  draws and the producer's grounding token straight off the manifest, then
  routing them through the same expected-utility engine `decide()` uses. The
  grounding rides from the producer through the decision, so an `[unverified]`
  payload forces an abstention at the pipeline boundary. `decideR` does not
  depend on the contract package: the manifest is read through its public S7
  properties (`outputs`, `metadata`, `summary`), so the tail consumes any
  conforming producer rather than special-casing each one.
* Add `decide_rate_from_manifest()`, the agronomic convenience that sources a
  yield-per-rate posterior and its grounding from a manifest and emits a
  profit-optimal nitrogen-rate decision -- the formalised crop-pipeline tail.
* Add a grade-band (threshold-economics) loss primitive. `grade_band_value()`
  builds a step value schedule whose payoff jumps at quality breakpoints (a
  grain price that steps up as protein clears a milling and a premium
  threshold, say), and `grade_band_utility()` turns the schedule into a
  `decide()`-ready utility. Under a step payoff the optimal decision is governed
  by the posterior probability of clearing each band, not by the posterior mean.
  This is a building block for the future `grainPlan` orchestrator.

## Formalised in this release

* `decide()` chooses the feasible action of greatest expected utility over
  posterior draws, abstaining to a safe action on any of four triggers --
  un-grounded input, no feasible action, low effective sample size, or a move
  that is not clearly better than the status quo.
* `decide_input_rate()` and `decide_position_size()` are two reference
  decisions -- a crop nitrogen rate chosen by expected profit, and a trading
  position size chosen by drawdown-capped expected log-growth -- that route
  through the same engine, demonstrating one decision layer across two domains.
* `decision` is the S7 result class, carrying the chosen action, the candidate
  ledger, the grounding label, and the abstention record, with `print()` and
  `is_grounded()` methods.
* `grounding_grounded()`, `grounding_unverified()`, and `combine_grounding()`
  are the canonical provenance vocabulary, hardcoded to match the ORCHESTRA
  federation's `[unverified]` / `grounded` tokens (worst-case combination: one
  un-grounded input taints the decision).
