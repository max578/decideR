# Expected value of one prospective sample from a manifest

Prices a named, finite study before it is run: this soil test, this
trial, at this site. Where
[`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md)
prices perfect knowledge, `decide_evsi()` prices the imperfect knowledge
a real sample would deliver, \$\$EVSI = E_y\[\max_a E\_{\theta \mid
y}\[U(a, \theta)\]\] - \max_a E\_\theta\[U(a, \theta)\],\$\$ the
expected gain from being allowed to decide after seeing the data rather
than before. It is bounded above by the EVPI, which the valuation
reports beside it as a ceiling.

## Usage

``` r
decide_evsi(
  manifest,
  candidates,
  sample_design,
  utility = NULL,
  state = NULL,
  state_key = NULL,
  n_pre = 500L,
  grounding = NULL,
  safe_action = NULL,
  draws_key = "yield_draws",
  ...
)
```

## Arguments

- manifest:

  An `orchestra_manifest` S7 object, as for
  [`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md).

- candidates:

  A numeric vector (or list) of candidate actions.

- sample_design:

  A named list describing the prospective sample: `simulate` (a
  `function(state)` returning one hypothetical dataset drawn at that
  latent state), `loglik` (a `function(y, state)` returning the
  log-likelihood of that dataset at every state draw, one value per
  draw), and optionally `label`, `n_obs` and `cost`.

- utility:

  A function `function(action, draws_column)`, or `NULL` when each
  manifest column is already the utility of its candidate.

- state:

  Optional numeric vector, one latent-state value per draw, that the
  prospective sample informs.

- state_key:

  Optional name of a column of the manifest's `params` data.frame to
  read the state from.

- n_pre:

  The number of outer (pre-posterior) draws.

- grounding:

  Optional override for the manifest's own grounding token.

- safe_action:

  The action the baseline decision abstains to.

- draws_key:

  The `metadata` key under which a draws matrix is sought when the
  `outputs` slot is empty.

- ...:

  Further arguments passed to the decision core (e.g. `constraint`,
  `decisive_prob`).

## Value

A [valuation](https://max578.github.io/decideR/reference/valuation.md)
of `type = "evsi"`, whose `components` carry the pre-posterior and
current-information expectations, the EVPI ceiling, the weight
diagnostics, and – when `sample_design$cost` is supplied – the cost and
the net value.

## Details

The pre-posterior expectation is evaluated by the standard two-loop
Monte Carlo algorithm: draw a latent state from the current posterior,
simulate the dataset the sample would produce at that state, update, and
re-decide. The inner update here is an importance re-weighting of the
manifest's own draws by the sampling log-likelihood rather than a nested
re-fit, so the manifest stays the single source of the posterior and
decideR adds no sampler. That re-weighting degenerates when the
prospective sample is very much more informative than the current
posterior; the effective sample size of the weights is therefore
computed at every outer draw, reported in `components$weight_ess_min`,
and warned about when it collapses.

The estimate is a Monte Carlo one and is reported unclamped. A small
negative value is Monte Carlo noise around a true value near zero – a
sample worth nothing – and is not silently floored at zero.

## References

Raiffa, H. and Schlaifer, R. (1961) *Applied Statistical Decision
Theory*. Boston: Harvard University Graduate School of Business
Administration.

Ades, A. E., Lu, G. and Claxton, K. (2004) Expected value of sample
information calculations in medical decision modeling. *Medical Decision
Making*, 24(2), 207–227.
[doi:10.1177/0272989X04263162](https://doi.org/10.1177/0272989X04263162)

## See also

[`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md)
for the ceiling on any sample's value.

Other value:
[`bcr_crrdc()`](https://max578.github.io/decideR/reference/bcr_crrdc.md),
[`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md),
[`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md),
[`valuation()`](https://max578.github.io/decideR/reference/valuation.md)

## Examples

``` r
set.seed(2L)
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
# A posterior for the yield gain from a nitrogen top-up, in t/ha.
gain <- rnorm(600L, mean = 0.10, sd = 0.35)
m <- demo_manifest(
  outputs  = matrix(gain, ncol = 1L),
  metadata = list(grounding = grounding_grounded())
)
# A four-plot strip trial measuring the gain, observation sd 0.5.
trial <- list(
  label    = "4-plot strip trial",
  n_obs    = 4L,
  cost     = 0.02,
  simulate = function(state) mean(rnorm(4L, state, 0.5)),
  loglik   = function(y, state) dnorm(y, state, 0.5 / sqrt(4), log = TRUE)
)
decide_evsi(m, candidates = c(0, 1), sample_design = trial,
            utility = function(a, g) a * g, n_pre = 200L)
#> <valuation: evsi> priced  [grounded]
#>   value : 0.059459
#>   expected_utility_preposterior: 0.19218
#>   expected_utility_current_information: 0.13272
#>   evsi:          0.059459
#>   evpi_ceiling:  0.088082
#>   n_pre:         200
#>   n_draws:       600
#>   weight_ess_min: 8.9613
#>   weight_ess_mean: 342.02
#>   mc_se:         0.014113
#>   n_obs:         4
#>   cost:          0.02
#>   net_value:     0.039459
#>   method: evsi_preposterior_importance_weights
```
