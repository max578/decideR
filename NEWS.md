# decideR (development version)

Fixes from the 2026-08-25 ORCHESTRA fitness audit (all CONFIRMED CRITICAL/HIGH
findings except the value-of-information verbs, deferred to a later wave).

## Bug fixes

* The decisiveness gate no longer silently no-ops for a categorical candidate
  set or an off-grid numeric `safe_action` (D-01). `.match_candidate()`
  returning no numeric match now falls back to the per-draw argmax
  probability, so the gate stays live for every candidate shape instead of
  becoming inert -- previously `decide()`'s own `safe_action = NULL` default,
  and every list/categorical candidate set, disabled the check with no
  warning.
* `decide_input_rate()` and `decide_position_size()` no longer silently
  discard `constraint`, `safe_label`, `method`, `metadata`, and `inputs`
  passed through `...` (D-02). Both now harvest the documented `...` names and
  stop loudly on an unrecognised one rather than accepting and dropping it. A
  caller `constraint` to `decide_position_size()` ANDs onto the hard drawdown
  guard rather than replacing it.
* `print.grade_band_value()` now dispatches on an installed package. The S3
  method was correctly registered in the package's own method table but never
  reached by `print()`'s ordinary S3 dispatch once `S7::methods_register()`
  had run (D-03) -- the package's headline loss primitive printed as a raw
  closure dump. `.onLoad()` now explicitly re-registers the method after
  `S7::methods_register()`.
* `decide()` (and every reference decision routed through the shared core)
  now abstains with a new `degenerate_utility` reason instead of failing with
  an opaque base-R error when every feasible candidate's expected utility is
  `NA`/`NaN` (D-04).
* `decide_from_manifest()` now accepts a manifest whose draws are a single
  posterior column (the shape a flexyBayes posterior arrives in), recycling
  it across every candidate when `utility` is supplied, rather than refusing
  with a column-count mismatch (D-06).
* The roxygen `@examples` for `decide_from_manifest()` and
  `decide_rate_from_manifest()` now build a readable S7 stand-in and actually
  run the manifest-tail call, rather than wrapping it in `\dontrun{}` around
  an undefined variable (D-07).

## Documentation

* Clarified that the `low_ess` abstention trigger is opt-in -- it never fires
  unless the caller supplies `min_ess` -- in `decide()`'s roxygen and the
  vignette's abstention table (D-05).
* `decide_position_size()`'s `max_drawdown` is now documented as a hard
  *one-period* loss-quantile (value-at-risk) floor, not a multi-period
  peak-to-trough drawdown statistic, which the previous wording could be read
  to promise (D-09).
* `is_grounded()`'s roxygen and the vignette's abstention section now state
  the correct downstream gate: `is_grounded()` alone is `TRUE` for a decision
  that abstained for `no_feasible_action`, `low_ess`, or
  `insufficient_evidence`, since none of those reasons downgrades the
  grounding label; a consumer that must also refuse an abstained decision
  gates on `is_grounded(x) && !x@abstained` (D-14).
* Named the Kelly (1956) reference for `decide_position_size()`'s expected
  log-growth objective and fixed a grammatical ellipsis in
  `decide_from_manifest()`'s `utility` documentation.
* `_pkgdown.yml` now groups the reference index into four named sections
  (Decisions, Manifest tail, Grounding, Loss) keyed to the existing
  `@family` tags, replacing the single undifferentiated catch-all list
  (D-17).
* Copy-edited five grammar/sharpness issues in the getting-started vignette
  and the README (mass-noun agreement, an elliptical "act ... when you
  should", a subject-verb number mismatch, a trailing preposition, a missing
  "in which") (D-18).
* The getting-started vignette now carries two figures -- the nitrogen-rate
  candidate ledger and the grade-band schedule with the chosen rate's protein
  posterior overlaid -- each with a caption and an interpreting sentence; the
  vignette previously shipped with no figures at all (D-13).
