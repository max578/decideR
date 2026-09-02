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

# =============================================================================
# CRRDC-guideline benefit-cost ratio
# =============================================================================
# `decide_bcr()` above prices a generic discounted benefit-cost ratio and
# leaves the assumptions -- the rate, the horizon, whether the benefit stream
# is already incremental -- entirely to the caller. The Council of Rural
# Research and Development Corporations' impact-assessment guidelines make
# four of those assumptions mandatory rather than optional for an Australian
# agricultural R&D benefit-cost ratio: an explicit counterfactual (what would
# have happened anyway), an explicit attribution share (how much of the
# incremental benefit this investment alone caused, against co-funders and
# spillovers), an adoption profile with lags (uptake is never implicit 100%
# from year one), and a discount-rate sensitivity band around the central
# rate. `bcr_crrdc()` is that guideline, made executable: it refuses to
# construct a ratio without all four, and reports the ratio at the central
# rate and at the CRRDC sensitivity rates side by side.

# Validate a year/value stream data.frame (benefits, costs, or a
# data.frame-shaped counterfactual). Shared by all three because a CRRDC
# stream has the identical shape regardless of what it represents.
.check_bcr_stream <- function(x, what) {
  if (!is.data.frame(x) || !all(c("year", "value") %in% names(x))) {
    stop(
      sprintf("`%s` must be a data.frame with columns `year` and `value`",
              what),
      call. = FALSE
    )
  }
  if (nrow(x) == 0L || anyNA(x$year) || anyNA(x$value)) {
    stop(
      sprintf(
        "`%s` must have at least one row with no NA in `year` or `value`",
        what
      ),
      call. = FALSE
    )
  }
  if (!is.numeric(x$year) || !is.numeric(x$value)) {
    stop(sprintf("`%s$year` and `%s$value` must both be numeric", what, what),
         call. = FALSE)
  }
  if (anyDuplicated(x$year) > 0L) {
    stop(sprintf("`%s$year` must not contain duplicate years", what),
         call. = FALSE)
  }
  invisible(TRUE)
}

