# =============================================================================
# Internal helpers
# =============================================================================
# Small, un-exported utilities shared across decideR's sources. Kept here rather
# than scattered so the export surface stays readable (r_style invariant 8).

# Null-coalescing helper -- return the right operand when the left is NULL.
# decideR's manifest tail leans on it to apply defaults to optional arguments
# passed through `...`. Defined locally rather than imported so the package
# keeps its lean two-Import surface (S7, stats).
#
# @noRd
`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}
