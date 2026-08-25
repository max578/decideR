# =============================================================================
# Benefit-cost analysis
# =============================================================================
# The institutional close of an ORCHESTRA study: a research investment produces
# a stream of benefits over a horizon and consumes a stream of costs, and the
# question a funder asks is whether the discounted benefits repay the
# discounted costs. `decide_bcr()` is that arithmetic, made auditable -- every
# component the ratio is assembled from is returned beside it -- and made
# honest: a benefit stream whose provenance is `[unverified]` prices out as a
# typed abstention rather than as a ratio a funding submission would quote.

# Discount factors for `horizon` periods indexed t = 0, 1, ..., horizon - 1.
# The first period is the present and is NOT discounted; a stream stated as
# end-of-period cash flows is expressed by leading the benefit stream with a
# zero. The convention is stated rather than inferred because the two
# conventions differ by a factor of (1 + r) and a reader cannot tell which was
# used from the ratio alone.
.discount_factors <- function(discount_rate, horizon) {
  (1 + discount_rate)^-(seq_len(horizon) - 1L)
}

# Pad a stream to the horizon with zeros. A stream LONGER than the horizon is
# an error, never a silent truncation: dropping the tail of a benefit stream
# quietly understates a ratio, which is the failure mode this package exists
# to refuse.
.pad_stream <- function(x, horizon, what) {
  if (!is.numeric(x) || length(x) == 0L || anyNA(x)) {
    stop(sprintf("`%s` must be a non-empty numeric stream with no NA", what),
         call. = FALSE)
  }
  if (length(x) > horizon) {
    stop(
      sprintf(
        paste0("`%s` covers %d periods but `horizon` is %d -- lengthen the ",
               "horizon rather than truncating the stream"),
        what, length(x), horizon
      ),
      call. = FALSE
    )
  }
  c(as.numeric(x), rep(0, horizon - length(x)))
}

# -----------------------------------------------------------------------------
# Exported benefit-cost ratio
# -----------------------------------------------------------------------------

