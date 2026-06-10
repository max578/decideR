#' decideR: Bayesian Decision-Theoretic Actions under Loss and Hard Constraints
#'
#' Maps a posterior distribution or an 'orchestra_manifest' inference result to an optimal action under an explicit loss function and a hard feasibility constraint, returning the action together with a grounding label and an honest abstention when evidence is insufficient. The grounding label is combined worst-case across inputs, so a decision resting on an unverified external fact is downgraded to abstention rather than asserted with false confidence. Reference decisions cover bounded input-rate selection and constraint-capped position sizing.
#'
#' @keywords internal
"_PACKAGE"

# Register S7 methods (e.g. the `print` method for `decision`) with the base
# generics they extend. Required because those generics live outside decideR.
.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}
