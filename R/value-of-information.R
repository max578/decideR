# =============================================================================
# Value of information
# =============================================================================
# What is the evidence worth? `decide_evpi()` prices perfect knowledge of the
# latent state -- the ceiling on what any study could ever return -- and
# `decide_evsi()` prices one named, finite prospective sample: this soil test,
# this trial, at this site. Both are read off the identical per-draw,
# per-candidate utility matrix the manifest tail already assembles, so the
# value of information and the decision it would inform are computed from one
# object rather than from two hand-aligned ones. Both refuse to price
# un-grounded evidence: an `[unverified]` manifest returns a typed abstention,
# never a dollar figure.

# Abstention reasons that make a value of information meaningless. NOTE the
# omission: `insufficient_evidence` is NOT blocking. A decision that is too
# close to call is exactly the situation in which information is worth buying,
# so the valuation is still priced and the indecisive decision rides along in
# `@baseline` for the reader to see.
.VOI_BLOCKING_REASONS <- c("input_ungrounded", "no_feasible_action",
                           "low_ess", "degenerate_utility")

# Build an abstained valuation from the baseline decision that produced the
# reason, so the valuation inherits the decision's grounding and provenance.
.voi_abstain <- function(type, reason, baseline, method) {
  .valuation_abstain(
    type = type, reason = reason, grounding = baseline@grounding,
    method = method, baseline = baseline, inputs = baseline@inputs,
    metadata = baseline@metadata
  )
}

# The two expectations an EVPI is the difference of, over the feasible
# candidates only: the expected utility under perfect information (choose the
# best action for each draw, then average) and under current information
# (average each action over the draws, then choose the best).
.evpi_parts <- function(util_matrix, feasible) {
  u <- util_matrix[, feasible, drop = FALSE]
  row_max <- do.call(pmax, lapply(seq_len(ncol(u)), function(j) u[, j]))
  eu <- colMeans(u)
  list(
    expected_utility_perfect_information = mean(row_max),
    expected_utility_current_information = max(eu),
    evpi = mean(row_max) - max(eu)
  )
}

# -----------------------------------------------------------------------------
# Expected value of perfect information
# -----------------------------------------------------------------------------

#' Expected value of perfect information from a manifest
#'
#' Prices what it would be worth to learn the latent state exactly before
#' acting. Given the same manifest, candidate set and utility that
#' [decide_from_manifest()] takes, `decide_evpi()` returns
#' \deqn{EVPI = E_\theta[\max_a U(a, \theta)] - \max_a E_\theta[U(a, \theta)],}
#' the difference between deciding with the state known and deciding with only
#' its posterior. It is the ceiling on the value of any study, trial or
#' measurement addressing that state: no finite sample can be worth more, which
#' is what makes it the natural first screen before an experiment is designed.
#'
#' The expectation runs over the feasible candidates only, so a hard constraint
#' passed through `...` prices the information available *within* the actions
#' the grower or the agency can actually take, not within a wider hypothetical
#' set.
#'
#' Grounding rides from the producer exactly as it does for a decision: an
#' `[unverified]` manifest returns an abstained `valuation` with
#' `abstain_reason = "input_ungrounded"` and `value = NA_real_`. The other
#' blocking reasons are `no_feasible_action`, `low_ess` and
#' `degenerate_utility`. An `insufficient_evidence` baseline decision is *not*
#' blocking: a too-close-to-call decision is precisely where information pays,
#' and the indecisive decision is returned in `@baseline`.
#'
#' @param manifest An `orchestra_manifest` S7 object (or any S7 object exposing
#'   the contract's `outputs` / `metadata` / `summary` properties).
#' @param candidates A numeric vector (or list) of candidate actions.
#' @param utility A function `function(action, draws_column)` returning a
#'   numeric utility per draw, or `NULL` when each manifest column is already
#'   the utility of the corresponding candidate.
#' @param grounding Optional override for the manifest's own grounding token.
#' @param safe_action The action the baseline decision abstains to; defaults to
#'   the first candidate.
#' @param draws_key The `metadata` key under which a draws matrix is sought
#'   when the `outputs` slot is empty.
#' @param ... Further arguments passed to the decision core (e.g. `constraint`,
#'   `min_ess`, `ess`, `decisive_prob`).
#' @return A [valuation] of `type = "evpi"`. Its `components` carry the two
#'   expectations the value is the difference of, the draw count and the number
#'   of feasible candidates; `@baseline` carries the decision current evidence
#'   supports.
#' @references
#' Raiffa, H. and Schlaifer, R. (1961) *Applied Statistical Decision Theory*.
#' Boston: Harvard University Graduate School of Business Administration.
#' @examples
#' set.seed(1L)
#' rates <- seq(0, 200, by = 25)
#' demo_manifest <- S7::new_class(
#'   "demo_manifest",
#'   properties = list(
#'     outputs         = S7::new_property(S7::class_any, default = NULL),
#'     metadata        = S7::new_property(S7::class_list, default = list()),
#'     summary         = S7::new_property(S7::class_any, default = NULL),
#'     run_id          = S7::new_property(S7::class_character, default = ""),
#'     emitter_package = S7::new_property(S7::class_character, default = "")
#'   )
#' )
#' ymax <- rnorm(800L, 5.5, 0.6)
#' yld  <- vapply(rates,
#'                function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)),
#'                numeric(800L))
#' m <- demo_manifest(
#'   metadata = list(yield_draws = yld, grounding = grounding_grounded())
#' )
#' decide_evpi(m, candidates = rates,
#'             utility = function(r, y) 300 * y - 1.2 * r)
#' @seealso [decide_evsi()] for the value of one finite sample;
#'   [decide_from_manifest()] for the decision the value is measured against.
#' @family value
#' @export
decide_evpi <- function(manifest, candidates, utility = NULL, grounding = NULL,
                        safe_action = NULL, draws_key = "yield_draws", ...) {
  mf <- .manifest_decision(
    manifest = manifest, candidates = candidates, utility = utility,
    grounding = grounding, safe_action = safe_action, draws_key = draws_key,
    dots = list(...)
  )
  d <- mf$decision
  if (isTRUE(d@abstain_reason %in% .VOI_BLOCKING_REASONS)) {
    return(.voi_abstain("evpi", d@abstain_reason, d, "evpi_expected_utility"))
  }
  feasible <- d@candidates$feasible
  u <- mf$util_matrix[, feasible, drop = FALSE]
  if (anyNA(u)) {
    return(.voi_abstain("evpi", "degenerate_utility", d,
                        "evpi_expected_utility"))
  }
  parts <- .evpi_parts(mf$util_matrix, feasible)
  valuation(
    value      = parts$evpi,
    type       = "evpi",
    components = c(parts, list(n_draws = nrow(u),
                               n_feasible_candidates = ncol(u))),
    grounding  = d@grounding,
    baseline   = d,
    method     = "evpi_expected_utility",
    inputs     = d@inputs,
    metadata   = d@metadata
  )
}

