# Package index

## Decisions

The core engine and the two reference decisions built on it.

- [`decide()`](https://max578.github.io/decideR/reference/decide.md) :
  Choose an action by expected utility, with grounding and abstention
- [`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md)
  : Choose a crop input rate by expected profit
- [`decide_position_size()`](https://max578.github.io/decideR/reference/decide_position_size.md)
  : Size a trading position by capped expected log-growth under a
  loss-quantile limit
- [`decision()`](https://max578.github.io/decideR/reference/decision.md)
  : A decision-theoretic action with grounding and abstention
- [`is_grounded()`](https://max578.github.io/decideR/reference/is_grounded.md)
  : Is a decision grounded?
- [`print,decideR::decision-method`](https://max578.github.io/decideR/reference/print-decideR-decision-method.md)
  : Print a decision

## Manifest tail

Deciding directly from an upstream `orchestra_manifest`.

- [`decide_from_manifest()`](https://max578.github.io/decideR/reference/decide_from_manifest.md)
  : Turn an orchestra manifest into a decision
- [`decide_rate_from_manifest()`](https://max578.github.io/decideR/reference/decide_rate_from_manifest.md)
  : Choose a crop input rate from an upstream yield manifest

## Value

Value of information (EVPI, EVSI) and the discounted benefit-cost ratio.

- [`bcr_crrdc()`](https://max578.github.io/decideR/reference/bcr_crrdc.md)
  : CRRDC-guideline benefit-cost ratio
- [`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md)
  : Benefit-cost ratio of a research investment
- [`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md)
  : Expected value of perfect information from a manifest
- [`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md)
  : Expected value of one prospective sample from a manifest
- [`print,decideR::valuation-method`](https://max578.github.io/decideR/reference/print-decideR-valuation-method.md)
  : Print a valuation
- [`valuation()`](https://max578.github.io/decideR/reference/valuation.md)
  : A priced quantity with grounding and abstention
- [`print(`*`<decider_bcr>`*`)`](https://max578.github.io/decideR/reference/print.decider_bcr.md)
  : Print a CRRDC benefit-cost ratio
- [`as.data.frame(`*`<decider_bcr>`*`)`](https://max578.github.io/decideR/reference/as.data.frame.decider_bcr.md)
  : Coerce a CRRDC benefit-cost ratio to a data.frame

## Grounding

The Independent Oracle Principle provenance vocabulary.

- [`combine_grounding()`](https://max578.github.io/decideR/reference/combine_grounding.md)
  : Combine input grounding worst-case
- [`grounding_grounded()`](https://max578.github.io/decideR/reference/grounding_tokens.md)
  [`grounding_unverified()`](https://max578.github.io/decideR/reference/grounding_tokens.md)
  : Canonical grounding tokens

## Loss

Threshold-economics (grade-band) loss primitives.

- [`grade_band_utility()`](https://max578.github.io/decideR/reference/grade_band_utility.md)
  : Build a decide() utility from a grade-band schedule
- [`grade_band_value()`](https://max578.github.io/decideR/reference/grade_band_value.md)
  : A grade-band value schedule (threshold-economics loss)
- [`print(`*`<grade_band_value>`*`)`](https://max578.github.io/decideR/reference/print.grade_band_value.md)
  : Print a grade-band value schedule
