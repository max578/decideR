# =============================================================================
# Reference decisions
# =============================================================================
# Two decisions from two domains -- a bounded agronomic input rate and a
# constraint-capped trading position -- both expressed as expected-utility
# maximisation over a candidate grid and both routed through the identical
# `.decide_core()`. They exist to prove the shared-keystone premise concretely:
# one decision engine serves crops and markets, and the Independent Oracle
# Principle firewall (abstain on un-grounded input) applies the same way to a
# nitrogen rate and to real money.

# The `...` names both reference decisions harvest and pass on to
# `.decide_core()`. Anything outside this set is a caller mistake (a
# misspelled argument, or one that belongs to the other reference decision)
# and must not be silently swallowed the way a bare `list(...)[["min_ess"]]`
# read would.
.REFERENCE_DECISION_DOTS <- c("min_ess", "ess", "constraint", "safe_label",
                              "method", "metadata", "inputs")

# Validate the names of `...` against the accepted set, stopping loudly on
# anything unrecognised rather than discarding it.
.check_reference_dots <- function(dots, caller) {
  unknown <- setdiff(names(dots), .REFERENCE_DECISION_DOTS)
  if (length(unknown) > 0L) {
    stop(
      sprintf(
        "%s(): unrecognised `...` argument(s) %s -- accepted names are %s",
        caller, paste(sQuote(unknown), collapse = ", "),
        paste(.REFERENCE_DECISION_DOTS, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# -----------------------------------------------------------------------------
# Agronomy: bounded input-rate selection
# -----------------------------------------------------------------------------

#' Choose a crop input rate by expected profit
#'
#' A reference decision for the agronomic domain. Given posterior draws of yield
#' at each candidate input rate -- the kind of object a mechanistic-simulator
#' inversion (PESTO) or a causal test (TACI) emits -- it selects the rate that
#' maximises expected profit, \eqn{E[p_y\,y(r) - p_r\,r]}, where \eqn{p_y} is the
#' grain price and \eqn{p_r} the input price. It abstains to `safe_rate` when the
#' yield evidence is un-grounded or the leading rate is not decisive.
#'
#' @param yield_draws A numeric matrix of posterior yield draws, one column per
#'   candidate rate (rows are draws).
#' @param rates A numeric vector of candidate input rates, one per column of
#'   `yield_draws`.
#' @param price_grain Grain price per unit yield.
#' @param price_input Input price per unit rate.
#' @param grounding One or more grounding tokens for the yield evidence;
#'   combined worst-case.
#' @param safe_rate The fallback rate on abstention (default `0`, the
#'   no-input status quo).
#' @param decisive_prob Minimum posterior probability that the leading rate is
#'   best (see [decide()]).
#' @param ... Further arguments passed to the decision core: `min_ess`, `ess`,
#'   `constraint` (a `function(rate)` feasibility check), `safe_label`,
#'   `method`, `metadata`, `inputs`. Any other name stops with an error rather
#'   than being silently discarded.
#' @return A [decision] object whose `action` is the chosen rate.
#' @examples
#' set.seed(1L)
#' rates <- seq(0, 200, by = 40)
#' # diminishing-returns yield response with posterior noise
#' mu <- 3 + 2.5 * (1 - exp(-rates / 80))
#' yield_draws <- sapply(mu, function(m) rnorm(1500L, m, 0.3))
#' decide_input_rate(yield_draws, rates, price_grain = 300, price_input = 1.2,
#'                   grounding = grounding_grounded())
#' @seealso [decide()] for the underlying engine; [decide_position_size()] for
#'   the trading counterpart.
#' @family decisions
#' @export
decide_input_rate <- function(yield_draws, rates, price_grain, price_input,
                              grounding = grounding_unverified(),
                              safe_rate = 0, decisive_prob = 0.6, ...) {
  if (!is.matrix(yield_draws) || ncol(yield_draws) != length(rates)) {
    stop("`yield_draws` must be a matrix with one column per rate",
         call. = FALSE)
  }
  dots <- list(...)
  .check_reference_dots(dots, "decide_input_rate")
  grounding <- combine_grounding(grounding)
  util_matrix <- price_grain * yield_draws -
    matrix(price_input * rates, nrow = nrow(yield_draws),
           ncol = length(rates), byrow = TRUE)
  labels <- sprintf("rate=%g", rates)

  .decide_core(
    util_matrix   = util_matrix, candidates = rates, labels = labels,
    constraint    = dots[["constraint"]], grounding = grounding,
    safe_action   = safe_rate,
    safe_label    = dots[["safe_label"]] %||%
                    sprintf("rate=%g (status quo)", safe_rate),
    min_ess       = dots[["min_ess"]], ess = dots[["ess"]],
    decisive_prob = decisive_prob,
    method        = dots[["method"]] %||% "expected_profit",
    inputs        = dots[["inputs"]] %||%
                    list(rates = rates, price_grain = price_grain,
                        price_input = price_input),
    metadata      = dots[["metadata"]] %||% list(domain = "agronomy")
  )
}

# -----------------------------------------------------------------------------
# Trading: constraint-capped position sizing
# -----------------------------------------------------------------------------

#' Size a trading position by capped expected log-growth under a loss-quantile
#' limit
#'
#' A reference decision for the trading domain. Given predictive draws of the
#' next-period simple return, it chooses the fraction of capital that maximises
#' expected log-growth \eqn{E[\log(1 + f\,r)]} (the Kelly objective) over a grid
#' bounded by `kelly_cap`, subject to a hard one-period loss-quantile
#' constraint: a fraction is feasible only if its `loss_quantile` return
#' quantile is no worse than `-max_drawdown`. **This guard is a single-period
#' value-at-risk floor, not a path drawdown** -- `max_drawdown` names the worst
#' `loss_quantile`-fraction of *next-period* returns the position may be
#' exposed to, not a peak-to-trough statistic accumulated over a trading path;
#' a true multi-period drawdown limit is not computed here. With no edge the
#' grid maximiser is naturally flat; with an edge the constraint caps the size.
#' It abstains to flat (`0`) when the return evidence is un-grounded -- the
#' capital firewall: never stake real money on a market fact that has not been
#' verified against the exchange.
#'
#' @param return_draws A numeric vector of predictive next-period simple returns.
#' @param capital The capital available; the dollar position is
#'   `fraction * capital`.
#' @param max_drawdown The hard one-period loss-quantile cap (e.g. `0.15`) --
#'   a value-at-risk floor on the *next-period* return, not a multi-period
#'   peak-to-trough drawdown.
#' @param kelly_cap The maximum fraction of capital (a fractional-Kelly ceiling).
#' @param n_grid The number of fractions evaluated on `[0, kelly_cap]`.
#' @param loss_quantile The lower return quantile the `max_drawdown` guard is
#'   evaluated at.
#' @param grounding One or more grounding tokens for the return evidence;
#'   combined worst-case.
#' @param decisive_prob Minimum posterior probability that the leading fraction
#'   is best (see [decide()]).
#' @param ... Further arguments passed to the decision core: `min_ess`, `ess`,
#'   `constraint` (a `function(fraction)` feasibility check, ANDed onto the
#'   hard drawdown constraint -- it can only tighten feasibility, never
#'   loosen it), `safe_label`, `method`, `metadata`, `inputs`. Any other name
#'   stops with an error rather than being silently discarded.
#' @return A [decision] object whose `action` is the chosen fraction of capital;
#'   the implied dollar position is in `@metadata$position`.
#' @examples
#' set.seed(1L)
#' # a small positive edge with fat tails
#' r <- 0.004 + 0.02 * rt(4000L, df = 4) / sqrt(2)
#' decide_position_size(r, capital = 1000, max_drawdown = 0.15,
#'                      grounding = grounding_grounded())
#' @seealso [decide()] for the underlying engine; [decide_input_rate()] for the
#'   agronomic counterpart.
#' @family decisions
#' @export
decide_position_size <- function(return_draws, capital, max_drawdown,
                                 kelly_cap = 0.5, n_grid = 41L,
                                 loss_quantile = 0.05,
                                 grounding = grounding_unverified(),
                                 decisive_prob = 0.6, ...) {
  if (!is.numeric(return_draws) || length(return_draws) == 0L) {
    stop("`return_draws` must be a non-empty numeric vector", call. = FALSE)
  }
  if (max_drawdown <= 0) {
    stop("`max_drawdown` must be positive", call. = FALSE)
  }
  dots <- list(...)
  .check_reference_dots(dots, "decide_position_size")
  grounding <- combine_grounding(grounding)
  fracs <- seq(0, kelly_cap, length.out = n_grid)

  util_matrix <- vapply(
    fracs,
    function(f) {
      u <- log1p(f * return_draws)
      u[is.nan(u)] <- -Inf            # ruin (1 + f r <= 0) -> avoided
      u
    },
    numeric(length(return_draws))
  )

  drawdown_constraint <- function(f) {
    if (f == 0) {
      return(TRUE)
    }
    q <- stats::quantile(f * return_draws, probs = loss_quantile,
                         names = FALSE, type = 7L)
    q >= -max_drawdown
  }
  # A caller-supplied `constraint` (via `...`) ANDs onto the hard drawdown
  # guard rather than replacing it -- the drawdown cap is a non-negotiable
  # capital-firewall constraint, not a default a caller can silently override.
  extra_constraint <- dots[["constraint"]]
  constraint <- if (is.null(extra_constraint)) {
    drawdown_constraint
  } else {
    function(f) isTRUE(drawdown_constraint(f)) && isTRUE(extra_constraint(f))
  }

  labels <- sprintf("size=%.1f%% (=%.0f)", 100 * fracs, fracs * capital)
  d <- .decide_core(
    util_matrix   = util_matrix, candidates = fracs, labels = labels,
    constraint    = constraint, grounding = grounding, safe_action = 0,
    safe_label    = dots[["safe_label"]] %||% "flat (0%)",
    min_ess       = dots[["min_ess"]], ess = dots[["ess"]],
    decisive_prob = decisive_prob,
    method        = dots[["method"]] %||% "kelly_log_growth_drawdown_capped",
    inputs        = dots[["inputs"]] %||%
                    list(capital = capital, max_drawdown = max_drawdown,
                        kelly_cap = kelly_cap, loss_quantile = loss_quantile),
    metadata      = dots[["metadata"]] %||% list(domain = "trading")
  )
  d@metadata <- c(d@metadata, list(position = d@action * capital))
  d
}
