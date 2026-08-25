# =============================================================================
# The valuation object
# =============================================================================
# `valuation` is the result type of decideR's value verbs: how much a piece of
# evidence is worth (`decide_evpi()`, `decide_evsi()`) and whether a stream of
# benefits repays a stream of costs (`decide_bcr()`). It is deliberately NOT a
# `decision` -- nothing is chosen here, a quantity is priced -- but it carries
# the same two honesty fields, so an un-grounded input prices out as a typed
# abstention rather than as a number a reader would spend money on.

#' A priced quantity with grounding and abstention
#'
#' The object returned by [decide_evpi()], [decide_evsi()] and [decide_bcr()].
#' It records the priced `value`, the `type` of valuation that produced it, the
#' arithmetic `components` a reader needs in order to audit that value, and the
#' two Independent Oracle Principle honesty fields: `grounding`, and the
#' abstention record (`abstained`, `abstain_reason`). When a valuation abstains,
#' `value` is `NA_real_` -- decideR never mints a dollar figure on evidence its
#' producer did not ground.
#'
#' The `abstain_reason` vocabulary extends the `decision` vocabulary with the
#' reasons specific to pricing: `input_ungrounded`, `no_feasible_action`,
#' `low_ess`, `degenerate_utility` (all inherited from the decision that the
#' valuation is built on) and `undefined_ratio` (a benefit-cost ratio whose
#' discounted cost base is not strictly positive).
#'
#' @param value The priced quantity, in the utility units of the inputs
#'   (currency per unit area for a crop valuation, a dimensionless ratio for a
#'   benefit-cost ratio), or `NA_real_` when abstained.
#' @param type A short valuation type: `"evpi"`, `"evsi"` or `"bcr"`.
#' @param components A named list of the parts the `value` is assembled from,
#'   so the number can be audited rather than trusted.
#' @param grounding A canonical grounding token.
#' @param abstained `TRUE` when the valuation declined to price the quantity.
#' @param abstain_reason A short reason string, or `NA_character_`.
#' @param baseline The `decision` the current evidence supports, for a value of
#'   information; `NULL` otherwise.
#' @param method A label recording the valuation rule.
#' @param inputs A named list recording input provenance.
#' @param metadata A named list of free-form metadata.
#' @return A `valuation` S7 object.
#' @examples
#' v <- valuation(value = 12.4, type = "evpi",
#'                grounding = grounding_grounded())
#' v@value
#' @seealso [decide_evpi()], [decide_evsi()], [decide_bcr()].
#' @family value
#' @export
valuation <- S7::new_class(
  "valuation",
  properties = list(
    value          = S7::new_property(S7::class_numeric, default = NA_real_),
    type           = S7::new_property(S7::class_character,
                                      default = NA_character_),
    components     = S7::new_property(S7::class_list, default = list()),
    # Literal rather than grounding_unverified() so the class definition does
    # not depend on grounding.R's load order; the validator enforces the token.
    grounding      = S7::new_property(S7::class_character,
                                      default = "[unverified]"),
    abstained      = S7::new_property(S7::class_logical, default = FALSE),
    abstain_reason = S7::new_property(S7::class_character,
                                      default = NA_character_),
    baseline       = S7::new_property(S7::class_any, default = NULL),
    method         = S7::new_property(S7::class_character,
                                      default = NA_character_),
    inputs         = S7::new_property(S7::class_list, default = list()),
    metadata       = S7::new_property(S7::class_list, default = list())
  ),
  validator = function(self) {
    if (length(self@grounding) != 1L ||
          !self@grounding %in% c(grounding_grounded(),
                                 grounding_unverified())) {
      return("@grounding must be exactly one canonical grounding token")
    }
    if (length(self@abstained) != 1L || is.na(self@abstained)) {
      return("@abstained must be a single non-NA logical")
    }
    if (isTRUE(self@abstained) && is.na(self@abstain_reason)) {
      return("an abstained valuation must carry a non-NA @abstain_reason")
    }
    if (isTRUE(self@abstained) && !is.na(self@value)) {
      return("an abstained valuation must not carry a @value")
    }
    NULL
  }
)

# -----------------------------------------------------------------------------
# Typed abstention
# -----------------------------------------------------------------------------

# Mint an abstained valuation. Every value verb routes its refusals through
# here so an un-priced quantity is always the same shape: `NA_real_` beside a
# typed reason, class-stamped `decideR_abstention` so the federation's
# `is_orchestra_decline()` predicate recognises it by naming convention.
.valuation_abstain <- function(type, reason, grounding, method,
                               baseline = NULL, inputs = list(),
                               metadata = list()) {
  v <- valuation(
    value          = NA_real_,
    type           = type,
    components     = list(),
    grounding      = grounding,
    abstained      = TRUE,
    abstain_reason = reason,
    baseline       = baseline,
    method         = method,
    inputs         = inputs,
    metadata       = metadata
  )
  .stamp_abstention_class(v)
}

# -----------------------------------------------------------------------------
# Printing
# -----------------------------------------------------------------------------

#' Print a valuation
#'
#' @param x A [valuation].
#' @param ... Ignored, for compatibility with [print()].
#' @return `x`, invisibly.
#' @examples
#' print(valuation(value = 12.4, type = "evpi",
#'                 grounding = grounding_grounded()))
#' @export
S7::method(print, valuation) <- function(x, ...) {
  status <- if (isTRUE(x@abstained)) {
    sprintf("ABSTAINED (%s)", x@abstain_reason)
  } else {
    "priced"
  }
  cat(sprintf("<valuation: %s> %s  [%s]\n", x@type, status, x@grounding))
  if (!is.na(x@value)) {
    cat(sprintf("  value : %s\n", format(x@value, digits = 5L)))
  }
  nm <- names(x@components)
  scalar <- vapply(x@components,
                   function(z) is.numeric(z) && length(z) == 1L,
                   logical(1L))
  if (any(scalar)) {
    for (k in nm[scalar]) {
      cat(sprintf("  %-14s %s\n", paste0(k, ":"),
                  format(x@components[[k]], digits = 5L)))
    }
  }
  if (!is.na(x@method)) {
    cat(sprintf("  method: %s\n", x@method))
  }
  invisible(x)
}