# -----------------------------------------------------------------------------
# Expected value of sample information
# -----------------------------------------------------------------------------

# A prospective sample is described by a closure pair: `simulate(state)` draws
# one hypothetical dataset from the sampling model at a given latent state, and
# `loglik(y, state)` returns the log-likelihood of that dataset at every state
# draw. Everything else in the design (`label`, `n_obs`, `cost`) is metadata
# the valuation reports but does not compute with -- except `cost`, which is
# subtracted once to give the net value.
.check_sample_design <- function(design) {
  if (!is.list(design)) {
    stop("`sample_design` must be a list describing the prospective sample",
         call. = FALSE)
  }
  missing_fn <- setdiff(c("simulate", "loglik"), names(design))
  if (length(missing_fn) > 0L) {
    stop(
      sprintf(
        paste0("`sample_design` must supply %s -- the sampling model the ",
               "sample would be drawn from"),
        paste(sQuote(missing_fn), collapse = " and ")
      ),
      call. = FALSE
    )
  }
  if (!is.function(design$simulate) || !is.function(design$loglik)) {
    stop("`sample_design$simulate` and `$loglik` must both be functions",
         call. = FALSE)
  }
  if (!is.null(design$cost) &&
        (!is.numeric(design$cost) || length(design$cost) != 1L)) {
    stop("`sample_design$cost`, when supplied, must be a single number",
         call. = FALSE)
  }
  invisible(TRUE)
}

# Resolve the latent state the prospective sample informs, one value per draw:
# an explicit vector, a named column of the manifest's `params` data.frame (the
# contract's `inferential_target = "parameters"` payload), or the single
# posterior column of a `predictions` manifest. Never guessed from a
# multi-column outcome grid -- which column is the state is a modelling
# statement the caller owns.
.evsi_state <- function(manifest, draws, state, state_key) {
  n <- nrow(draws)
  if (!is.null(state)) {
    if (!is.numeric(state) || length(state) != n) {
      stop(sprintf(
        "`state` must be a numeric vector of length %d (one per draw)", n
      ), call. = FALSE)
    }
    return(as.numeric(state))
  }
  if (!is.null(state_key)) {
    params <- .manifest_prop(manifest, "params")
    if (is.null(params) || !state_key %in% names(params)) {
      stop(sprintf("manifest carries no `params` column %s", sQuote(state_key)),
           call. = FALSE)
    }
    st <- params[[state_key]]
    if (length(st) != n) {
      stop(sprintf("`params$%s` has %d values but the draws have %d rows",
                   state_key, length(st), n), call. = FALSE)
    }
    return(as.numeric(st))
  }
  if (ncol(draws) == 1L) {
    return(as.numeric(draws[, 1L]))
  }
  stop(
    paste0("cannot infer the latent state the sample informs from a ",
           "multi-column draws matrix -- supply `state` or `state_key`"),
    call. = FALSE
  )
}

