# CRRDC-guideline benefit-cost ratio (bcr_crrdc()).
#
# INDEPENDENT ORACLE. `.annuity_factor()` below is the closed-form finite
# geometric series for a constant year-indexed stream discounted from
# base_year (period t = 0, undiscounted) through period n - 1:
#
#   A(r, n) = sum_{k=0}^{n-1} (1 + r)^-k = (1 - (1 + r)^-n) * (1 + r) / r.
#
# It is coded independently of `bcr_crrdc()`'s own `.pv_at_year()` (which sums
# element-wise over the supplied years rather than applying a closed-form
# factor), so agreement between the two is a genuine cross-check of the
# arithmetic, not self-consistency of one code path against itself.
.annuity_factor <- function(r, n) {
  (1 - (1 + r)^-n) * (1 + r) / r
}

test_that("bcr_crrdc() reproduces the closed-form annuity PV -- parameterisation A", {
  # Constant streams, already-net counterfactual, full attribution, full
  # uptake: b = 1000, c = 400, n = 6 years from 2020, default rates
  # (central 5%, sensitivity 3%/7%).
  n <- 6L
  bens <- data.frame(year = 2020:2025, value = rep(1000, n))
  csts <- data.frame(year = 2020:2025, value = rep(400, n))
  up   <- data.frame(year = 2020:2025, uptake = rep(1, n))

  v <- bcr_crrdc(bens, csts, counterfactual = "already_net",
                 counterfactual_label = "no intervention baseline",
                 attribution = 1, adoption = up,
                 grounding = grounding_grounded())

  expect_s3_class(v, "decider_bcr")
  expect_false(v$abstained)
  expect_identical(v$base_year, 2020L)

  for (i in seq_len(nrow(v$rates))) {
    r <- v$rates$rate[i]
    fac <- .annuity_factor(r, n)
    expect_equal(v$rates$pv_benefits[i], 1000 * fac, tolerance = 1e-12)
    expect_equal(v$rates$pv_costs[i], 400 * fac, tolerance = 1e-12)
    expect_equal(v$rates$npv[i], (1000 - 400) * fac, tolerance = 1e-12)
    expect_equal(v$rates$bcr[i], 2.5, tolerance = 1e-12)
  } # ends i, over discount rates
})

test_that("bcr_crrdc() reproduces the closed-form annuity PV -- parameterisation B", {
  # A data.frame counterfactual (zero, so net = gross), partial attribution,
  # full uptake, custom rates: gross b = 500, attribution = 0.4 -> net
  # attributed b = 200, c = 1000, n = 10 years from 2015, central 6%,
  # sensitivity 2%/9%.
  n <- 10L
  bens <- data.frame(year = 2015:2024, value = rep(500, n))
  cf   <- data.frame(year = 2015:2024, value = rep(0, n))
  csts <- data.frame(year = 2015:2024, value = rep(1000, n))
  up   <- data.frame(year = 2015:2024, uptake = rep(1, n))

  v <- bcr_crrdc(bens, csts, counterfactual = cf, attribution = 0.4,
                 adoption = up, discount_central = 0.06,
                 discount_sensitivity = c(0.02, 0.09),
                 grounding = grounding_grounded())

  expect_false(v$abstained)
  expect_identical(v$base_year, 2015L)
  expect_identical(v$rates$rate, c(0.06, 0.02, 0.09))

  for (i in seq_len(nrow(v$rates))) {
    r <- v$rates$rate[i]
    fac <- .annuity_factor(r, n)
    expect_equal(v$rates$pv_benefits[i], 200 * fac, tolerance = 1e-12)
    expect_equal(v$rates$pv_costs[i], 1000 * fac, tolerance = 1e-12)
    expect_equal(v$rates$npv[i], (200 - 1000) * fac, tolerance = 1e-12)
    expect_equal(v$rates$bcr[i], 0.2, tolerance = 1e-12)
  } # ends i, over discount rates
})

