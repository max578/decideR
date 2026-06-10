# =============================================================================
# The decision object
# =============================================================================
# `decision` is decideR's native result type: the chosen action, the expected
# utility that justified it, the full candidate ledger, and -- carried beside
# the numbers, never inferred from them -- the grounding label and the honest
# abstention record. It is an S7 object so that the ORCHESTRA composition layer
# can adapt it to an `orchestra_manifest` without decideR depending on the
# contract package.

#' A decision-theoretic action with grounding and abstention
#'
#' The object returned by [decide()] and the reference decisions. It records
#' the chosen `action`, the `expected_utility` that selected it, the complete
#' `candidates` ledger (every action with its expected utility and
#' feasibility), and the two honesty fields the Independent Oracle Principle
#' requires: `grounding` (`grounding_grounded()` or `grounding_unverified()`)
#' and the abstention record (`abstained`, `abstain_reason`). When a decision
#' abstains the `action` is the caller's `safe_action`, not the utility-maximal
#' one.
#'
#' @param action The chosen action. The `safe_action` when `abstained` is
#'   `TRUE`.
#' @param action_label A short human-readable label for the action; suffixed
#'   `"[unverified]"` when the grounding is not grounded.
#' @param expected_utility The expected (mean-over-draws) utility of the chosen
#'   action, or `NA_real_` when abstained.
#' @param candidates A `data.frame` with one row per candidate action:
#'   `action`, `expected_utility`, `feasible`.
#' @param grounding A canonical grounding token.
#' @param abstained `TRUE` when the decision declined the utility-maximal
#'   action.
#' @param abstain_reason A short reason string, or `NA_character_`.
#' @param safe_action The fallback action taken on abstention.
#' @param method The decision rule applied (e.g. `"expected_profit"`).
#' @param inputs A named list recording input provenance.
#' @param metadata A named list of free-form metadata.
#' @return A `decision` S7 object.
#' @examples
#' d <- decision(action = 120, action_label = "rate=120 kg/ha",
#'               expected_utility = 1840, grounding = grounding_grounded())
#' d@action
#' @seealso [decide()] and the reference decisions that produce this object.
#' @family decisions
#' @export
decision <- S7::new_class(
  "decision",
  properties = list(
    action           = S7::new_property(S7::class_any, default = NULL),
    action_label     = S7::new_property(S7::class_character,
                                        default = NA_character_),
    expected_utility = S7::new_property(S7::class_numeric,
                                        default = NA_real_),
    candidates       = S7::new_property(S7::class_any, default = NULL),
    # Literal rather than grounding_unverified() so the class definition does
    # not depend on grounding.R's load order; the validator enforces the token.
    grounding        = S7::new_property(
      S7::class_character,
      default = "[unverified]"
    ),
    abstained        = S7::new_property(S7::class_logical, default = FALSE),
    abstain_reason   = S7::new_property(S7::class_character,
                                        default = NA_character_),
    safe_action      = S7::new_property(S7::class_any, default = NULL),
    method           = S7::new_property(S7::class_character,
                                        default = NA_character_),
    inputs           = S7::new_property(S7::class_list, default = list()),
    metadata         = S7::new_property(S7::class_list, default = list())
  ),
  validator = function(self) {
    if (length(self@grounding) != 1L ||
          !self@grounding %in% c(grounding_grounded(), grounding_unverified())) {
      return("@grounding must be exactly one canonical grounding token")
    }
    if (length(self@abstained) != 1L || is.na(self@abstained)) {
      return("@abstained must be a single non-NA logical")
    }
    if (isTRUE(self@abstained) && is.na(self@abstain_reason)) {
      return("an abstained decision must carry a non-NA @abstain_reason")
    }
    NULL
  }
)

#' Is a decision grounded?
#'
#' A convenience predicate reading the decision's grounding label. A consumer
#' that must refuse to act on un-grounded evidence -- for example a live
#' trading order path -- gates on this.
#'
#' @param x A `decision`.
#' @return `TRUE` when the decision's grounding is `grounding_grounded()`.
#' @examples
#' is_grounded(decision(grounding = grounding_grounded()))
#' is_grounded(decision(grounding = grounding_unverified()))
#' @family decisions
#' @export
is_grounded <- function(x) {
  if (!S7::S7_inherits(x, decision)) {
    stop("`x` must be a decision object", call. = FALSE)
  }
  .is_grounded(x@grounding)
}

# -----------------------------------------------------------------------------
# Printing
# -----------------------------------------------------------------------------

#' Print a decision
#'
#' @param x A [decision].
#' @param ... Ignored, for compatibility with [print()].
#' @return `x`, invisibly.
#' @examples
#' print(decision(action_label = "flat", grounding = grounding_grounded()))
#' @export
S7::method(print, decision) <- function(x, ...) {
  status <- if (isTRUE(x@abstained)) {
    sprintf("ABSTAINED (%s)", x@abstain_reason)
  } else {
    "decided"
  }
  cat(sprintf("<decision> %s  [%s]\n", status, x@grounding))
  cat(sprintf("  action : %s\n", x@action_label))
  if (!is.na(x@expected_utility)) {
    cat(sprintf("  E[utility]: %s\n", format(x@expected_utility, digits = 4L)))
  }
  if (!is.null(x@candidates)) {
    n <- nrow(x@candidates)
    cat(sprintf("  candidates: %d evaluated (method: %s)\n", n, x@method))
  }
  invisible(x)
}
