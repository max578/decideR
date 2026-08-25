#' decideR: Bayesian Decision-Theoretic Actions under Loss and Hard Constraints
#'
#' Maps a posterior distribution or an 'orchestra_manifest' inference result to an optimal action under an explicit loss function and a hard feasibility constraint, returning the action together with a grounding label and an honest abstention when evidence is insufficient. The grounding label is combined worst-case across inputs, so a decision resting on an unverified external fact is downgraded to abstention rather than asserted with false confidence. A manifest-native tail closes an analytics pipeline by deciding directly from an upstream member's inference result, and a grade-band loss prices quality-threshold ('protein-band') payoffs as a first-class step value schedule. Reference decisions cover bounded input-rate selection and constraint-capped position sizing.
#'
#' @keywords internal
"_PACKAGE"

# Register S7 methods (e.g. the `print` method for `decision`) with the base
# generics they extend. Required because those generics live outside decideR.
#
# `S7::methods_register()` intercepts `print` (a base generic it also
# registers an S7 method for, via `decision`) in a way that stops R's plain S3
# dispatch from reaching `print.grade_band_value()` on an installed package --
# `getS3method("print", "grade_band_value")` fails to find it even though the
# NAMESPACE `S3method()` entry is present and the method sits in decideR's own
# S3 method table [unverified against S7's documented contract; observed
# directly: reproduced on a minimal package carrying only a plain S3 print
# method plus one unrelated `S7::method(print, <S7 class>) <-` registration].
# Re-registering the S3 method explicitly, after `methods_register()` has run,
# restores ordinary dispatch.
.onLoad <- function(libname, pkgname) {
  S7::methods_register()
  registerS3method("print", "grade_band_value", print.grade_band_value)
}