test_that("bcr_crrdc() reports lower rates as higher PV for a future-loaded stream", {
  # A benefit stream that grows through the horizon, under a lagged adoption
  # ramp, is worth more in present-value terms at a lower discount rate:
  # the lower rate discounts the (larger) later-year benefits less harshly.
  n <- 10L
  bens <- data.frame(year = 2020:2029, value = seq(50, 950, length.out = n))
  csts <- data.frame(year = 2020:2029, value = rep(100, n))
  up   <- data.frame(year = 2020:2029, uptake = seq(0.2, 1, length.out = n))

  v <- bcr_crrdc(bens, csts, counterfactual = "already_net",
                 counterfactual_label = "no adoption of the new practice",
                 attribution = 0.8, adoption = up,
                 grounding = grounding_grounded())

  b_low <- v$rates$pv_benefits[v$rates$rate_label == "sensitivity_1"]
  b_mid <- v$rates$pv_benefits[v$rates$rate_label == "central"]
  b_high <- v$rates$pv_benefits[v$rates$rate_label == "sensitivity_2"]
  expect_gt(b_low, b_mid)
  expect_gt(b_mid, b_high)
})

test_that("bcr_crrdc() refuses each missing CRRDC requirement, naming it", {
  bens <- data.frame(year = 2020:2021, value = c(0, 210))
  csts <- data.frame(year = 2020:2021, value = c(100, 0))
  up   <- data.frame(year = 2020:2021, uptake = c(1, 1))

  expect_error(
    bcr_crrdc(bens, csts, attribution = 1, adoption = up),
    "`counterfactual` is required"
  )
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net",
              counterfactual_label = "baseline", adoption = up),
    "`attribution` is required"
  )
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net",
              counterfactual_label = "baseline", attribution = 1),
    "`adoption` is required"
  )
})

test_that("bcr_crrdc() requires a label for an already-net counterfactual", {
  bens <- data.frame(year = 2020:2021, value = c(0, 210))
  csts <- data.frame(year = 2020:2021, value = c(100, 0))
  up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net", attribution = 1,
              adoption = up),
    "counterfactual_label"
  )
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = 42, attribution = 1,
              adoption = up),
    "already_net"
  )
})

test_that("bcr_crrdc() validates the attribution share", {
  bens <- data.frame(year = 2020:2021, value = c(0, 210))
  csts <- data.frame(year = 2020:2021, value = c(100, 0))
  up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net",
              counterfactual_label = "baseline", attribution = 0,
              adoption = up),
    "\\(0, 1\\]"
  )
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net",
              counterfactual_label = "baseline", attribution = 1.2,
              adoption = up),
    "\\(0, 1\\]"
  )
})

test_that("bcr_crrdc() validates adoption coverage and uptake range", {
  bens <- data.frame(year = 2020:2022, value = c(0, 100, 100))
  csts <- data.frame(year = 2020:2022, value = c(100, 0, 0))

  # Adoption profile missing a benefit year.
  short_up <- data.frame(year = 2020:2021, uptake = c(0.5, 1))
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net",
              counterfactual_label = "baseline", attribution = 1,
              adoption = short_up),
    "does not cover benefit year"
  )

  # Uptake out of [0, 1].
  bad_up <- data.frame(year = 2020:2022, uptake = c(0.5, 1, 1.4))
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net",
              counterfactual_label = "baseline", attribution = 1,
              adoption = bad_up),
    "\\[0, 1\\]"
  )
})

test_that("bcr_crrdc() validates counterfactual data.frame coverage", {
  bens <- data.frame(year = 2020:2022, value = c(0, 100, 100))
  csts <- data.frame(year = 2020:2022, value = c(100, 0, 0))
  up   <- data.frame(year = 2020:2022, uptake = c(1, 1, 1))
  short_cf <- data.frame(year = 2020:2021, value = c(0, 0))
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = short_cf, attribution = 1,
              adoption = up),
    "does not cover benefit year"
  )
})

