# Benefit-cost ratio of a research investment

Discounts a stream of benefits and a stream of costs at an explicit rate
over an explicit horizon and reports the components an impact assessment
is written from – the two streams, the present value of each, the net
present value, and the ratio: \$\$PV = \sum\_{t=0}^{H-1} \frac{x_t}{(1 +
r)^t}, \quad NPV = PV_B - PV_C, \quad BCR = PV_B / PV_C.\$\$ This is the
CRRDC-style reporting set an Australian rural research and development
impact assessment closes with. decideR encodes no guideline default for
the rate or the horizon: both are stated by the assessment the analysis
serves and are the caller's to supply, so a ratio can never be quoted
against an assumption its author did not make.

## Usage

``` r
decide_bcr(
  benefits = NULL,
  costs,
  discount_rate,
  horizon = NULL,
  grounding = NULL,
  manifest = NULL,
  draws_key = "benefit_draws",
  probs = c(0.05, 0.5, 0.95),
  metadata = list()
)
```

## Arguments

- benefits:

  The benefit stream: a numeric vector, one value per period from
  `t = 0`, or a numeric matrix of posterior draws (rows) by periods
  (columns). May be `NULL` when `manifest` supplies it.

- costs:

  The cost stream, a numeric vector, one value per period from `t = 0`.

- discount_rate:

  The real discount rate per period, as a proportion (e.g. `0.05` for
  five per cent).

- horizon:

  The number of periods, `t = 0, ..., horizon - 1`; defaults to the
  longer of the two streams.

- grounding:

  Optional grounding token(s) for the streams, combined worst-case;
  defaults to the manifest's own token, or to
  [`grounding_unverified()`](https://max578.github.io/decideR/reference/grounding_tokens.md)
  when no manifest is supplied.

- manifest:

  Optional `orchestra_manifest` S7 object supplying the benefit stream
  and its grounding.

- draws_key:

  The `metadata` key under which the benefit draws are sought when the
  manifest's `outputs` slot is empty.

- probs:

  Quantiles at which the posterior ratio is summarised when the benefit
  stream arrives as draws.

- metadata:

  A named list of free-form metadata.

## Value

A [valuation](https://max578.github.io/decideR/reference/valuation.md)
of `type = "bcr"` whose `value` is the ratio and whose `components`
carry the discounted streams, the two present values and the net present
value.

## Details

Period `t = 0` is the present and is not discounted. A stream given as
end-of-period cash flows is expressed by leading it with a zero, as in
the worked example below. Streams shorter than the horizon are
zero-padded; a stream longer than the horizon is an error rather than a
silent truncation.

When `manifest` is supplied, the benefit stream and its grounding token
are read from it through the same duck-typed contract accessors the
decision tail uses (`outputs`, then `metadata[[draws_key]]`; grounding
from `metadata$grounding` or `summary$metrics$grounding`), with draws in
rows and periods in columns. The point estimate then uses the posterior
mean stream, and the posterior distribution of the ratio is summarised
in `components$bcr_quantiles`. An ungrounded manifest returns an
abstained valuation, never a ratio.

## See also

[`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md)
for the value of the next study rather than of the whole programme.

Other value:
[`bcr_crrdc()`](https://max578.github.io/decideR/reference/bcr_crrdc.md),
[`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md),
[`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md),
[`valuation()`](https://max578.github.io/decideR/reference/valuation.md)

## Examples

``` r
# A two-period investment: 100 spent now, 210 returned next period, at a
# five per cent discount rate. PV(costs) = 100, PV(benefits) = 210/1.05 =
# 200, so NPV = 100 and BCR = 2.
v <- decide_bcr(benefits = c(0, 210), costs = c(100, 0),
                discount_rate = 0.05,
                grounding = grounding_grounded())
v@value
#> [1] 2
v@components$npv
#> [1] 100

# The same investment on an un-grounded benefit stream prices out as an
# abstention rather than as a ratio.
decide_bcr(benefits = c(0, 210), costs = c(100, 0), discount_rate = 0.05)
#> <valuation: bcr> ABSTAINED (input_ungrounded)  [ungrounded]
#>   method: discounted_benefit_cost_ratio
```
