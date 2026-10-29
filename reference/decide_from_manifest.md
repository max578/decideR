# Turn an orchestra manifest into a decision

The manifest-native pipeline tail. Given an `orchestra_manifest` emitted
by any ORCHESTRA member – a PESTO ensemble inversion, a kernR causal
test, a flexyBayes posterior – `decide_from_manifest()` extracts the
predictive draws and the producer's grounding token from the manifest,
then routes them through the same expected-utility engine
[`decide()`](https://max578.github.io/decideR/reference/decide.md) uses.
It is the standard closer of the crop pipeline: an upstream member's
inference becomes a loss-optimal, grounding-aware action without the
caller re-assembling the draws by hand.

## Usage

``` r
decide_from_manifest(
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

  A numeric vector of candidate actions, one per column of the
  manifest's draws matrix; or a numeric vector the `utility` indexes
  freely when the draws are a single posterior vector.

- utility:

  A function `function(action, draws_column)` returning a numeric
  utility per draw, or `NULL` to treat each manifest column as the
  utility of the corresponding candidate directly (the case in which a
  producer has already evaluated the loss per candidate).

- grounding:

  Optional override for the manifest's own grounding token; defaults to
  the token the manifest carries, read worst-case.

- safe_action:

  The action returned on abstention; defaults to the first candidate
  (the status-quo convention for an ordered grid).

- draws_key:

  The `metadata` key under which a draws matrix is sought when the
  `outputs` slot is empty.

- ...:

  Further arguments passed to the decision core (e.g. `min_ess`, `ess`,
  `decisive_prob`, `safe_label`, `method`, `metadata`).

## Value

A [decision](https://max578.github.io/decideR/reference/decision.md)
object whose `inputs` record the manifest's `run_id` and
`emitter_package` for provenance.

## Details

The grounding label rides from the producer through the decision: a
manifest whose payload is ungrounded forces an abstention to
`safe_action`, regardless of how attractive the draws look. This is the
Independent Oracle Principle firewall applied at the pipeline boundary –
decideR never mints a confident recommendation on an upstream fact the
producer did not ground.

decideR does not depend on the contract package; the manifest is read
through its public S7 properties (`outputs`, `metadata`, `summary`). The
draws are sought in the `outputs` slot first, then under
`metadata[[draws_key]]`, so the tail consumes any conforming producer
rather than special-casing each one.

## See also

[`decide_rate_from_manifest()`](https://max578.github.io/decideR/reference/decide_rate_from_manifest.md)
for the agronomic convenience;
[`decide()`](https://max578.github.io/decideR/reference/decide.md) for
the underlying engine.

Other manifest:
[`decide_rate_from_manifest()`](https://max578.github.io/decideR/reference/decide_rate_from_manifest.md)

## Examples

``` r
set.seed(1L)
rates <- seq(0, 200, by = 25)
# In production the manifest is a real `orchestra_manifest` S7 object from
# the composition layer. Here, a minimal S7 stand-in carrying the same
# public properties the tail reads (`outputs`, `metadata`, `summary`,
# `run_id`, `emitter_package`) -- an S3 list is NOT readable by the tail,
# which duck-types through S7 property access.
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
ymax <- rnorm(1500L, 5.5, 0.3)
yld  <- vapply(rates,
               function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)),
               numeric(1500L))
m <- demo_manifest(
  metadata = list(yield_draws = yld, grounding = grounding_grounded())
)
decide_from_manifest(m, candidates = rates,
                     utility = function(r, y) 300 * y - 1.2 * r)
#> <decision> decided  [grounded]
#>   action : 175
#>   E[utility]: 1355
#>   candidates: 9 evaluated (method: manifest_expected_utility)
```
