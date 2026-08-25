# =============================================================================
# The manifest-native pipeline tail
# =============================================================================
# decideR is the standard tail of an ORCHESTRA pipeline: an upstream member
# (PESTO inversion, a kernR TACI test, a flexyBayes posterior) emits an
# `orchestra_manifest` carrying predictive draws, and decideR turns that
# manifest into a `decision`. These functions are that bridge. They read the
# manifest by its public contract -- the draws matrix and the grounding token --
# never by special-casing the producer, so the same tail consumes any
# member's manifest. decideR deliberately does NOT depend on the contract
# package: the manifest type is duck-typed through S7 property access (the same
# composition-layer convention proxymix's and the conductor's adapters use),
# which keeps decideR's lean two-Import surface and avoids coupling its MIT
# release to the contract's home repository.

# Read a named property off an S7 manifest without taking a hard dependency on
# the contract class. Returns `default` when the object is not an S7 object that
# carries the property, so a malformed input fails in the calling validator with
# a decideR message rather than an opaque S7 error.
.manifest_prop <- function(m, name, default = NULL) {
  ok <- isTRUE(tryCatch(S7::S7_inherits(m), error = function(e) FALSE)) &&
    name %in% S7::prop_names(m)
  if (ok) S7::prop(m, name) else default
}

# Pull the predictive-draws matrix out of a manifest. The orchestra contract
# carries prediction draws in the `outputs` slot (manifest spec table, §3); the
# composition layer also stashes a domain draws matrix under a `metadata` key
# (e.g. `yield_draws`) when the producer is a stand-in. We look in `outputs`
# first, then fall back to the `metadata` key, so the tail reads the contract
# generically and still consumes the federation's current conductor producers.
# Returns a numeric matrix (draws in rows, candidates in columns) or stops.
.manifest_draws <- function(m, draws_key = "yield_draws") {
  draws <- .manifest_prop(m, "outputs")
  if (is.null(draws)) {
    meta <- .manifest_prop(m, "metadata", default = list())
    draws <- meta[[draws_key]]
  }
  if (is.null(draws)) {
    stop(
      sprintf(
        "manifest carries no predictive draws in `outputs` or `metadata$%s`",
        draws_key
      ),
      call. = FALSE
    )
  }
  draws <- as.matrix(draws)
  if (!is.numeric(draws) || nrow(draws) == 0L || ncol(draws) == 0L) {
    stop("manifest draws must be a non-empty numeric matrix", call. = FALSE)
  }
  draws
}

# Read the grounding token a manifest carries for its payload. The federation's
# convention records it at `metadata$grounding`, with the typed
# `summary$metrics$grounding` as the secondary home. Anything else -- including
# a manifest that never set a token -- is treated as un-grounded, the honest
# Independent Oracle Principle default. The returned token is validated against
# the canonical vocabulary by the decision engine downstream.
.manifest_grounding <- function(m) {
  meta <- .manifest_prop(m, "metadata", default = list())
  if (!is.null(meta[["grounding"]])) {
    return(as.character(meta[["grounding"]]))
  }
  summ <- .manifest_prop(m, "summary")
  if (!is.null(summ) && is.list(summ) && !is.null(summ$metrics$grounding)) {
    return(as.character(summ$metrics$grounding))
  }
  grounding_unverified()
}

# -----------------------------------------------------------------------------
# Exported manifest tail
# -----------------------------------------------------------------------------

