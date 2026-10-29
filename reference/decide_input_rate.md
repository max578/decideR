# Choose a crop input rate by expected profit

A reference decision for the agronomic domain. Given posterior draws of
yield at each candidate input rate – the kind of object a
mechanistic-simulator inversion (PESTO) or a causal test (kernR) emits –
it selects the rate that maximises expected profit, \\E\[p_y\\y(r) -
p_r\\r\]\\, where \\p_y\\ is the grain price and \\p_r\\ the input
price. It abstains to `safe_rate` when the yield evidence is un-grounded
or the leading rate is not decisive.

## Usage

``` r
decide_input_rate(
  yield_draws,
  rates,
  price_grain,
  price_input,
  grounding = grounding_unverified(),
  safe_rate = 0,
  decisive_prob = 0.6,
  ...
)
```

## Arguments

- yield_draws:

  A numeric matrix of posterior yield draws, one column per candidate
  rate (rows are draws).

- rates:

  A numeric vector of candidate input rates, one per column of
  `yield_draws`.

- price_grain:

  Grain price per unit yield.

- price_input:

  Input price per unit rate.

- grounding:

  One or more grounding tokens for the yield evidence; combined
  worst-case.

- safe_rate:

  The fallback rate on abstention (default `0`, the no-input status
  quo).

- decisive_prob:

  Minimum posterior probability that the leading rate is best (see
  [`decide()`](https://max578.github.io/decideR/reference/decide.md)).

- ...:

  Further arguments passed to the decision core: `min_ess`, `ess`,
  `constraint` (a `function(rate)` feasibility check), `safe_label`,
  `method`, `metadata`, `inputs`. Any other name stops with an error
  rather than being silently discarded.

## Value

A [decision](https://max578.github.io/decideR/reference/decision.md)
object whose `action` is the chosen rate.

## See also

[`decide()`](https://max578.github.io/decideR/reference/decide.md) for
the underlying engine;
[`decide_position_size()`](https://max578.github.io/decideR/reference/decide_position_size.md)
for the trading counterpart.

Other decisions:
[`decide()`](https://max578.github.io/decideR/reference/decide.md),
[`decide_position_size()`](https://max578.github.io/decideR/reference/decide_position_size.md),
[`decision()`](https://max578.github.io/decideR/reference/decision.md),
[`is_grounded()`](https://max578.github.io/decideR/reference/is_grounded.md)

## Examples

``` r
set.seed(1L)
rates <- seq(0, 200, by = 40)
# diminishing-returns yield response with posterior noise
mu <- 3 + 2.5 * (1 - exp(-rates / 80))
yield_draws <- sapply(mu, function(m) rnorm(1500L, m, 0.3))
decide_input_rate(yield_draws, rates, price_grain = 300, price_input = 1.2,
                  grounding = grounding_grounded())
#> <decision> decided  [grounded]
#>   action : rate=160
#>   E[utility]: 1355
#>   candidates: 6 evaluated (method: expected_profit)
```
