# Value of information (EVPI / EVSI).
#
# INDEPENDENT ORACLE. The expected values below are NOT produced by decideR.
# They are the closed-form two-action linear-Gaussian results of Raiffa, H. and
# Schlaifer, R. (1961) "Applied Statistical Decision Theory" (Harvard Business
# School), written in terms of the unit normal linear-loss integral
#
#   L_N(z) = phi(z) - z * (1 - Phi(z)),
#
# for the decision "act (payoff theta) or do nothing (payoff 0)" with prior
# theta ~ N(mu, sigma^2):
#
#   EVPI = sigma * L_N(|mu| / sigma)
#   EVSI = sigma_tilde * L_N(|mu| / sigma_tilde),
#     sigma_tilde = sigma^2 / sqrt(sigma^2 + sigma_s^2 / n),
#
# sigma_tilde being the pre-posterior standard deviation of the posterior mean
# after n observations of variance sigma_s^2 (Raiffa and Schlaifer's
# pre-posterior analysis; the EVSI two-loop algorithm decideR implements is
# that of Ades, A. E., Lu, G. and Claxton, K. (2004), Medical Decision Making
# 24(2), 207-227, doi:10.1177/0272989X04263162). Derivation of the identity
# used here: E[max(0, D)] = sigma * phi(d) + mu * Phi(d) with d = mu / sigma,
# and max_a E[U] = max(0, mu), whose difference is sigma * L_N(|d|).
#
# Both closed forms are limits of the same expression: EVSI -> EVPI as n -> Inf
# (sigma_tilde -> sigma), which the monotonicity test below exercises.

.unit_normal_loss <- function(z) {
  stats::dnorm(z) - z * (1 - stats::pnorm(z))
}

.evpi_closed <- function(mu, sigma) {
  sigma * .unit_normal_loss(abs(mu) / sigma)
}

.evsi_closed <- function(mu, sigma, sigma_s, n_obs) {
  s_tilde <- sigma^2 / sqrt(sigma^2 + sigma_s^2 / n_obs)
  s_tilde * .unit_normal_loss(abs(mu) / s_tilde)
}

# A minimal S7 stand-in for the contract surface the tail reads. The REAL
# `orchestra_manifest` is exercised in test-real-manifest-contract.R; here the
# object under grade is the value arithmetic, whose oracle is the closed form
# above rather than any manifest.
.voi_manifest <- S7::new_class(
  "voi_manifest",
  properties = list(
    outputs         = S7::new_property(S7::class_any, default = NULL),
    params          = S7::new_property(S7::class_any, default = NULL),
    metadata        = S7::new_property(S7::class_list, default = list()),
    summary         = S7::new_property(S7::class_any, default = NULL),
    run_id          = S7::new_property(S7::class_character,
                                       default = "voi-run"),
    emitter_package = S7::new_property(S7::class_character,
                                       default = "flexyBayes")
  )
)

# The two-action linear-Gaussian problem the closed forms describe: a single
# posterior column of the gain `theta` from acting, utility U(a, theta) =
# a * theta with a in {0, 1}.
.gain_manifest <- function(mu, sigma, n_draw,
                           grounding = grounding_grounded()) {
  theta <- stats::rnorm(n_draw, mean = mu, sd = sigma)
  .voi_manifest(
    outputs  = matrix(theta, ncol = 1L),
    params   = data.frame(gain = theta),
    metadata = list(grounding = grounding)
  )
}

.act_or_not <- function(a, theta) a * theta

test_that("decide_evpi() matches the Raiffa-Schlaifer closed form", {
  mu <- 0.5
  sigma <- 1
  set.seed(20260825L)
  m <- .gain_manifest(mu, sigma, n_draw = 200000L)
  v <- decide_evpi(m, candidates = c(0, 1), utility = .act_or_not)

  expect_s7_class(v, valuation)
  expect_identical(v@type, "evpi")
  expect_false(v@abstained)
  expect_true(v@value > 0)
  # Absolute agreement, since the quantity graded is a difference of two
  # expectations and a relative tolerance would be read against the wrong
  # scale. 0.01 is roughly six Monte Carlo standard errors at 200,000 draws
  # (the standard deviation of max(0, theta) is about 0.7), not a fitted
  # number.
  expect_lt(abs(v@value - .evpi_closed(mu, sigma)), 0.01)
  # the two expectations the value is the difference of, in the right order
  expect_gt(v@components$expected_utility_perfect_information,
            v@components$expected_utility_current_information)
})

test_that("EVPI is priced even when the decision itself is too close to call", {
  # The design point: `insufficient_evidence` is NOT a blocking reason -- a
  # too-close-to-call decision is exactly where information is worth buying.
  mu <- 0.02
  sigma <- 1
  set.seed(4242L)
  m <- .gain_manifest(mu, sigma, n_draw = 200000L)
  v <- decide_evpi(m, candidates = c(0, 1), utility = .act_or_not,
                   safe_action = 0)

  expect_true(v@baseline@abstained)
  expect_identical(v@baseline@abstain_reason, "insufficient_evidence")
  expect_false(v@abstained)
  expect_lt(abs(v@value - .evpi_closed(mu, sigma)), 0.01)
})

