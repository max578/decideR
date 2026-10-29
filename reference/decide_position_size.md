# Size a trading position by capped expected log-growth under a loss-quantile limit

A reference decision for the trading domain. Given predictive draws of
the next-period simple return, it chooses the fraction of capital that
maximises expected log-growth \\E\[\log(1 + f\\r)\]\\ (the Kelly
objective; Kelly, 1956) over a grid bounded by `kelly_cap`, subject to a
hard one-period loss-quantile constraint: a fraction is feasible only if
its `loss_quantile` return quantile is no worse than `-max_drawdown`.
**This guard is a single-period value-at-risk floor, not a path
drawdown** – `max_drawdown` names the worst `loss_quantile`-fraction of
*next-period* returns the position may be exposed to, not a
peak-to-trough statistic accumulated over a trading path; a true
multi-period drawdown limit is not computed here. With no edge the grid
maximiser is naturally flat; with an edge the constraint caps the size.
It abstains to flat (`0`) when the return evidence is un-grounded – the
capital firewall: never stake real money on a market fact that has not
been verified against the exchange.

## Usage

``` r
decide_position_size(
  return_draws,
  capital,
  max_drawdown,
  kelly_cap = 0.5,
  n_grid = 41L,
  loss_quantile = 0.05,
  grounding = grounding_unverified(),
  decisive_prob = 0.6,
  ...
)
```

## Arguments

- return_draws:

  A numeric vector of predictive next-period simple returns.

- capital:

  The capital available; the dollar position is `fraction * capital`.

- max_drawdown:

  The hard one-period loss-quantile cap (e.g. `0.15`) – a value-at-risk
  floor on the *next-period* return, not a multi-period peak-to-trough
  drawdown.

- kelly_cap:

  The maximum fraction of capital (a fractional-Kelly ceiling).

- n_grid:

  The number of fractions evaluated on `[0, kelly_cap]`.

- loss_quantile:

  The lower return quantile the `max_drawdown` guard is evaluated at.

- grounding:

  One or more grounding tokens for the return evidence; combined
  worst-case.

- decisive_prob:

  Minimum posterior probability that the leading fraction is best (see
  [`decide()`](https://max578.github.io/decideR/reference/decide.md)).

- ...:

  Further arguments passed to the decision core: `min_ess`, `ess`,
  `constraint` (a `function(fraction)` feasibility check, ANDed onto the
  hard drawdown constraint – it can only tighten feasibility, never
  loosen it), `safe_label`, `method`, `metadata`, `inputs`. Any other
  name stops with an error rather than being silently discarded.

## Value

A [decision](https://max578.github.io/decideR/reference/decision.md)
object whose `action` is the chosen fraction of capital; the implied
dollar position is in `@metadata$position`.

## References

Kelly, J. L. (1956). A New Interpretation of Information Rate. *Bell
System Technical Journal*, 35(4), 917-926.

## See also

[`decide()`](https://max578.github.io/decideR/reference/decide.md) for
the underlying engine;
[`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md)
for the agronomic counterpart.

Other decisions:
[`decide()`](https://max578.github.io/decideR/reference/decide.md),
[`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md),
[`decision()`](https://max578.github.io/decideR/reference/decision.md),
[`is_grounded()`](https://max578.github.io/decideR/reference/is_grounded.md)

## Examples

``` r
set.seed(1L)
# a small positive edge with fat tails
r <- 0.004 + 0.02 * rt(4000L, df = 4) / sqrt(2)
decide_position_size(r, capital = 1000, max_drawdown = 0.15,
                     grounding = grounding_grounded())
#> <decision> decided  [grounded]
#>   action : size=50.0% (=500)
#>   E[utility]: 0.002397
#>   candidates: 41 evaluated (method: kelly_log_growth_drawdown_capped)
```
