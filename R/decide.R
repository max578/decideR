# =============================================================================
# The decision engine
# =============================================================================
# `decide()` is the shared keystone every reference decision reduces to: given
# posterior draws of a latent state, a utility function over (action, state),
# and a candidate action set, it chooses the feasible action of greatest
# expected utility -- but only when the evidence is grounded and decisive.
# Otherwise it abstains to a caller-supplied safe action and says why. Four
# abstention triggers, in priority order: ungrounded input (the Independent
# Oracle Principle firewall), no feasible action, too few effective draws, and
# a too-close-to-call margin.

# -----------------------------------------------------------------------------
# Internal core
# -----------------------------------------------------------------------------

# Locate the safe action in the candidate set (numeric grids only), so the
# decisiveness check can compare the chosen action against the status quo.
# Returns NA when there is no numeric match.
.match_candidate <- function(candidates, action) {
  if (is.null(action) || is.list(candidates) || !is.numeric(candidates) ||
        !is.numeric(action) || length(action) != 1L) {
    return(NA_integer_)
  }
  hit <- which(abs(as.numeric(candidates) - action) < 1e-9)
  if (length(hit) == 0L) NA_integer_ else hit[1L]
}

# Internal core: choose among `candidates` given a per-draw, per-candidate
# utility matrix. Kept separate from `decide()` so a reference decision that
# already holds an outcome matrix (e.g. yield draws per rate) can assemble the
# utility itself and reuse the identical abstention logic.
.decide_core <- function(util_matrix, candidates, labels, constraint,
                         grounding, safe_action, safe_label, min_ess, ess,
                         decisive_prob, method, inputs, metadata) {
  n_cand <- ncol(util_matrix)
  feasible <- if (is.null(constraint)) {
    rep(TRUE, n_cand)
  } else {
    vapply(seq_len(n_cand),
           function(j) isTRUE(constraint(candidates[[j]])),
           logical(1L))
  }

  eu <- colMeans(util_matrix)
  eu[!feasible] <- NA_real_
  ledger <- data.frame(
    action           = if (is.list(candidates)) seq_len(n_cand) else candidates,
    expected_utility = eu,
    feasible         = feasible,
    stringsAsFactors = FALSE
  )

  ess_eff <- if (is.null(ess)) nrow(util_matrix) else ess
  reason <- NA_character_
  if (!.is_grounded(grounding)) {
    reason <- "input_ungrounded"
  } else if (!any(feasible)) {
    reason <- "no_feasible_action"
  } else if (!is.null(min_ess) && ess_eff < min_ess) {
    reason <- "low_ess"
  }

  # Decisiveness is judged against the status quo: the posterior probability
  # that the chosen action beats the safe action. This answers the question a
  # decision actually faces -- "is moving off the status quo justified?" -- and
  # is robust to a fine candidate grid, where two near-optimal neighbours would
  # split a per-draw argmax and trigger spurious indecision. When the chosen
  # action *is* the safe action (no move), or the safe action is not a numeric
  # candidate, the check is a no-op.
  best_idx <- if (any(feasible)) which.max(eu) else NA_integer_
  if (is.na(reason) && any(feasible)) {
    safe_idx <- .match_candidate(candidates, safe_action)
    decisive <- if (is.na(safe_idx) || identical(safe_idx, best_idx)) {
      1
    } else {
      mean(util_matrix[, best_idx] > util_matrix[, safe_idx])
    }
    if (decisive < decisive_prob) {
      reason <- "insufficient_evidence"
    }
  }

  abstained <- !is.na(reason)
  if (abstained) {
    action <- safe_action
    label  <- safe_label
    eu_sel <- NA_real_
  } else {
    action <- candidates[[best_idx]]
    label  <- labels[[best_idx]]
    eu_sel <- eu[best_idx]
  }
  if (!.is_grounded(grounding)) {
    label <- paste0(label, " ", grounding_unverified())
  }

  decision(
    action           = action,
    action_label     = label,
    expected_utility = eu_sel,
    candidates       = ledger,
    grounding        = grounding,
    abstained        = abstained,
    abstain_reason   = reason,
    safe_action      = safe_action,
    method           = method,
    inputs           = inputs,
    metadata         = metadata
  )
}

# -----------------------------------------------------------------------------
# Exported decision rule
# -----------------------------------------------------------------------------