test_that("EVPI vanishes when one action dominates on every draw", {
  # Analytic identity, not a decideR output: with sigma -> 0 the state is known
  # and perfect information is worth nothing.
  set.seed(11L)
  m <- .gain_manifest(mu = 10, sigma = 0.01, n_draw = 5000L)
  v <- decide_evpi(m, candidates = c(0, 1), utility = .act_or_not)
  expect_lt(abs(v@value - 0), 1e-8)
})

test_that("an un-grounded manifest abstains rather than pricing information", {
  set.seed(7L)
  m <- .gain_manifest(0.5, 1, n_draw = 2000L,
                      grounding = grounding_unverified())
  v <- decide_evpi(m, candidates = c(0, 1), utility = .act_or_not)

  expect_true(v@abstained)
  expect_identical(v@abstain_reason, "input_ungrounded")
  expect_true(is.na(v@value))
  # recognised by the federation's `is_orchestra_decline()` naming convention
  expect_true(any(grepl("_abstention$", class(v))))
})

test_that("EVPI abstains when no action is feasible", {
  set.seed(8L)
  m <- .gain_manifest(0.5, 1, n_draw = 2000L)
  v <- decide_evpi(m, candidates = c(0, 1), utility = .act_or_not,
                   constraint = function(a) FALSE)
  expect_true(v@abstained)
  expect_identical(v@abstain_reason, "no_feasible_action")
  expect_true(is.na(v@value))
})

test_that("decide_evsi() matches the pre-posterior closed form", {
  mu <- 0.3
  sigma <- 1
  sigma_s <- 2
  n_obs <- 4L
  set.seed(31415L)
  m <- .gain_manifest(mu, sigma, n_draw = 8000L)
  trial <- list(
    label    = "four-plot strip trial",
    n_obs    = n_obs,
    simulate = function(state) mean(stats::rnorm(n_obs, state, sigma_s)),
    loglik   = function(y, state) {
      stats::dnorm(y, state, sigma_s / sqrt(n_obs), log = TRUE)
    }
  )
  v <- decide_evsi(m, candidates = c(0, 1), sample_design = trial,
                   utility = .act_or_not, n_pre = 8000L)

  expect_s7_class(v, valuation)
  expect_identical(v@type, "evsi")
  expect_false(v@abstained)
  expect_true(v@value > 0)
  # 0.02 absolute is between three and four times the outer loop's own
  # reported Monte Carlo standard error at n_pre = 8000 (`components$mc_se`,
  # about 0.006), which the next assertion states directly. It is a stated
  # multiple of the estimator's noise, not a fitted number.
  expect_lt(abs(v@value - .evsi_closed(mu, sigma, sigma_s, n_obs)), 0.02)
  expect_lt(abs(v@value - .evsi_closed(mu, sigma, sigma_s, n_obs)),
            4 * v@components$mc_se)
  # a finite sample can never be worth more than perfect information
  expect_lt(v@value, v@components$evpi_ceiling)
  expect_lt(abs(v@components$evpi_ceiling - .evpi_closed(mu, sigma)), 0.02)
  expect_identical(v@metadata$sample_label, "four-plot strip trial")
})

test_that("EVSI rises with the size of the prospective sample", {
  # Analytic identity: sigma_tilde is increasing in n, and so is
  # sigma_tilde * L_N(|mu| / sigma_tilde); EVSI -> EVPI as n -> Inf.
  mu <- 0.3
  sigma <- 1
  sigma_s <- 2
  small <- .evsi_closed(mu, sigma, sigma_s, 2L)
  large <- .evsi_closed(mu, sigma, sigma_s, 8L)
  expect_lt(small, large)

  make_design <- function(n_obs) {
    list(n_obs = n_obs,
         simulate = function(state) mean(stats::rnorm(n_obs, state, sigma_s)),
         loglik = function(y, state) {
           stats::dnorm(y, state, sigma_s / sqrt(n_obs), log = TRUE)
         })
  }
  set.seed(999L)
  m <- .gain_manifest(mu, sigma, n_draw = 8000L)
  v_small <- decide_evsi(m, candidates = c(0, 1),
                         sample_design = make_design(2L),
                         utility = .act_or_not, n_pre = 4000L)
  v_large <- decide_evsi(m, candidates = c(0, 1),
                         sample_design = make_design(8L),
                         utility = .act_or_not, n_pre = 4000L)
  expect_lt(v_small@value, v_large@value)
  expect_lt(abs(v_small@value - small), 0.02)
  expect_lt(abs(v_large@value - large), 0.02)
})

