# Build a decide() utility from a grade-band schedule

Turns a
[grade_band_value](https://max578.github.io/decideR/reference/grade_band_value.md)
schedule into a `utility(action, theta)` function the decision engine
consumes. `theta` is a posterior draw of the quality outcome (grain
protein, say); the action shifts that outcome through `quality_shift`, a
function `function(action, theta)` returning the realised quality under
the action. The utility of an action at a draw is the band payoff of the
shifted outcome, less an optional per-unit action cost. Because the
payoff is a step function, the expected utility decideR averages over
the draws is governed by each band's posterior probability – exactly the
threshold economics a quality-graded decision faces.

## Usage

``` r
grade_band_utility(value, quality_shift = NULL, cost = 0)
```

## Arguments

- value:

  A
  [grade_band_value](https://max578.github.io/decideR/reference/grade_band_value.md)
  schedule.

- quality_shift:

  A function `function(action, theta)` returning the realised quality
  outcome under the action, or `NULL` for the additive default
  `theta + action`.

- cost:

  A function `function(action)` returning the action's cost, or a single
  numeric per-unit cost applied as `cost * action`, or `0` for no cost.

## Value

A function `function(action, theta)` suitable as the `utility` argument
to [`decide()`](https://max578.github.io/decideR/reference/decide.md).

## Details

When `quality_shift` is left `NULL` the action is taken to *be* the
quality outcome offset added to `theta` (the common case where an input
nudges the outcome additively), so `quality = theta + action`. Supply a
`quality_shift` for any non-additive response (a saturating
dose-response, say).

## See also

[`grade_band_value()`](https://max578.github.io/decideR/reference/grade_band_value.md)
for the schedule;
[`decide()`](https://max578.github.io/decideR/reference/decide.md) for
the engine.

Other loss:
[`grade_band_value()`](https://max578.github.io/decideR/reference/grade_band_value.md)

## Examples

``` r
v <- grade_band_value(c(10.5, 11.5, 13), c(300, 330, 360, 400))
# A nitrogen rate lifts protein additively; protein costs nothing but N does.
u <- grade_band_utility(v, quality_shift = function(rate, protein)
                          protein + 0.01 * rate, cost = 1.2)
set.seed(1L)
protein <- rnorm(2000L, mean = 11.0, sd = 0.6)
decide(protein, u, candidates = seq(0, 150, by = 25),
       grounding = grounding_grounded(), safe_action = 0)
#> <decision> decided  [grounded]
#>   action : 0
#>   E[utility]: 330
#>   candidates: 7 evaluated (method: expected_utility)
```