#' Choose an action by expected utility, with grounding and abstention
#'
#' The shared decision rule. Given `draws` from the posterior of a latent state
#' \eqn{\theta}, a `utility` function \eqn{U(a, \theta)}, and a set of candidate
#' actions, `decide()` evaluates the expected utility
#' \eqn{E_\theta[U(a, \theta)]} of each feasible candidate by averaging over the
#' draws and selects the maximiser. It declines to do so -- abstaining to
#' `safe_action` -- under any of four conditions, checked in this order: the
#' combined input `grounding` is not grounded (the Independent Oracle Principle
#' firewall: never act on an unverified fact); no candidate satisfies
#' `constraint`; the effective sample size is below `min_ess`; or the chosen
#' action beats the `safe_action` on fewer than `decisive_prob` of the draws
#' (it is not clearly better than the status quo). The last check is judged
#' against the safe action, not the runner-up, so a fine candidate grid does
#' not trigger spurious indecision.
#'
#' The grounding label is combined worst-case across `grounding` with
#' [combine_grounding()], so passing the provenance of several inputs taints the
#' decision if any one of them is unverified.
#'
#' @param draws A numeric vector of posterior draws of the latent state.
#' @param utility A function `function(action, theta)` returning a numeric
#'   vector of utilities the same length as `theta`.
#' @param candidates A numeric vector (or list) of candidate actions.
#' @param labels Optional character labels for the candidates; defaults to a
#'   formatted `candidates`.
#' @param constraint Optional `function(action)` returning `TRUE` when the
#'   action is feasible.
#' @param grounding One or more grounding tokens for the inputs; combined
#'   worst-case.
#' @param safe_action The action returned on abstention (e.g. a flat position,
#'   a zero input rate, the status quo).
#' @param safe_label A label for the safe action.
#' @param min_ess Optional effective-sample-size floor.
#' @param ess Optional effective sample size of `draws`; defaults to
#'   `length(draws)`.
#' @param decisive_prob The minimum posterior probability that the chosen action
#'   beats `safe_action`, below which the decision abstains as not clearly
#'   better than the status quo.
#' @param method A label recording the decision rule.
#' @param inputs A named list recording input provenance.
#' @param metadata A named list of free-form metadata.
#' @return A [decision] object.
#' @examples
#' set.seed(1L)
#' theta <- rnorm(2000L, mean = 1.2, sd = 0.4)
#' u <- function(a, theta) -(a - theta)^2
#' decide(theta, u, candidates = seq(0, 3, by = 0.5),
#'        grounding = grounding_grounded(), safe_action = 0)
#' @seealso [decide_input_rate()] and [decide_position_size()] for domain
#'   wrappers; [decision] for the returned object.
#' @family decisions
#' @export
decide <- function(draws, utility, candidates, labels = NULL,
                   constraint = NULL, grounding = grounding_unverified(),
                   safe_action = NULL, safe_label = "abstain",
                   min_ess = NULL, ess = NULL, decisive_prob = 0.6,
                   method = "expected_utility", inputs = list(),
                   metadata = list()) {
  if (!is.numeric(draws) || length(draws) == 0L) {
    stop("`draws` must be a non-empty numeric vector", call. = FALSE)
  }
  if (!is.function(utility)) {
    stop("`utility` must be a function of (action, theta)", call. = FALSE)
  }
  n_cand <- length(candidates)
  if (n_cand == 0L) {
    stop("`candidates` must hold at least one action", call. = FALSE)
  }
  if (is.null(labels)) {
    labels <- as.character(if (is.list(candidates)) {
      seq_len(n_cand)
    } else {
      candidates
    })
  }
  grounding <- combine_grounding(grounding)

  util_matrix <- vapply(
    seq_len(n_cand),
    function(j) {
      u <- utility(candidates[[j]], draws)
      if (length(u) != length(draws)) {
        stop("`utility` must return one value per draw", call. = FALSE)
      }
      as.numeric(u)
    },
    numeric(length(draws))
  )

  .decide_core(
    util_matrix = util_matrix, candidates = candidates, labels = labels,
    constraint = constraint, grounding = grounding, safe_action = safe_action,
    safe_label = safe_label, min_ess = min_ess, ess = ess,
    decisive_prob = decisive_prob, method = method, inputs = inputs,
    metadata = metadata
  )
}
