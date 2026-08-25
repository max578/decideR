# =============================================================================
# Provenance vocabulary (Independent Oracle Principle)
# =============================================================================
# Canonical grounding tokens and their worst-case combination. The single
# source of truth for these strings is ORCHESTRA's
# `integration/provenance_vocabulary.md`; a separate package such as decideR
# MUST hardcode the identical tokens (never a synonym) so the federation does
# not drift on the grounding label. A fact is `grounded` only once it has been
# diffed against the external authority that owns it; self-consistency,
# golden fixtures, and inter-member agreement do not ground anything. Every
# other state is `[unverified]` and is treated as un-grounded by every
# decision built here.

#' Canonical grounding tokens
#'
#' The two states a fact -- or a decision assembled from facts -- can occupy
#' under the Independent Oracle Principle. `grounding_grounded()` returns the
#' token for a fact that has been checked against its external authority;
#' `grounding_unverified()` returns the token for everything else, which is the
#' default until a grounding check proves otherwise.
#'
#' The square brackets in `"[unverified]"` are deliberate and load-bearing:
#' they make an un-grounded label visually unmissable when it surfaces in a
#' printed decision, a verdict string, or a report.
#'
#' @return A length-one character string holding the canonical token.
#' @examples
#' grounding_grounded()
#' grounding_unverified()
#' @seealso [combine_grounding()] for worst-case combination across inputs.
#' @family grounding
#' @name grounding_tokens
NULL

#' @rdname grounding_tokens
#' @export
grounding_grounded <- function() "grounded"

#' @rdname grounding_tokens
#' @export
grounding_unverified <- function() "[unverified]"

# -----------------------------------------------------------------------------
# Worst-case combination
# -----------------------------------------------------------------------------

#' Combine input grounding worst-case
#'
#' A decision that rests on several inputs is grounded only when *every* input
#' is grounded; a single un-grounded input taints the whole decision. This is
#' the worst-case combination mandated by the Independent Oracle Principle, and
#' it is the rule by which a decision inherits its grounding label from the
#' facts it consumes.
#'
#' Each token is validated against the canonical vocabulary, so a synonym such
#' as `"unverified"` or `"ungrounded"` is rejected loudly rather than silently
#' mistaken for a grounded fact.
#'
#' @param tokens A character vector of grounding tokens, each either
#'   `grounding_grounded()` or `grounding_unverified()`.
#' @return `grounding_grounded()` if `tokens` is non-empty and every element is
#'   grounded; otherwise `grounding_unverified()`.
#' @examples
#' combine_grounding(c(grounding_grounded(), grounding_grounded()))
#' combine_grounding(c(grounding_grounded(), grounding_unverified()))
#' @seealso [grounding_tokens] for the two canonical tokens.
#' @family grounding
#' @export
combine_grounding <- function(tokens) {
  tokens <- as.character(tokens)
  ok <- tokens %in% c(grounding_grounded(), grounding_unverified())
  if (!all(ok)) {
    bad <- unique(tokens[!ok])
    stop(
      sprintf(
        "non-canonical grounding token(s): %s -- use grounding_grounded() or grounding_unverified() exactly",
        paste(sQuote(bad), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (length(tokens) == 0L) {
    return(grounding_unverified())
  }
  if (all(tokens == grounding_grounded())) {
    grounding_grounded()
  } else {
    grounding_unverified()
  }
}

# Internal predicate -- a single token is grounded.
.is_grounded <- function(token) {
  identical(as.character(token), grounding_grounded())
}