test_that("bcr_crrdc() validates the discount rates", {
  bens <- data.frame(year = 2020:2021, value = c(0, 210))
  csts <- data.frame(year = 2020:2021, value = c(100, 0))
  up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net",
              counterfactual_label = "baseline", attribution = 1,
              adoption = up, discount_central = -2),
    "greater than -1"
  )
  expect_error(
    bcr_crrdc(bens, csts, counterfactual = "already_net",
              counterfactual_label = "baseline", attribution = 1,
              adoption = up, discount_sensitivity = c(0.03, -1.5)),
    "greater than -1"
  )
})

test_that("an un-grounded input abstains, never a ratio", {
  bens <- data.frame(year = 2020:2021, value = c(0, 210))
  csts <- data.frame(year = 2020:2021, value = c(100, 0))
  up   <- data.frame(year = 2020:2021, uptake = c(1, 1))

  # No grounding supplied at all -- the safe default is un-grounded.
  v_default <- bcr_crrdc(bens, csts, counterfactual = "already_net",
                         counterfactual_label = "baseline", attribution = 1,
                         adoption = up)
  expect_true(v_default$abstained)
  expect_identical(v_default$abstain_reason, "input_ungrounded")
  expect_true(all(is.na(v_default$rates$bcr)))
  expect_true(any(grepl("_abstention$", class(v_default))))

  # One un-grounded token among several taints the combined token.
  v_mixed <- bcr_crrdc(bens, csts, counterfactual = "already_net",
                       counterfactual_label = "baseline", attribution = 1,
                       adoption = up,
                       grounding = c(grounding_grounded(),
                                    grounding_unverified()))
  expect_true(v_mixed$abstained)
  expect_identical(v_mixed$abstain_reason, "input_ungrounded")

  # All-grounded tokens combine to grounded and the ratio is priced.
  v_grounded <- bcr_crrdc(bens, csts, counterfactual = "already_net",
                          counterfactual_label = "baseline", attribution = 1,
                          adoption = up,
                          grounding = c(grounding_grounded(),
                                       grounding_grounded()))
  expect_false(v_grounded$abstained)
  expect_false(any(is.na(v_grounded$rates$bcr)))
})

test_that("an all-zero cost stream abstains rather than dividing by zero", {
  bens <- data.frame(year = 2020:2021, value = c(0, 210))
  csts <- data.frame(year = 2020:2021, value = c(0, 0))
  up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
  v <- bcr_crrdc(bens, csts, counterfactual = "already_net",
                 counterfactual_label = "baseline", attribution = 1,
                 adoption = up, grounding = grounding_grounded())
  expect_true(v$abstained)
  expect_identical(v$abstain_reason, "undefined_ratio")
  expect_true(all(is.na(v$rates$bcr)))
})

test_that("print.decider_bcr() and as.data.frame.decider_bcr() work", {
  bens <- data.frame(year = 2020:2021, value = c(0, 210))
  csts <- data.frame(year = 2020:2021, value = c(100, 0))
  up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
  v <- bcr_crrdc(bens, csts, counterfactual = "already_net",
                 counterfactual_label = "no intervention", attribution = 1,
                 adoption = up, grounding = grounding_grounded())

  expect_output(print(v), "decider_bcr")
  expect_output(print(v), "no intervention")
  expect_output(print(v), "BCR @ central")
  expect_output(print(v), "BCR @ sensitivity_1")
  expect_output(print(v), "BCR @ sensitivity_2")

  df <- as.data.frame(v)
  expect_identical(df, v$rates)
  expect_s3_class(df, "data.frame")
  expect_identical(nrow(df), 3L)
  expect_identical(names(df),
                   c("rate_label", "rate", "pv_benefits", "pv_costs", "npv",
                     "bcr"))

  abstained <- bcr_crrdc(bens, csts, counterfactual = "already_net",
                        counterfactual_label = "no intervention",
                        attribution = 1, adoption = up)
  expect_output(print(abstained), "ABSTAINED")
  expect_output(print(abstained), "\\[unverified\\]")
})