#' Expected value of one prospective sample from a manifest
#'
#' Prices a named, finite study before it is run: this soil test, this trial,
#' at this site. Where [decide_evpi()] prices perfect knowledge,
#' `decide_evsi()` prices the imperfect knowledge a real sample would deliver,
#' \deqn{EVSI = E_y[\max_a E_{\theta \mid y}[U(a, \theta)]] -
#'              \max_a E_\theta[U(a, \theta)],}
#' the expected gain from being allowed to decide after seeing the data rather
#' than before. It is bounded above by the EVPI, which the valuation reports
#' beside it as a ceiling.
#'
#' The pre-posterior expectation is evaluated by the standard two-loop Monte
#' Carlo algorithm: draw a latent state from the current posterior, simulate the
#' dataset the sample would produce at that state, update, and re-decide. The
#' inner update here is an importance re-weighting of the manifest's own draws
#' by the sampling log-likelihood rather than a nested re-fit, so the manifest
#' stays the single source of the posterior and decideR adds no sampler. That
#' re-weighting degenerates when the prospective sample is very much more
#' informative than the current posterior; the effective sample size of the
#' weights is therefore computed at every outer draw, reported in
#' `components$weight_ess_min`, and warned about when it collapses.
#'
#' The estimate is a Monte Carlo one and is reported unclamped. A small
#' negative value is Monte Carlo noise around a true value near zero -- a
#' sample worth nothing -- and is not silently floored at zero.
#'
#' @param manifest An `orchestra_manifest` S7 object, as for [decide_evpi()].
#' @param candidates A numeric vector (or list) of candidate actions.
#' @param sample_design A named list describing the prospective sample:
#'   `simulate` (a `function(state)` returning one hypothetical dataset drawn at
#'   that latent state), `loglik` (a `function(y, state)` returning the
#'   log-likelihood of that dataset at every state draw, one value per draw),
#'   and optionally `label`, `n_obs` and `cost`.
#' @param utility A function `function(action, draws_column)`, or `NULL` when
#'   each manifest column is already the utility of its candidate.
#' @param state Optional numeric vector, one latent-state value per draw, that
#'   the prospective sample informs.
#' @param state_key Optional name of a column of the manifest's `params`
#'   data.frame to read the state from.
#' @param n_pre The number of outer (pre-posterior) draws.
#' @param grounding Optional override for the manifest's own grounding token.
#' @param safe_action The action the baseline decision abstains to.
#' @param draws_key The `metadata` key under which a draws matrix is sought
#'   when the `outputs` slot is empty.
#' @param ... Further arguments passed to the decision core (e.g. `constraint`,
#'   `decisive_prob`).
#' @return A [valuation] of `type = "evsi"`, whose `components` carry the
#'   pre-posterior and current-information expectations, the EVPI ceiling, the
#'   weight diagnostics, and -- when `sample_design$cost` is supplied -- the
#'   cost and the net value.
#' @references
#' Raiffa, H. and Schlaifer, R. (1961) *Applied Statistical Decision Theory*.
#' Boston: Harvard University Graduate School of Business Administration.
#'
#' Ades, A. E., Lu, G. and Claxton, K. (2004) Expected value of sample
#' information calculations in medical decision modeling. *Medical Decision
#' Making*, 24(2), 207--227. \doi{10.1177/0272989X04263162}
#' @examples
#' set.seed(2L)
#' demo_manifest <- S7::new_class(
#'   "demo_manifest",
#'   properties = list(
#'     outputs         = S7::new_property(S7::class_any, default = NULL),
#'     metadata        = S7::new_property(S7::class_list, default = list()),
#'     summary         = S7::new_property(S7::class_any, default = NULL),
#'     run_id          = S7::new_property(S7::class_character, default = ""),
#'     emitter_package = S7::new_property(S7::class_character, default = "")
#'   )
#' )
#' # A posterior for the yield gain from a nitrogen top-up, in t/ha.
#' gain <- rnorm(600L, mean = 0.10, sd = 0.35)
#' m <- demo_manifest(
#'   outputs  = matrix(gain, ncol = 1L),
#'   metadata = list(grounding = grounding_grounded())
#' )
#' # A four-plot strip trial measuring the gain, observation sd 0.5.
#' trial <- list(
#'   label    = "4-plot strip trial",
#'   n_obs    = 4L,
#'   cost     = 0.02,
#'   simulate = function(state) mean(rnorm(4L, state, 0.5)),
#'   loglik   = function(y, state) dnorm(y, state, 0.5 / sqrt(4), log = TRUE)
#' )
#' decide_evsi(m, candidates = c(0, 1), sample_design = trial,
#'             utility = function(a, g) a * g, n_pre = 200L)
#' @seealso [decide_evpi()] for the ceiling on any sample's value.
#' @family value
#' @export
decide_evsi <- function(manifest, candidates, sample_design, utility = NULL,
                        state = NULL, state_key = NULL, n_pre = 500L,
                        grounding = NULL, safe_action = NULL,
                        draws_key = "yield_draws", ...) {
  .check_sample_design(sample_design)
  if (!is.numeric(n_pre) || length(n_pre) != 1L || n_pre < 1L) {
    stop("`n_pre` must be a single positive number of outer draws",
         call. = FALSE)
  }
  n_pre <- as.integer(n_pre)
  method <- "evsi_preposterior_importance_weights"

  mf <- .manifest_decision(
    manifest = manifest, candidates = candidates, utility = utility,
    grounding = grounding, safe_action = safe_action, draws_key = draws_key,
    dots = list(...)
  )
  d <- mf$decision
  if (isTRUE(d@abstain_reason %in% .VOI_BLOCKING_REASONS)) {
    return(.voi_abstain("evsi", d@abstain_reason, d, method))
  }
  feasible <- d@candidates$feasible
  u <- mf$util_matrix[, feasible, drop = FALSE]
  if (anyNA(u)) {
    return(.voi_abstain("evsi", "degenerate_utility", d, method))
  }
  st <- .evsi_state(manifest, mf$draws, state, state_key)

  n_draw <- nrow(u)
  idx <- sample.int(n_draw, size = n_pre, replace = n_pre > n_draw)
  best_post <- numeric(n_pre)
  ess_w     <- numeric(n_pre)
  for (k in seq_len(n_pre)) {
    y  <- sample_design$simulate(st[idx[k]])
    ll <- sample_design$loglik(y, st)
    if (length(ll) != n_draw || anyNA(ll)) {
      stop(
        sprintf(
          paste0("`sample_design$loglik` must return %d non-NA ",
                 "log-likelihoods, one per draw"),
          n_draw
        ),
        call. = FALSE
      )
    }
    w <- exp(ll - max(ll))
    sw <- sum(w)
    if (!is.finite(sw) || sw <= 0) {
      stop(paste0("`sample_design$loglik` produced weights that do not ",
                  "normalise -- check the sampling model"),
           call. = FALSE)
    }
    w <- w / sw
    ess_w[k] <- 1 / sum(w^2)
    best_post[k] <- max(as.numeric(crossprod(w, u)))
  } # ends k, over pre-posterior draws

  eu_current <- max(colMeans(u))
  evsi <- mean(best_post) - eu_current
  # The mean weight ESS, not the minimum: one unlucky outer draw resting on a
  # handful of theta draws does not compromise an average over thousands, but a
  # mean ESS in the low tens means the posterior is being represented by almost
  # none of the draws at almost every outer step, and the estimate is then not
  # worth reporting silently. Observed separation on the linear-Gaussian case
  # is stark -- thousands when the sample is comparable to the posterior,
  # single digits when it is orders of magnitude sharper.
  if (mean(ess_w) < 50) {
    warning(
      sprintf(
        paste0("pre-posterior importance weights degenerated (mean effective ",
               "sample size %.1f of %d draws): the EVSI is under-resolved -- ",
               "widen the posterior, shrink the sample, or raise the draw ",
               "count"),
        mean(ess_w), n_draw
      ),
      call. = FALSE
    )
  }

  parts <- .evpi_parts(mf$util_matrix, feasible)
  comp <- list(
    expected_utility_preposterior        = mean(best_post),
    expected_utility_current_information = eu_current,
    evsi                                 = evsi,
    evpi_ceiling                         = parts$evpi,
    n_pre                                = n_pre,
    n_draws                              = n_draw,
    weight_ess_min                       = min(ess_w),
    weight_ess_mean                      = mean(ess_w),
    mc_se                                = stats::sd(best_post) / sqrt(n_pre)
  )
  if (!is.null(sample_design$n_obs)) {
    comp$n_obs <- sample_design$n_obs
  }
  if (!is.null(sample_design$cost)) {
    comp$cost <- as.numeric(sample_design$cost)
    comp$net_value <- evsi - as.numeric(sample_design$cost)
  }
  valuation(
    value      = evsi,
    type       = "evsi",
    components = comp,
    grounding  = d@grounding,
    baseline   = d,
    method     = method,
    inputs     = d@inputs,
    metadata   = c(d@metadata,
                   list(sample_label = sample_design$label %||% NA_character_))
  )
}