#' Turn an orchestra manifest into a decision
#'
#' The manifest-native pipeline tail. Given an `orchestra_manifest` emitted by
#' any ORCHESTRA member -- a PESTO ensemble inversion, a kernR causal test, a
#' flexyBayes posterior -- `decide_from_manifest()` extracts the predictive
#' draws and the producer's grounding token from the manifest, then routes them
#' through the same expected-utility engine [decide()] uses. It is the standard
#' closer of the crop pipeline: an upstream member's inference becomes a
#' loss-optimal, grounding-aware action without the caller re-assembling the
#' draws by hand.
#'
#' The grounding label rides from the producer through the decision: a manifest
#' whose payload is `[unverified]` forces an abstention to `safe_action`,
#' regardless of how attractive the draws look. This is the Independent Oracle
#' Principle firewall applied at the pipeline boundary -- decideR never mints a
#' confident recommendation on an upstream fact the producer did not ground.
#'
#' decideR does not depend on the contract package; the manifest is read through
#' its public S7 properties (`outputs`, `metadata`, `summary`). The draws are
#' sought in the `outputs` slot first, then under `metadata[[draws_key]]`, so the
#' tail consumes any conforming producer rather than special-casing each one.
#'
#' @param manifest An `orchestra_manifest` S7 object (or any S7 object exposing
#'   the contract's `outputs` / `metadata` / `summary` properties).
#' @param candidates A numeric vector of candidate actions, one per column of
#'   the manifest's draws matrix; or a numeric vector the `utility` indexes
#'   freely when the draws are a single posterior vector.
#' @param utility A function `function(action, draws_column)` returning a numeric
#'   utility per draw, or `NULL` to treat each manifest column as the utility of
#'   the corresponding candidate directly (the case a producer has already
#'   evaluated the loss per candidate).
#' @param grounding Optional override for the manifest's own grounding token;
#'   defaults to the token the manifest carries, read worst-case.
#' @param safe_action The action returned on abstention; defaults to the first
#'   candidate (the status-quo convention for an ordered grid).
#' @param draws_key The `metadata` key under which a draws matrix is sought when
#'   the `outputs` slot is empty.
#' @param ... Further arguments passed to the decision core (e.g. `min_ess`,
#'   `ess`, `decisive_prob`, `safe_label`, `method`, `metadata`).
#' @return A [decision] object whose `inputs` record the manifest's `run_id` and
#'   `emitter_package` for provenance.
#' @examples
#' set.seed(1L)
#' rates <- seq(0, 200, by = 25)
#' # a manifest-shaped object: yield draws per rate in `metadata$yield_draws`
#' ymax <- rnorm(1500L, 5.5, 0.3)
#' yld  <- vapply(rates,
#'                function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)),
#'                numeric(1500L))
#' fake_manifest <- structure(
#'   list(metadata = list(yield_draws = yld, grounding = grounding_grounded())),
#'   class = "demo_manifest"
#' )
#' \dontrun{
#' # with a real orchestra_manifest from the composition layer:
#' decide_from_manifest(m, candidates = rates,
#'                      utility = function(r, y) 300 * y - 1.2 * r)
#' }
#' @seealso [decide_rate_from_manifest()] for the agronomic convenience;
#'   [decide()] for the underlying engine.
#' @family manifest
#' @export
decide_from_manifest <- function(manifest, candidates, utility = NULL,
                                 grounding = NULL, safe_action = NULL,
                                 draws_key = "yield_draws", ...) {
  draws <- .manifest_draws(manifest, draws_key = draws_key)
  n_cand <- length(candidates)
  if (n_cand == 0L) {
    stop("`candidates` must hold at least one action", call. = FALSE)
  }
  if (ncol(draws) != n_cand) {
    stop(
      sprintf(
        "manifest draws have %d columns but `candidates` has %d actions",
        ncol(draws), n_cand
      ),
      call. = FALSE
    )
  }

  # Provenance: carry the producer's grounding worst-case unless the caller
  # overrides, and record the manifest identity in the decision's inputs.
  g <- if (is.null(grounding)) .manifest_grounding(manifest) else grounding
  g <- combine_grounding(g)
  inputs <- list(
    manifest_run_id  = .manifest_prop(manifest, "run_id", default = NA_character_),
    emitter_package  = .manifest_prop(manifest, "emitter_package",
                                      default = NA_character_)
  )

  # Assemble the per-draw, per-candidate utility matrix. When `utility` is NULL
  # each manifest column is taken as the candidate's utility directly (a
  # producer that already evaluated the loss); otherwise the column is the
  # posterior draws fed to the utility for that candidate.
  util_matrix <- if (is.null(utility)) {
    draws
  } else {
    if (!is.function(utility)) {
      stop("`utility` must be NULL or a function of (action, draws_column)",
           call. = FALSE)
    }
    vapply(
      seq_len(n_cand),
      function(j) {
        u <- utility(candidates[[j]], draws[, j])
        if (length(u) != nrow(draws)) {
          stop("`utility` must return one value per draw", call. = FALSE)
        }
        as.numeric(u)
      },
      numeric(nrow(draws))
    )
  }

  labels <- as.character(candidates)
  if (is.null(safe_action)) {
    safe_action <- candidates[[1L]]
  }
  dots <- list(...)
  .decide_core(
    util_matrix   = util_matrix,
    candidates    = candidates,
    labels        = labels,
    constraint    = dots[["constraint"]],
    grounding     = g,
    safe_action   = safe_action,
    safe_label    = dots[["safe_label"]] %||% "abstain (status quo)",
    min_ess       = dots[["min_ess"]],
    ess           = dots[["ess"]],
    decisive_prob = dots[["decisive_prob"]] %||% 0.6,
    method        = dots[["method"]] %||% "manifest_expected_utility",
    inputs        = inputs,
    metadata      = dots[["metadata"]] %||% list()
  )
}

