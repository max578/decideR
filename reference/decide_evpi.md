# Expected value of perfect information from a manifest

Prices what it would be worth to learn the latent state exactly before
acting. Given the same manifest, candidate set and utility that
[`decide_from_manifest()`](https://max578.github.io/decideR/reference/decide_from_manifest.md)
takes, `decide_evpi()` returns \$\$EVPI = E\_\theta\[\max_a U(a,
\theta)\] - \max_a E\_\theta\[U(a, \theta)\],\$\$ the difference between
deciding with the state known and deciding with only its posterior. It
is the ceiling on the value of any study, trial or measurement
addressing that state: no finite sample can be worth more, which is what
makes it the natural first screen before an experiment is designed.

## Usage

``` r
decide_evpi(
  manifest,
  candidates,
  utility = NULL,
  grounding = NULL,
  safe_action = NULL,
  draws_key = "yield_draws",
  ...
)
```

## Arguments

- manifest:

  An `orchestra_manifest` S7 object (or any S7 object exposing the
  contract's `outputs` / `metadata` / `summary` properties).

- candidates:

  A numeric vector (or list) of candidate actions.

- utility:

  A function `function(action, draws_column)` returning a numeric
  utility per draw, or `NULL` when each manifest column is already the
  utility of the corresponding candidate.

- grounding:

  Optional override for the manifest's own grounding token.

- safe_action:

  The action the baseline decision abstains to; defaults to the first
  candidate.

- draws_key:

  The `metadata` key under which a draws matrix is sought when the
  `outputs` slot is empty.

- ...:

  Further arguments passed to the decision core (e.g. `constraint`,
  `min_ess`, `ess`, `decisive_prob`).

## Value

A [valuation](https://max578.github.io/decideR/reference/valuation.md)
of `type = "evpi"`. Its `components` carry the two expectations the
value is the difference of, the draw count and the number of feasible
candidates; `@baseline` carries the decision current evidence supports.

## Details

The expectation runs over the feasible candidates only, so a hard
constraint passed through `...` prices the information available
*within* the actions the grower or the agency can actually take, not
within a wider hypothetical set.

Grounding rides from the producer exactly as it does for a decision: an
ungrounded manifest returns an abstained `valuation` with
`abstain_reason = "input_ungrounded"` and `value = NA_real_`. The other
blocking reasons are `no_feasible_action`, `low_ess` and
`degenerate_utility`. An `insufficient_evidence` baseline decision is
*not* blocking: a too-close-to-call decision is precisely where
information pays, and the indecisive decision is returned in
`@baseline`.

## References

Raiffa, H. and Schlaifer, R. (1961) *Applied Statistical Decision
Theory*. Boston: Harvard University Graduate School of Business
Administration.

## See also

[`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md)
for the value of one finite sample;
[`decide_from_manifest()`](https://max578.github.io/decideR/reference/decide_from_manifest.md)
for the decision the value is measured against.

Other value:
[`bcr_crrdc()`](https://max578.github.io/decideR/reference/bcr_crrdc.md),
[`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md),
[`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md),
[`valuation()`](https://max578.github.io/decideR/reference/valuation.md)

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
ymax <- rnorm(800L, 5.5, 0.6)
yld  <- vapply(rates,
               function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)),
               numeric(800L))
m <- demo_manifest(
  metadata = list(yield_draws = yld, grounding = grounding_grounded())
)
decide_evpi(m, candidates = rates,
            utility = function(r, y) 300 * y - 1.2 * r)
#> <valuation: evpi> priced  [grounded]
#>   value : 3.7097
#>   expected_utility_perfect_information: 1357
#>   expected_utility_current_information: 1353.2
#>   evpi:          3.7097
#>   n_draws:       800
#>   n_feasible_candidates: 9
#>   method: evpi_expected_utility
```