#' Benefit-cost ratio of a research investment
#'
#' Discounts a stream of benefits and a stream of costs at an explicit rate
#' over an explicit horizon and reports the components an impact assessment is
#' written from -- the two streams, the present value of each, the net present
#' value, and the ratio:
#' \deqn{PV = \sum_{t=0}^{H-1} \frac{x_t}{(1 + r)^t}, \quad
#'       NPV = PV_B - PV_C, \quad BCR = PV_B / PV_C.}
#' This is the CRRDC-style reporting set an Australian rural research and
#' development impact assessment closes with. decideR encodes no guideline
#' default for the rate or the horizon: both are stated by the assessment the
#' analysis serves and are the caller's to supply, so a ratio can never be
#' quoted against an assumption its author did not make.
#'
#' Period `t = 0` is the present and is not discounted. A stream given as
#' end-of-period cash flows is expressed by leading it with a zero, as in the
#' worked example below. Streams shorter than the horizon are zero-padded;
#' a stream longer than the horizon is an error rather than a silent
#' truncation.
#'
#' When `manifest` is supplied, the benefit stream and its grounding token are
#' read from it through the same duck-typed contract accessors the decision
#' tail uses (`outputs`, then `metadata[[draws_key]]`; grounding from
#' `metadata$grounding` or `summary$metrics$grounding`), with draws in rows and
#' periods in columns. The point estimate then uses the posterior mean stream,
#' and the posterior distribution of the ratio is summarised in
#' `components$bcr_quantiles`. An `[unverified]` manifest returns an abstained
#' valuation, never a ratio.
#'
#' @param benefits The benefit stream: a numeric vector, one value per period
#'   from `t = 0`, or a numeric matrix of posterior draws (rows) by periods
#'   (columns). May be `NULL` when `manifest` supplies it.
#' @param costs The cost stream, a numeric vector, one value per period from
#'   `t = 0`.
#' @param discount_rate The real discount rate per period, as a proportion
#'   (e.g. `0.05` for five per cent).
#' @param horizon The number of periods, `t = 0, ..., horizon - 1`; defaults to
#'   the longer of the two streams.
#' @param grounding Optional grounding token(s) for the streams, combined
#'   worst-case; defaults to the manifest's own token, or to
#'   `grounding_unverified()` when no manifest is supplied.
#' @param manifest Optional `orchestra_manifest` S7 object supplying the
#'   benefit stream and its grounding.
#' @param draws_key The `metadata` key under which the benefit draws are sought
#'   when the manifest's `outputs` slot is empty.
#' @param probs Quantiles at which the posterior ratio is summarised when the
#'   benefit stream arrives as draws.
#' @param metadata A named list of free-form metadata.
#' @return A [valuation] of `type = "bcr"` whose `value` is the ratio and whose
#'   `components` carry the discounted streams, the two present values and the
#'   net present value.
#' @examples
#' # A two-period investment: 100 spent now, 210 returned next period, at a
#' # five per cent discount rate. PV(costs) = 100, PV(benefits) = 210/1.05 =
#' # 200, so NPV = 100 and BCR = 2.
#' v <- decide_bcr(benefits = c(0, 210), costs = c(100, 0),
#'                 discount_rate = 0.05,
#'                 grounding = grounding_grounded())
#' v@value
#' v@components$npv
#'
#' # The same investment on an un-grounded benefit stream prices out as an
#' # abstention rather than as a ratio.
#' decide_bcr(benefits = c(0, 210), costs = c(100, 0), discount_rate = 0.05)
#' @seealso [decide_evsi()] for the value of the next study rather than of the
#'   whole programme.
#' @family value
#' @export
decide_bcr <- function(benefits = NULL, costs, discount_rate, horizon = NULL,
                       grounding = NULL, manifest = NULL,
                       draws_key = "benefit_draws",
                       probs = c(0.05, 0.5, 0.95), metadata = list()) {
  method <- "discounted_benefit_cost_ratio"
  if (!is.numeric(discount_rate) || length(discount_rate) != 1L ||
        is.na(discount_rate) || discount_rate <= -1) {
    stop("`discount_rate` must be a single number greater than -1",
         call. = FALSE)
  }
  if (is.null(benefits) && is.null(manifest)) {
    stop("supply `benefits`, or a `manifest` carrying the benefit draws",
         call. = FALSE)
  }

  # Provenance first: the streams may be read from a manifest, in which case
  # the manifest's grounding token rides through to the ratio.
  draws <- NULL
  inputs <- list()
  if (!is.null(manifest)) {
    if (is.null(benefits)) {
      draws <- .manifest_draws(manifest, draws_key = draws_key)
      benefits <- colMeans(draws)
    }
    if (is.null(grounding)) {
      grounding <- .manifest_grounding(manifest)
    }
    inputs <- list(
      manifest_run_id = .manifest_prop(manifest, "run_id",
                                       default = NA_character_),
      emitter_package = .manifest_prop(manifest, "emitter_package",
                                       default = NA_character_)
    )
  }
  if (is.matrix(benefits)) {
    draws <- benefits
    benefits <- colMeans(draws)
  }
  g <- combine_grounding(grounding %||% grounding_unverified())

  if (is.null(horizon)) {
    horizon <- max(length(benefits), length(costs))
  }
  if (!is.numeric(horizon) || length(horizon) != 1L || horizon < 1L) {
    stop("`horizon` must be a single positive number of periods",
         call. = FALSE)
  }
  horizon <- as.integer(horizon)
  b_stream <- .pad_stream(benefits, horizon, "benefits")
  c_stream <- .pad_stream(costs, horizon, "costs")
  dfac <- .discount_factors(discount_rate, horizon)

  if (!.is_grounded(g)) {
    return(.valuation_abstain(
      type = "bcr", reason = "input_ungrounded", grounding = g,
      method = method, inputs = inputs, metadata = metadata
    ))
  }
  pv_b <- sum(b_stream * dfac)
  pv_c <- sum(c_stream * dfac)
  if (!is.finite(pv_c) || pv_c <= 0) {
    return(.valuation_abstain(
      type = "bcr", reason = "undefined_ratio", grounding = g,
      method = method, inputs = inputs, metadata = metadata
    ))
  }

  comp <- list(
    benefit_stream            = b_stream,
    cost_stream               = c_stream,
    discount_factors          = dfac,
    discount_rate             = discount_rate,
    horizon                   = horizon,
    present_value_benefits    = pv_b,
    present_value_costs       = pv_c,
    npv                       = pv_b - pv_c,
    bcr                       = pv_b / pv_c
  )
  if (!is.null(draws)) {
    pv_draws <- as.numeric(.pad_draws(draws, horizon) %*% dfac)
    comp$n_draws <- nrow(draws)
    comp$bcr_quantiles <- stats::quantile(pv_draws / pv_c, probs = probs,
                                          names = TRUE)
  }
  valuation(
    value      = pv_b / pv_c,
    type       = "bcr",
    components = comp,
    grounding  = g,
    method     = method,
    inputs     = inputs,
    metadata   = metadata
  )
}

# Pad a draws-by-periods benefit matrix out to the horizon with zero columns,
# so the per-draw present value uses the identical discount vector as the
# point estimate.
.pad_draws <- function(draws, horizon) {
  if (ncol(draws) > horizon) {
    stop(
      sprintf(
        paste0("the benefit draws cover %d periods but `horizon` is %d -- ",
               "lengthen the horizon rather than truncating the stream"),
        ncol(draws), horizon
      ),
      call. = FALSE
    )
  }
  if (ncol(draws) == horizon) {
    return(draws)
  }
  cbind(draws, matrix(0, nrow = nrow(draws), ncol = horizon - ncol(draws)))
}
