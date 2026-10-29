# A decision-theoretic action with grounding and abstention

The object returned by
[`decide()`](https://max578.github.io/decideR/reference/decide.md) and
the reference decisions. It records the chosen `action`, the
`expected_utility` that selected it, the complete `candidates` ledger
(every action with its expected utility and feasibility), and the two
provenance fields the Independent Oracle Principle requires: `grounding`
([`grounding_grounded()`](https://max578.github.io/decideR/reference/grounding_tokens.md)
or
[`grounding_unverified()`](https://max578.github.io/decideR/reference/grounding_tokens.md))
and the abstention record (`abstained`, `abstain_reason`). When a
decision abstains the `action` is the caller's `safe_action`, not the
utility-maximal one.

## Usage

``` r
decision(
  action = NULL,
  action_label = NA_character_,
  expected_utility = NA_real_,
  candidates = NULL,
  grounding = "ungrounded",
  abstained = FALSE,
  abstain_reason = NA_character_,
  safe_action = NULL,
  method = NA_character_,
  inputs = list(),
  metadata = list()
)
```

## Arguments

- action:

  The chosen action. The `safe_action` when `abstained` is `TRUE`.

- action_label:

  A short human-readable label for the action; suffixed `"ungrounded"`
  when the grounding is not grounded.

- expected_utility:

  The expected (mean-over-draws) utility of the chosen action, or
  `NA_real_` when abstained.

- candidates:

  A `data.frame` with one row per candidate action: `action`,
  `expected_utility`, `feasible`.

- grounding:

  A canonical grounding token.

- abstained:

  `TRUE` when the decision declined the utility-maximal action.

- abstain_reason:

  A short reason string, or `NA_character_`.

- safe_action:

  The fallback action taken on abstention.

- method:

  The decision rule applied (e.g. `"expected_profit"`).

- inputs:

  A named list recording input provenance.

- metadata:

  A named list of free-form metadata.

## Value

A `decision` S7 object.

## See also

[`decide()`](https://max578.github.io/decideR/reference/decide.md) and
the reference decisions that produce this object.

Other decisions:
[`decide()`](https://max578.github.io/decideR/reference/decide.md),
[`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md),
[`decide_position_size()`](https://max578.github.io/decideR/reference/decide_position_size.md),
[`is_grounded()`](https://max578.github.io/decideR/reference/is_grounded.md)

## Examples

``` r
d <- decision(action = 120, action_label = "rate=120 kg/ha",
              expected_utility = 1840, grounding = grounding_grounded())
d@action
#> [1] 120
```