* `README.Rmd` now knits with `md_extensions: -smart`, so the generated
  `README.md` uses plain ASCII `--` throughout instead of pandoc's
  smart-typography en dashes (D-20); `README.md` re-knitted, which also
  fixes the stale example output that printed `grade_band_value()`'s return
  as a raw closure dump instead of the band table (the D-03 print-dispatch
  fix landed after the README was last knitted).

## Testing

* Added a `Suggests`-guarded test that drives `decide_rate_from_manifest()`
  through a REAL `orchestra_manifest` built from the ORCHESTRA workspace's own
  reference contract (hash-verified), rather than only ever consuming a
  decideR-authored stand-in -- the Independent Oracle Principle gap the audit
  named (D-08). Skips cleanly when the workspace is not present alongside the
  package.

## Infrastructure

* Replaced the R-CMD-check GitHub Actions workflow with the estate's
  known-green template (the previous workflow had never completed a real
  build in this repository's history) (D-10).
* An abstained `decision` now carries an additional `"decideR_abstention"`
  class tag (recognised by the ORCHESTRA leader-node's cross-member
  `is_orchestra_decline()` predicate) alongside its existing S7 class, so a
  decideR abstention is identifiable at a cross-member seam without the
  consumer depending on decideR's namespace.

# decideR 0.1.0

First formal release. `decideR` is the decision layer of the ORCHESTRA
analytics framework: the loss-optimal, grounding-aware closer of the
inference-to-decision loop. It maps a posterior -- or an upstream member's
`orchestra_manifest` inference result -- into an action under an explicit
utility and a hard feasibility constraint, with calibrated abstention and an
Independent Oracle Principle grounding firewall. This release adds the
manifest-native pipeline tail and the grade-band loss primitive, and formalises
the decision engine, grounding vocabulary, and reference decisions that the
development series exercised.

## New features

* Add a manifest-native pipeline tail. `decide_from_manifest()` turns an
  upstream `orchestra_manifest` into a `decision` by reading the predictive
  draws and the producer's grounding token straight off the manifest, then
  routing them through the same expected-utility engine `decide()` uses. The
  grounding rides from the producer through the decision, so an `[unverified]`
  payload forces an abstention at the pipeline boundary. `decideR` does not
  depend on the contract package: the manifest is read through its public S7
  properties (`outputs`, `metadata`, `summary`), so the tail consumes any
  conforming producer rather than special-casing each one.
* Add `decide_rate_from_manifest()`, the agronomic convenience that sources a
  yield-per-rate posterior and its grounding from a manifest and emits a
  profit-optimal nitrogen-rate decision -- the formalised crop-pipeline tail.
* Add a grade-band (threshold-economics) loss primitive. `grade_band_value()`
  builds a step value schedule whose payoff jumps at quality breakpoints (a
  grain price that steps up as protein clears a milling and a premium
  threshold, say), and `grade_band_utility()` turns the schedule into a
  `decide()`-ready utility. Under a step payoff the optimal decision is governed
  by the posterior probability of clearing each band, not by the posterior mean.
  This is a building block for the future `grainPlan` orchestrator.

## Formalised in this release

* `decide()` chooses the feasible action of greatest expected utility over
  posterior draws, abstaining to a safe action on any of four triggers --
  un-grounded input, no feasible action, low effective sample size, or a move
  that is not clearly better than the status quo.
* `decide_input_rate()` and `decide_position_size()` are two reference
  decisions -- a crop nitrogen rate chosen by expected profit, and a trading
  position size chosen by drawdown-capped expected log-growth -- that route
  through the same engine, demonstrating one decision layer across two domains.
* `decision` is the S7 result class, carrying the chosen action, the candidate
  ledger, the grounding label, and the abstention record, with `print()` and
  `is_grounded()` methods.
* `grounding_grounded()`, `grounding_unverified()`, and `combine_grounding()`
  are the canonical provenance vocabulary, hardcoded to match the ORCHESTRA
  federation's `[unverified]` / `grounded` tokens (worst-case combination: one
  un-grounded input taints the decision).
