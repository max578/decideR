# A priced quantity with grounding and abstention

The object returned by
[`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md),
[`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md)
and
[`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md).
It records the priced `value`, the `type` of valuation that produced it,
the arithmetic `components` a reader needs in order to audit that value,
and the two Independent Oracle Principle provenance fields: `grounding`,
and the abstention record (`abstained`, `abstain_reason`). When a
valuation abstains, `value` is `NA_real_` – decideR never mints a dollar
figure on evidence its producer did not ground.

## Usage

``` r
valuation(
  value = NA_real_,
  type = NA_character_,
  components = list(),
  grounding = "ungrounded",
  abstained = FALSE,
  abstain_reason = NA_character_,
  baseline = NULL,
  method = NA_character_,
  inputs = list(),
  metadata = list()
)
```

## Arguments

- value:

  The priced quantity, in the utility units of the inputs (currency per
  unit area for a crop valuation, a dimensionless ratio for a
  benefit-cost ratio), or `NA_real_` when abstained.

- type:

  A short valuation type: `"evpi"`, `"evsi"` or `"bcr"`.

- components:

  A named list of the parts the `value` is assembled from, so the number
  can be audited rather than trusted.

- grounding:

  A canonical grounding token.

- abstained:

  `TRUE` when the valuation declined to price the quantity.

- abstain_reason:

  A short reason string, or `NA_character_`.

- baseline:

  The `decision` the current evidence supports, for a value of
  information; `NULL` otherwise.

- method:

  A label recording the valuation rule.

- inputs:

  A named list recording input provenance.

- metadata:

  A named list of free-form metadata.

## Value

A `valuation` S7 object.

## Details

The `abstain_reason` vocabulary extends the `decision` vocabulary with
the reasons specific to pricing: `input_ungrounded`,
`no_feasible_action`, `low_ess`, `degenerate_utility` (all inherited
from the decision that the valuation is built on) and `undefined_ratio`
(a benefit-cost ratio whose discounted cost base is not strictly
positive).

## See also

[`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md),
[`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md),
[`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md).

Other value:
[`bcr_crrdc()`](https://max578.github.io/decideR/reference/bcr_crrdc.md),
[`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md),
[`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md),
[`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md)

## Examples

``` r
v <- valuation(value = 12.4, type = "evpi",
               grounding = grounding_grounded())
v@value
#> [1] 12.4
```