# Attribution is the one CRRDC input that is a single number, not a stream:
# the proportion of the incremental benefit this investment alone caused.
.check_bcr_attribution <- function(attribution) {
  if (!is.numeric(attribution) || length(attribution) != 1L ||
        is.na(attribution) || attribution <= 0 || attribution > 1) {
    stop(
      paste0("`attribution` must be a single number in (0, 1] -- the share ",
             "of the incremental benefit attributable to this investment"),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# The counterfactual is either a benefits-under-counterfactual stream
# (subtracted from `benefits` year by year) or the caller's declaration that
# `benefits` is already incremental, named by `counterfactual_label`. Either
# way it must cover every year `benefits` covers -- a benefit year with no
# matching counterfactual year cannot be net of anything.
.check_bcr_counterfactual <- function(counterfactual, counterfactual_label,
                                      benefit_years) {
  if (identical(counterfactual, "already_net")) {
    if (is.null(counterfactual_label) ||
          !is.character(counterfactual_label) ||
          length(counterfactual_label) != 1L || is.na(counterfactual_label) ||
          !nzchar(counterfactual_label)) {
      stop(
        paste0("`counterfactual_label` (a single non-empty character string ",
               "naming the declared counterfactual) is required when ",
               "`counterfactual = \"already_net\"`"),
        call. = FALSE
      )
    }
    return(invisible(TRUE))
  }
  if (is.data.frame(counterfactual)) {
    .check_bcr_stream(counterfactual, "counterfactual")
    absent <- setdiff(benefit_years, counterfactual$year)
    if (length(absent) > 0L) {
      stop(
        sprintf(
          paste0("`counterfactual` does not cover benefit year(s) %s -- ",
                 "CRRDC guidelines require the counterfactual to span every ",
                 "benefit year"),
          paste(sort(absent), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    return(invisible(TRUE))
  }
  stop(
    paste0("`counterfactual` must be a data.frame(year, value) or the ",
           "string \"already_net\""),
    call. = FALSE
  )
}

# The adoption profile is the CRRDC lag: uptake in [0, 1] by year, applied
# multiplicatively to the (net, attributed) benefit stream. It must cover
# every benefit year -- an implicit 100% for a year the profile omits is
# exactly what CRRDC guidelines forbid.
.check_bcr_adoption <- function(adoption, benefit_years) {
  if (!is.data.frame(adoption) ||
        !all(c("year", "uptake") %in% names(adoption))) {
    stop("`adoption` must be a data.frame with columns `year` and `uptake`",
         call. = FALSE)
  }
  if (nrow(adoption) == 0L || anyNA(adoption$year) || anyNA(adoption$uptake)) {
    stop(
      "`adoption` must have at least one row with no NA in `year` or `uptake`",
      call. = FALSE
    )
  }
  if (!is.numeric(adoption$uptake) ||
        any(adoption$uptake < 0 | adoption$uptake > 1)) {
    stop(
      paste0("`adoption$uptake` must lie in [0, 1] -- CRRDC guidelines ",
             "forbid an implicit 100% uptake"),
      call. = FALSE
    )
  }
  absent <- setdiff(benefit_years, adoption$year)
  if (length(absent) > 0L) {
    stop(
      sprintf(
        paste0("`adoption` does not cover benefit year(s) %s -- an adoption ",
               "lag profile must span every benefit year"),
        paste(sort(absent), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# discount_central is a single rate; discount_sensitivity is a non-empty
# vector of rates reported alongside it. Both share the same floor: a real
# discount rate of exactly -100% (or below) makes the discount factor
# infinite or undefined.
.check_bcr_discount_central <- function(x) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || x <= -1) {
    stop("`discount_central` must be a single number greater than -1",
         call. = FALSE)
  }
  invisible(TRUE)
}

.check_bcr_discount_sensitivity <- function(x) {
  if (!is.numeric(x) || length(x) == 0L || anyNA(x) || any(x <= -1)) {
    stop(
      paste0("`discount_sensitivity` must be a non-empty numeric vector, ",
             "every rate greater than -1"),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# Present value of a year-indexed stream at one discount rate, anchored at
# base_year. `bcr_crrdc()`'s streams carry calendar years rather than the
# period index `.discount_factors()` (above) assumes, so the discounting runs
# directly against `year - base_year` rather than against a period sequence.
.pv_at_year <- function(value, year, base_year, rate) {
  sum(value * (1 + rate)^-(year - base_year))
}

# Mint an abstained decider_bcr: every rate's pv/npv/bcr is NA, but the
# declared counterfactual, attribution and adoption profile ride through
# unchanged, so a reader can see exactly what was asked for even though
# nothing was priced. Class-stamped `decideR_abstention` (the same literal
# token `.stamp_abstention_class()` uses for the S7 result types), so the
# federation's `is_orchestra_decline()` predicate recognises it by the shared
# class-suffix convention without decideR's one S3 result type needing S7
# property access.
.bcr_crrdc_abstain <- function(reason, grounding, counterfactual_label,
                               attribution, adoption, base_year, rate_values) {
  out <- list(
    rates = data.frame(
      rate_label       = names(rate_values),
      rate             = as.numeric(rate_values),
      pv_benefits      = NA_real_,
      pv_costs         = NA_real_,
      npv              = NA_real_,
      bcr              = NA_real_,
      stringsAsFactors = FALSE,
      row.names        = NULL
    ),
    counterfactual_label = counterfactual_label,
    attribution           = attribution,
    adoption              = adoption,
    base_year             = base_year,
    grounding             = grounding,
    abstained             = TRUE,
    abstain_reason        = reason
  )
  class(out) <- c("decideR_abstention", "decider_bcr")
  out
}

# -----------------------------------------------------------------------------
# Exported CRRDC benefit-cost ratio
# -----------------------------------------------------------------------------

#' CRRDC-guideline benefit-cost ratio
#'
#' Discounts a benefit stream and a cost stream to a benefit-cost ratio in the
#' shape a Council of Rural Research and Development Corporations (CRRDC)
#' impact assessment reports, with the four inputs the guidelines make
#' mandatory: an explicit counterfactual, an explicit attribution share, an
#' adoption profile with lags, and a discount-rate sensitivity band around the
#' central rate. Where [decide_bcr()] leaves those assumptions to the caller,
#' `bcr_crrdc()` refuses to construct a ratio without all four -- a
#' benefit-cost ratio that implicitly assumes no counterfactual, full
#' attribution and instant 100% uptake is exactly what the guidelines forbid.
#'
#' `counterfactual` states what would have happened without the investment.
#' Supply a `data.frame(year, value)` of benefits under the counterfactual
#' scenario, spanning every year `benefits` covers, and it is subtracted from
#' `benefits` year by year before attribution and adoption are applied.
#' Alternatively, when `benefits` already IS the incremental (net-of-
#' counterfactual) stream, pass `counterfactual = "already_net"` and name the
#' declared counterfactual in `counterfactual_label` -- the label is required
#' in this branch because a net stream carries no other record of what it is
#' net of.
#'
#' `attribution` is the proportion, in `(0, 1]`, of the incremental benefit
#' this investment alone caused, net of co-funders, extension effort and
#' other contributing causes. `adoption` is the uptake profile, a
#' `data.frame(year, uptake)` with `uptake` in `[0, 1]`, applied
#' multiplicatively to the net, attributed benefit stream; it must cover
#' every year `benefits` covers, so an adoption lag is always stated rather
#' than assumed away. Costs are not adjusted by attribution or adoption --
#' the investment cost is what was actually spent, not a share of a benefit.
#'
#' The ratio is reported at `discount_central` (the CRRDC standard is 5% for
#' Australian rural R&D) and, side by side, at every rate in
#' `discount_sensitivity` (the CRRDC standard band is 3% and 7%), so a reader
#' sees how sensitive the ratio is to the one assumption a guideline mandates
#' testing. `base_year` (period `t = 0`, undiscounted) defaults to the
#' earliest year across `benefits` and `costs`, so an investment whose costs
#' precede its first benefit year is discounted from the year spending began.
#'
#' Grounding rides the same Independent Oracle Principle firewall as the rest
#' of decideR: an un-grounded input (the default when `grounding` is not
#' supplied) returns an abstained `decider_bcr` with `abstain_reason =
#' "input_ungrounded"` and every rate's `pv_benefits`/`pv_costs`/`npv`/`bcr`
#' `NA`, never a ratio a funding submission would quote. A discounted cost
#' base that is not strictly positive at the central rate (a zero or
#' negative cost stream) abstains with `abstain_reason = "undefined_ratio"`
#' for the same reason.
#'
#' @param benefits A `data.frame(year, value)`: the (gross, pre-counterfactual)
#'   annual real benefit stream.
#' @param costs A `data.frame(year, value)`: the annual real cost stream. Not
#'   adjusted by `counterfactual`, `attribution` or `adoption`.
#' @param counterfactual Required, no default. Either a `data.frame(year,
#'   value)` of benefits under the counterfactual, spanning every year
#'   `benefits` covers, subtracted from `benefits`; or the string
#'   `"already_net"` declaring `benefits` is already incremental, in which
#'   case `counterfactual_label` is also required.
#' @param attribution Required, no default. A single number in `(0, 1]`: the
#'   share of the incremental benefit attributable to this investment.
#' @param adoption Required, no default. A `data.frame(year, uptake)` with
#'   `uptake` in `[0, 1]`, spanning every year `benefits` covers, applied
#'   multiplicatively to the net, attributed benefit stream.
#' @param counterfactual_label A single character string naming the declared
#'   counterfactual. Required when `counterfactual = "already_net"`;
#'   optional (used only for reporting) when `counterfactual` is a
#'   `data.frame`.
#' @param discount_central The central real discount rate, as a proportion
#'   (CRRDC's Australian rural R&D standard is `0.05`).
#' @param discount_sensitivity A numeric vector of sensitivity discount rates
#'   reported alongside `discount_central` (CRRDC's standard band is
#'   `c(0.03, 0.07)`).
#' @param base_year The undiscounted period-zero year; defaults to the
#'   earliest year across `benefits` and `costs`.
#' @param grounding Optional grounding token(s) for the input facts,
#'   combined worst-case with [combine_grounding()]; defaults to
#'   [grounding_unverified()] when not supplied.
#' @return A `decider_bcr` object: `rates` (a `data.frame` with one row per
#'   discount rate and columns `rate_label`, `rate`, `pv_benefits`,
#'   `pv_costs`, `npv`, `bcr`), `counterfactual_label`, `attribution`,
#'   `adoption`, `base_year`, `grounding`, `abstained` and `abstain_reason`.
#' @examples
#' # A ten-year, evenly-adopted, half-attributed investment. The benefit
#' # stream is already declared incremental against a named counterfactual.
#' bens <- data.frame(year = 2020:2029, value = rep(500, 10))
#' csts <- data.frame(year = 2020:2029, value = rep(1000, 10))
#' up   <- data.frame(year = 2020:2029, uptake = rep(1, 10))
#' bcr_crrdc(bens, csts, counterfactual = "already_net",
#'           counterfactual_label = "no new variety released",
#'           attribution = 0.5, adoption = up,
#'           grounding = grounding_grounded())
#' @seealso [decide_bcr()] for a benefit-cost ratio without the CRRDC
#'   mandatory inputs.
#' @family value
#' @export
bcr_crrdc <- function(benefits, costs, counterfactual, attribution, adoption,
                      counterfactual_label = NULL,
                      discount_central = 0.05,
                      discount_sensitivity = c(0.03, 0.07),
                      base_year = NULL, grounding = NULL) {
  if (missing(counterfactual)) {
    stop(
      paste0("`counterfactual` is required -- CRRDC guidelines forbid a ",
             "benefit-cost ratio without an explicit counterfactual"),
      call. = FALSE
    )
  }
  if (missing(attribution)) {
    stop(
      paste0("`attribution` is required -- CRRDC guidelines forbid a ",
             "benefit-cost ratio without an explicit attribution share"),
      call. = FALSE
    )
  }
  if (missing(adoption)) {
    stop(
      paste0("`adoption` is required -- CRRDC guidelines forbid a ",
             "benefit-cost ratio with an implicit 100% adoption; supply an ",
             "adoption/lag profile"),
      call. = FALSE
    )
  }

  # Structural validation, delegated to named helpers ------------------------
  .check_bcr_stream(benefits, "benefits")
  .check_bcr_stream(costs, "costs")
  .check_bcr_attribution(attribution)
  .check_bcr_counterfactual(counterfactual, counterfactual_label,
                            benefits$year)
  .check_bcr_adoption(adoption, benefits$year)
  .check_bcr_discount_central(discount_central)
  .check_bcr_discount_sensitivity(discount_sensitivity)

  if (is.null(base_year)) {
    base_year <- min(c(benefits$year, costs$year))
  }

  # Counterfactual, attribution and adoption ----------------------------------
  if (identical(counterfactual, "already_net")) {
    benefits_net <- benefits$value
    cf_label <- counterfactual_label
  } else {
    cf_value <- counterfactual$value[match(benefits$year, counterfactual$year)]
    benefits_net <- benefits$value - cf_value
    cf_label <- counterfactual_label %||% "supplied counterfactual data.frame"
  }
  uptake <- adoption$uptake[match(benefits$year, adoption$year)]
  benefits_final <- benefits_net * attribution * uptake

  g <- combine_grounding(grounding %||% grounding_unverified())
  rate_values <- c(central = discount_central,
                   stats::setNames(discount_sensitivity,
                                   paste0("sensitivity_",
                                          seq_along(discount_sensitivity))))

  if (!.is_grounded(g)) {
    return(.bcr_crrdc_abstain(
      reason = "input_ungrounded", grounding = g,
      counterfactual_label = cf_label, attribution = attribution,
      adoption = adoption, base_year = base_year, rate_values = rate_values
    ))
  }

  pv_b <- vapply(rate_values,
                 function(r) .pv_at_year(benefits_final, benefits$year,
                                         base_year, r),
                 numeric(1L))
  pv_c <- vapply(rate_values,
                 function(r) .pv_at_year(costs$value, costs$year, base_year,
                                         r),
                 numeric(1L))

  if (!is.finite(pv_c[["central"]]) || pv_c[["central"]] <= 0) {
    return(.bcr_crrdc_abstain(
      reason = "undefined_ratio", grounding = g,
      counterfactual_label = cf_label, attribution = attribution,
      adoption = adoption, base_year = base_year, rate_values = rate_values
    ))
  }

  out <- list(
    rates = data.frame(
      rate_label       = names(rate_values),
      rate             = as.numeric(rate_values),
      pv_benefits      = as.numeric(pv_b),
      pv_costs         = as.numeric(pv_c),
      npv              = as.numeric(pv_b - pv_c),
      bcr              = as.numeric(pv_b / pv_c),
      stringsAsFactors = FALSE,
      row.names        = NULL
    ),
    counterfactual_label = cf_label,
    attribution           = attribution,
    adoption              = adoption,
    base_year             = base_year,
    grounding             = g,
    abstained             = FALSE,
    abstain_reason        = NA_character_
  )
  class(out) <- "decider_bcr"
  out
}

# -----------------------------------------------------------------------------
# Printing and coercion
# -----------------------------------------------------------------------------

#' Print a CRRDC benefit-cost ratio
#'
#' @param x A [bcr_crrdc()] result.
#' @param ... Ignored, for compatibility with [print()].
#' @return `x`, invisibly.
#' @examples
#' bens <- data.frame(year = 2020:2021, value = c(0, 210))
#' csts <- data.frame(year = 2020:2021, value = c(100, 0))
#' up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
#' print(bcr_crrdc(bens, csts, counterfactual = "already_net",
#'                 counterfactual_label = "no intervention", attribution = 1,
#'                 adoption = up, grounding = grounding_grounded()))
#' @export
print.decider_bcr <- function(x, ...) {
  status <- if (isTRUE(x$abstained)) {
    sprintf("ABSTAINED (%s)", x$abstain_reason)
  } else {
    "priced"
  }
  cat(sprintf("<decider_bcr> %s  [%s]\n", status, x$grounding))
  cat(sprintf("  counterfactual: %s\n", x$counterfactual_label))
  cat(sprintf("  attribution   : %s\n", format(x$attribution, digits = 4L)))
  cat(sprintf("  base year     : %s\n", x$base_year))
  for (i in seq_len(nrow(x$rates))) {
    r <- x$rates[i, ]
    cat(sprintf("  BCR @ %s (%s%%): %s\n", r$rate_label,
                format(100 * r$rate, digits = 3L),
                format(r$bcr, digits = 5L)))
  } # ends i, over discount rates
  invisible(x)
}

#' Coerce a CRRDC benefit-cost ratio to a data.frame
#'
#' @param x A [bcr_crrdc()] result.
#' @param ... Ignored, for compatibility with [as.data.frame()].
#' @return The `rates` `data.frame`: one row per discount rate, columns
#'   `rate_label`, `rate`, `pv_benefits`, `pv_costs`, `npv`, `bcr`.
#' @examples
#' bens <- data.frame(year = 2020:2021, value = c(0, 210))
#' csts <- data.frame(year = 2020:2021, value = c(100, 0))
#' up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
#' as.data.frame(bcr_crrdc(bens, csts, counterfactual = "already_net",
#'                         counterfactual_label = "no intervention",
#'                         attribution = 1, adoption = up,
#'                         grounding = grounding_grounded()))
#' @export
as.data.frame.decider_bcr <- function(x, ...) {
  x$rates
}
