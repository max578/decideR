# =============================================================================
# Grade-band (threshold-economics) loss
# =============================================================================
# Many agricultural and industrial payoffs are not smooth in the outcome they
# reward: a grain delivery is paid by quality grade, so the value jumps at a
# protein or screenings threshold rather than rising continuously. A decision
# made under such a payoff is governed by the posterior probability of clearing
# each threshold, not by the posterior mean -- a half-percent of expected
# protein is worth a great deal near a band edge and nothing in the middle of a
# band. `grade_band_value()` makes that step payoff a first-class, reusable loss
# primitive: a value schedule with breakpoints that any `decide()` call can
# consume, and the building block the future grainPlan orchestrator will reach
# for when it prices a quality-graded decision.

# Validate a (breaks, values) schedule. Breaks must be a strictly increasing
# numeric vector; values must hold one payoff per band, i.e. one more than the
# number of breaks (the bands below the first break, between each pair, and above
# the last break).
.check_grade_band <- function(breaks, values) {
  if (!is.numeric(breaks) || length(breaks) == 0L || anyNA(breaks)) {
    stop("`breaks` must be a non-empty numeric vector with no NA", call. = FALSE)
  }
  if (is.unsorted(breaks, strictly = TRUE)) {
    stop("`breaks` must be strictly increasing", call. = FALSE)
  }
  if (!is.numeric(values) || anyNA(values)) {
    stop("`values` must be a numeric vector with no NA", call. = FALSE)
  }
  if (length(values) != length(breaks) + 1L) {
    stop(
      sprintf(
        "`values` must have one more element than `breaks` (%d bands need %d values, got %d)",
        length(breaks), length(breaks) + 1L, length(values)
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' A grade-band value schedule (threshold-economics loss)
#'
#' Builds a step value schedule: a payoff that is constant within a quality band
#' and jumps at each breakpoint. This is the canonical shape of a quality-graded
#' payoff -- a grain price that steps up as protein clears 10.5%, 11.5%, and
#' 13%, say -- where the value of an outcome depends on which band it falls in,
#' not on its exact magnitude. The returned object is a vectorised function from
#' a quality outcome to its band payoff, classed so it carries the schedule for
#' inspection and prints as a readable band table.
#'
#' `breaks` are the band edges, strictly increasing. `values` are the payoffs,
#' one per band: the first applies below `breaks[1]`, the last applies at or
#' above `breaks[length(breaks)]`, and each interior element applies between a
#' consecutive pair of breaks. With `right = FALSE` (the default) each band is
#' the half-open interval `[lower, upper)`, so an outcome exactly on a break
#' clears into the higher band -- the convention a delivery standard uses when
#' it pays the better grade at the threshold.
#'
#' @param breaks A strictly increasing numeric vector of band edges (e.g. the
#'   protein thresholds `c(10.5, 11.5, 13)`).
#' @param values A numeric vector of band payoffs, of length
#'   `length(breaks) + 1`, ordered from the lowest band to the highest.
#' @param right Logical; when `FALSE` (default) bands are `[lower, upper)` so an
#'   outcome on a break clears into the higher band; when `TRUE` bands are
#'   `(lower, upper]`.
#' @param labels Optional character labels for the bands, of length
#'   `length(values)`; defaults to formatted interval strings.
#' @return A function of one numeric argument returning the band payoff for each
#'   element, with class `grade_band_value` and the schedule stored as
#'   attributes (`breaks`, `values`, `labels`, `right`).
#' @examples
#' # An APW-style protein payoff: $/t steps up as protein clears each band.
#' v <- grade_band_value(breaks = c(10.5, 11.5, 13),
#'                       values = c(300, 330, 360, 400))
#' v(c(9.0, 11.0, 11.5, 14.0))
#' v
#' @seealso [grade_band_utility()] to turn the schedule into a `decide()`
#'   utility; [decide()] for the engine that consumes it.
#' @family loss
#' @export
grade_band_value <- function(breaks, values, right = FALSE, labels = NULL) {
  .check_grade_band(breaks, values)
  if (is.null(labels)) {
    edges <- c(-Inf, breaks, Inf)
    labels <- vapply(
      seq_along(values),
      function(i) {
        lo <- edges[i]
        hi <- edges[i + 1L]
        if (right) {
          sprintf("(%s, %s]", format(lo), format(hi))
        } else {
          sprintf("[%s, %s)", format(lo), format(hi))
        }
      },
      character(1L)
    )
  } else if (length(labels) != length(values)) {
    stop("`labels` must have one element per band (length of `values`)",
         call. = FALSE)
  }

  force(breaks)
  force(values)
  force(right)
  fn <- function(quality) {
    if (!is.numeric(quality)) {
      stop("`quality` must be numeric", call. = FALSE)
    }
    # findInterval places each outcome into a band index. `rightmost.closed` and
    # `left.open` translate the band-edge convention: with right = FALSE we want
    # an outcome on a break to fall into the higher band, which is findInterval's
    # default left-closed behaviour.
    idx <- findInterval(quality, breaks, left.open = right) + 1L
    out <- values[idx]
    out[is.na(quality)] <- NA_real_
    out
  }
  attr(fn, "breaks") <- breaks
  attr(fn, "values") <- values
  attr(fn, "labels") <- labels
  attr(fn, "right")  <- right
  class(fn) <- c("grade_band_value", "function")
  fn
}

#' Print a grade-band value schedule
#'
#' @param x A [grade_band_value] schedule.
#' @param ... Ignored, for compatibility with [print()].
#' @return `x`, invisibly.
#' @examples
#' print(grade_band_value(c(10.5, 11.5), c(300, 330, 360)))
#' @export
print.grade_band_value <- function(x, ...) {
  tbl <- data.frame(
    band  = attr(x, "labels"),
    value = attr(x, "values"),
    stringsAsFactors = FALSE
  )
  cat(sprintf("<grade_band_value> %d bands\n", nrow(tbl)))
  print(tbl, row.names = FALSE)
  invisible(x)
}

#' Build a decide() utility from a grade-band schedule
#'
#' Turns a [grade_band_value] schedule into a `utility(action, theta)` function
#' the decision engine consumes. `theta` is a posterior draw of the quality
#' outcome (grain protein, say); the action shifts that outcome through
#' `quality_shift`, a function `function(action, theta)` returning the realised
#' quality under the action. The utility of an action at a draw is the band
#' payoff of the shifted outcome, less an optional per-unit action cost. Because
#' the payoff is a step function, the expected utility decideR averages over the
#' draws is governed by each band's posterior probability -- exactly the
#' threshold economics a quality-graded decision faces.
#'
#' When `quality_shift` is left `NULL` the action is taken to *be* the quality
#' outcome offset added to `theta` (the common case where an input nudges the
#' outcome additively), so `quality = theta + action`. Supply a `quality_shift`
#' for any non-additive response (a saturating dose-response, say).
#'
#' @param value A [grade_band_value] schedule.
#' @param quality_shift A function `function(action, theta)` returning the
#'   realised quality outcome under the action, or `NULL` for the additive
#'   default `theta + action`.
#' @param cost A function `function(action)` returning the action's cost, or a
#'   single numeric per-unit cost applied as `cost * action`, or `0` for no
#'   cost.
#' @return A function `function(action, theta)` suitable as the `utility`
#'   argument to [decide()].
#' @examples
#' v <- grade_band_value(c(10.5, 11.5, 13), c(300, 330, 360, 400))
#' # A nitrogen rate lifts protein additively; protein costs nothing but N does.
#' u <- grade_band_utility(v, quality_shift = function(rate, protein)
#'                           protein + 0.01 * rate, cost = 1.2)
#' set.seed(1L)
#' protein <- rnorm(2000L, mean = 11.0, sd = 0.6)
#' decide(protein, u, candidates = seq(0, 150, by = 25),
#'        grounding = grounding_grounded(), safe_action = 0)
#' @seealso [grade_band_value()] for the schedule; [decide()] for the engine.
#' @family loss
#' @export
grade_band_utility <- function(value, quality_shift = NULL, cost = 0) {
  if (!inherits(value, "grade_band_value")) {
    stop("`value` must be a grade_band_value() schedule", call. = FALSE)
  }
  shift <- if (is.null(quality_shift)) {
    function(action, theta) theta + action
  } else {
    if (!is.function(quality_shift)) {
      stop("`quality_shift` must be NULL or a function of (action, theta)",
           call. = FALSE)
    }
    quality_shift
  }
  cost_fn <- if (is.function(cost)) {
    cost
  } else {
    if (!is.numeric(cost) || length(cost) != 1L) {
      stop("`cost` must be a single numeric, a function, or 0", call. = FALSE)
    }
    function(action) cost * action
  }

  function(action, theta) {
    quality <- shift(action, theta)
    if (length(quality) != length(theta)) {
      stop("`quality_shift` must return one value per draw", call. = FALSE)
    }
    value(quality) - cost_fn(action)
  }
}
