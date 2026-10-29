# Choose a crop input rate from an upstream yield manifest

The agronomic manifest tail. Where
[`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md)
takes a yield-draws matrix assembled by the caller,
`decide_rate_from_manifest()` sources that matrix – and the grounding
token – directly from an `orchestra_manifest` emitted upstream (a PESTO
inversion or a mechanistic yield-response posterior). It is the
formalised crop-pipeline tail: a yield posterior in, a profit-optimal,
grounding-aware nitrogen-rate decision out. The grounding rides from the
producer, so an un-grounded yield posterior forces the status-quo rate.

## Usage

``` r
decide_rate_from_manifest(
  manifest,
  rates,
  price_grain,
  price_input,
  safe_rate = 0,
  decisive_prob = 0.6,
  ...
)
```

## Arguments

- manifest:

  An `orchestra_manifest` carrying a yield-per-rate draws matrix (in
  `outputs` or `metadata$yield_draws`), one column per rate.

- rates:

  A numeric vector of candidate input rates, one per column of the
  manifest's draws matrix.

- price_grain:

  Grain price per unit yield.

- price_input:

  Input price per unit rate.

- safe_rate:

  The fallback rate on abstention (default `0`, the no-input status
  quo).

- decisive_prob:

  Minimum posterior probability that the leading rate is best (see
  [`decide()`](https://max578.github.io/decideR/reference/decide.md)).

- ...:

  Further arguments passed to the decision core (e.g. `min_ess`).

## Value

A [decision](https://max578.github.io/decideR/reference/decision.md)
object whose `action` is the chosen rate.

## See also

[`decide_from_manifest()`](https://max578.github.io/decideR/reference/decide_from_manifest.md)
for the generic tail;
[`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md)
for the caller-assembled-matrix form.

Other manifest:
[`decide_from_manifest()`](https://max578.github.io/decideR/reference/decide_from_manifest.md)

## Examples

``` r
set.seed(1L)
rates <- seq(0, 200, by = 25)
demo_manifest <- S7::new_class(
  "demo_manifest",
  properties = list(
    outputs         = S7::new_property(S7::class_any, default = NULL),
    metadata        = S7::new_property(S7::class_list, default = list()),
    summary         = S7::new_property(S7::class_any, default = NULL),
    run_id          = S7::new_property(S7::class_character, default = ""),
    emitter_package = S7::new_property(S7::class_character, default = "")
  )
)
ymax  <- rnorm(1500L, 5.5, 0.3)
yld   <- vapply(rates,
                function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)),
                numeric(1500L))
m <- demo_manifest(
  metadata = list(yield_draws = yld, grounding = grounding_grounded())
)
decide_rate_from_manifest(m, rates, price_grain = 300, price_input = 1.2)
#> <decision> decided  [grounded]
#>   action : 175
#>   E[utility]: 1355
#>   candidates: 9 evaluated (method: expected_profit)
```
