# Choose an action by expected utility, with grounding and abstention

The shared decision rule. Given `draws` from the posterior of a latent
state \\\theta\\, a `utility` function \\U(a, \theta)\\, and a set of
candidate actions, `decide()` evaluates the expected utility
\\E\_\theta\[U(a, \theta)\]\\ of each feasible candidate by averaging
over the draws and selects the maximiser. It declines to do so –
abstaining to `safe_action` – under any of four conditions, checked in
this order: the combined input `grounding` is not grounded (the
Independent Oracle Principle firewall: never act on an unverified fact);
no candidate satisfies `constraint`; the effective sample size is below
`min_ess` (this trigger is opt-in – it never fires unless the caller
supplies `min_ess`, since there is no universal floor a
decision-agnostic engine can default to); or the chosen action beats the
`safe_action` on fewer than `decisive_prob` of the draws (it is not
clearly better than the status quo). The last check is judged against
the safe action, not the runner-up, so a fine candidate grid does not
trigger spurious indecision; when `safe_action` has no numeric match in
`candidates` (a categorical action set, or an off-grid numeric safe
action) it falls back to the per-draw argmax probability, so the gate
stays live for every candidate shape rather than becoming a no-op.

## Usage

``` r
decide(
  draws,
  utility,
  candidates,
  labels = NULL,
  constraint = NULL,
  grounding = grounding_unverified(),
  safe_action = NULL,
  safe_label = "abstain",
  min_ess = NULL,
  ess = NULL,
  decisive_prob = 0.6,
  method = "expected_utility",
  inputs = list(),
  metadata = list()
)
```

## Arguments

- draws:

  A numeric vector of posterior draws of the latent state.

- utility:

  A function `function(action, theta)` returning a numeric vector of
  utilities the same length as `theta`.

- candidates:

  A numeric vector (or list) of candidate actions.

- labels:

  Optional character labels for the candidates; defaults to a formatted
  `candidates`.

- constraint:

  Optional `function(action)` returning `TRUE` when the action is
  feasible.

- grounding:

  One or more grounding tokens for the inputs; combined worst-case.

- safe_action:

  The action returned on abstention (e.g. a flat position, a zero input
  rate, the status quo).

- safe_label:

  A label for the safe action.

- min_ess:

  Optional effective-sample-size floor; the `low_ess` abstention trigger
  is off by default and fires only when this is set.

- ess:

  Optional effective sample size of `draws`; defaults to
  `length(draws)`.

- decisive_prob:

  The minimum posterior probability that the chosen action beats
  `safe_action`, below which the decision abstains as not clearly better
  than the status quo.

- method:

  A label recording the decision rule.

- inputs:

  A named list recording input provenance.

- metadata:

  A named list of free-form metadata.

## Value

A [decision](https://max578.github.io/decideR/reference/decision.md)
object.

## Details

The grounding label is combined worst-case across `grounding` with
[`combine_grounding()`](https://max578.github.io/decideR/reference/combine_grounding.md),
so passing the provenance of several inputs taints the decision if any
one of them is unverified.

## See also

[`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md)
and
[`decide_position_size()`](https://max578.github.io/decideR/reference/decide_position_size.md)
for domain wrappers;
[decision](https://max578.github.io/decideR/reference/decision.md) for
the returned object.

Other decisions:
[`decide_input_rate()`](https://max578.github.io/decideR/reference/decide_input_rate.md),
[`decide_position_size()`](https://max578.github.io/decideR/reference/decide_position_size.md),
[`decision()`](https://max578.github.io/decideR/reference/decision.md),
[`is_grounded()`](https://max578.github.io/decideR/reference/is_grounded.md)

## Examples

``` r
set.seed(1L)
theta <- rnorm(2000L, mean = 1.2, sd = 0.4)
u <- function(a, theta) -(a - theta)^2
decide(theta, u, candidates = seq(0, 3, by = 0.5),
       grounding = grounding_grounded(), safe_action = 0)
#> <decision> decided  [grounded]
#>   action : 1
#>   E[utility]: -0.2098
#>   candidates: 7 evaluated (method: expected_utility)
```
