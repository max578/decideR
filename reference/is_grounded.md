# Is a decision grounded?

A convenience predicate reading the decision's grounding label. It
reports only the grounding of the evidence, not whether the decision
abstained – `is_grounded()` is `TRUE` for an abstained decision whenever
the abstention reason was `no_feasible_action`, `low_ess`, or
`insufficient_evidence`, since none of those reasons downgrades the
grounding label itself. A consumer that must refuse to act on either
un-grounded evidence or an abstained decision – for example a live
trading order path – gates on `is_grounded(x) && !x@abstained`, not on
`is_grounded()` alone.

## Usage

``` r
is_grounded(x)
```

## Arguments

- x:

  A `decision`.

## Value

`TRUE` when the decision's grounding is
[`grounding_grounded()`](https://max578.github.io/decideR/reference/grounding_tokens.md).
This does not imply the decision was not abstained; see Details.

## See also

Other decisions:
[`decide()`](https://max578.github.io/decideR/reference/decide.md),
[`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md),
[`decide_position_size()`](https://max578.github.io/decideR/reference/decide_position_size.md),
[`decision()`](https://max578.github.io/decideR/reference/decision.md)

## Examples

``` r
is_grounded(decision(grounding = grounding_grounded()))
#> [1] TRUE
is_grounded(decision(grounding = grounding_unverified()))
#> [1] FALSE
```