#' Choose a crop input rate from an upstream yield manifest
#'
#' The agronomic manifest tail. Where [decide_input_rate()] takes a yield-draws
#' matrix assembled by the caller, `decide_rate_from_manifest()` sources that
#' matrix -- and the grounding token -- directly from an `orchestra_manifest`
#' emitted upstream (a PESTO inversion or a TACI yield-response posterior). It is
#' the formalised crop-pipeline tail: a yield posterior in, a profit-optimal,
#' grounding-aware nitrogen-rate decision out. The grounding rides from the
#' producer, so an un-grounded yield posterior forces the status-quo rate.
#'
#' @param manifest An `orchestra_manifest` carrying a yield-per-rate draws
#'   matrix (in `outputs` or `metadata$yield_draws`), one column per rate.
#' @param rates A numeric vector of candidate input rates, one per column of the
#'   manifest's draws matrix.
#' @param price_grain Grain price per unit yield.
#' @param price_input Input price per unit rate.
#' @param safe_rate The fallback rate on abstention (default `0`, the no-input
#'   status quo).
#' @param decisive_prob Minimum posterior probability that the leading rate is
#'   best (see [decide()]).
#' @param ... Further arguments passed to the decision core (e.g. `min_ess`).
#' @return A [decision] object whose `action` is the chosen rate.
#' @examples
#' set.seed(1L)
#' rates <- seq(0, 200, by = 25)
#' ymax  <- rnorm(1500L, 5.5, 0.3)
#' yld   <- vapply(rates,
#'                 function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)),
#'                 numeric(1500L))
#' m <- structure(
#'   list(metadata = list(yield_draws = yld, grounding = grounding_grounded())),
#'   class = "demo_manifest"
#' )
#' \dontrun{
#' decide_rate_from_manifest(m, rates, price_grain = 300, price_input = 1.2)
#' }
#' @seealso [decide_from_manifest()] for the generic tail;
#'   [decide_input_rate()] for the caller-assembled-matrix form.
#' @family manifest
#' @export
decide_rate_from_manifest <- function(manifest, rates, price_grain, price_input,
                                      safe_rate = 0, decisive_prob = 0.6, ...) {
  decide_from_manifest(
    manifest      = manifest,
    candidates    = rates,
    utility       = function(r, y) price_grain * y - price_input * r,
    safe_action   = safe_rate,
    safe_label    = sprintf("rate=%g (status quo)", safe_rate),
    decisive_prob = decisive_prob,
    method        = "expected_profit",
    metadata      = list(domain = "agronomy"),
    ...
  )
}