test_that("EVSI reports the sampling cost and the net value", {
  set.seed(5150L)
  m <- .gain_manifest(0.3, 1, n_draw = 4000L)
  design <- list(
    n_obs    = 4L,
    cost     = 0.05,
    simulate = function(state) mean(stats::rnorm(4L, state, 2)),
    loglik   = function(y, state) stats::dnorm(y, state, 1, log = TRUE)
  )
  v <- decide_evsi(m, candidates = c(0, 1), sample_design = design,
                   utility = .act_or_not, n_pre = 400L)
  expect_equal(v@components$cost, 0.05)
  expect_equal(v@components$net_value, v@value - 0.05)
})

test_that("EVSI abstains on an un-grounded manifest", {
  set.seed(6L)
  m <- .gain_manifest(0.3, 1, n_draw = 2000L,
                      grounding = grounding_unverified())
  design <- list(
    simulate = function(state) stats::rnorm(1L, state, 1),
    loglik   = function(y, state) stats::dnorm(y, state, 1, log = TRUE)
  )
  v <- decide_evsi(m, candidates = c(0, 1), sample_design = design,
                   utility = .act_or_not, n_pre = 50L)
  expect_true(v@abstained)
  expect_identical(v@abstain_reason, "input_ungrounded")
  expect_true(is.na(v@value))
})

test_that("the latent state is resolved explicitly, never guessed", {
  set.seed(12L)
  rates <- c(0, 50, 100)
  theta <- stats::rnorm(1500L, 5.5, 0.4)
  yld <- vapply(rates, function(r) 3 + (theta - 3) * (1 - exp(-r / 80)),
                numeric(1500L))
  m <- .voi_manifest(
    outputs  = yld,
    params   = data.frame(ymax = theta),
    metadata = list(grounding = grounding_grounded())
  )
  design <- list(
    simulate = function(state) stats::rnorm(1L, state, 0.5),
    loglik   = function(y, state) stats::dnorm(y, state, 0.5, log = TRUE)
  )
  # a multi-column outcome grid carries no self-evident latent state
  expect_error(
    decide_evsi(m, candidates = rates, sample_design = design,
                utility = function(r, y) 300 * y - 1.2 * r, n_pre = 20L),
    "cannot infer the latent state"
  )
  # naming the manifest's `params` column resolves it
  v <- decide_evsi(m, candidates = rates, sample_design = design,
                   utility = function(r, y) 300 * y - 1.2 * r,
                   state_key = "ymax", n_pre = 100L)
  expect_false(v@abstained)
  expect_true(v@value >= 0)
  expect_error(
    decide_evsi(m, candidates = rates, sample_design = design,
                utility = function(r, y) 300 * y - 1.2 * r,
                state_key = "not_a_column", n_pre = 20L),
    "no `params` column"
  )
})

test_that("a malformed sample design stops rather than being half-honoured", {
  set.seed(13L)
  m <- .gain_manifest(0.3, 1, n_draw = 500L)
  expect_error(
    decide_evsi(m, candidates = c(0, 1), sample_design = list(simulate = mean),
                utility = .act_or_not),
    "must supply"
  )
  expect_error(
    decide_evsi(m, candidates = c(0, 1),
                sample_design = list(simulate = 1, loglik = 2),
                utility = .act_or_not),
    "must both be functions"
  )
  bad_length <- list(
    simulate = function(state) stats::rnorm(1L, state, 1),
    loglik   = function(y, state) stats::dnorm(y, state, 1, log = TRUE)[1L]
  )
  expect_error(
    decide_evsi(m, candidates = c(0, 1), sample_design = bad_length,
                utility = .act_or_not, n_pre = 5L),
    "one per draw"
  )
})

test_that("a degenerate importance re-weighting is warned about, not hidden", {
  # A sample vastly more informative than the current posterior collapses the
  # weights onto a handful of draws; the estimate is then under-resolved and
  # must say so.
  set.seed(14L)
  m <- .gain_manifest(0.3, 1, n_draw = 300L)
  sharp <- list(
    simulate = function(state) stats::rnorm(1L, state, 0.001),
    loglik   = function(y, state) stats::dnorm(y, state, 0.001, log = TRUE)
  )
  expect_warning(
    decide_evsi(m, candidates = c(0, 1), sample_design = sharp,
                utility = .act_or_not, n_pre = 30L),
    "importance weights degenerated"
  )
})

test_that("a valuation prints its status, value and components", {
  v <- valuation(value = 12.4, type = "evpi",
                 components = list(evpi = 12.4, n_draws = 1000L),
                 grounding = grounding_grounded(),
                 method = "evpi_expected_utility")
  expect_output(print(v), "<valuation: evpi> priced")
  expect_output(print(v), "12.4")
  abst <- valuation(value = NA_real_, type = "evsi",
                    grounding = grounding_unverified(), abstained = TRUE,
                    abstain_reason = "input_ungrounded")
  expect_output(print(abst), "ABSTAINED \\(input_ungrounded\\)")
})

test_that("a valuation refuses to carry a value alongside an abstention", {
  expect_error(
    valuation(value = 3, type = "evpi", abstained = TRUE,
              abstain_reason = "input_ungrounded"),
    "must not carry a @value"
  )
})
