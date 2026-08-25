# Benefit-cost ratio.
#
# INDEPENDENT ORACLE. The expected values are hand-computed from the discounted
# cash-flow identity, stated in full here so a reader can check the arithmetic
# without running anything:
#
#   PV(x) = sum_{t=0}^{H-1} x_t / (1 + r)^t,  NPV = PV(B) - PV(C),
#   BCR   = PV(B) / PV(C).
#
# Worked example A (the two-period case): r = 0.05, costs = (100, 0),
# benefits = (0, 210). Period t = 0 is the present and is NOT discounted, so
#   PV(C) = 100 / 1.05^0 + 0 / 1.05^1 = 100,
#   PV(B) =   0 / 1.05^0 + 210 / 1.05^1 = 210 / 1.05 = 200,
#   NPV   = 200 - 100 = 100,  BCR = 200 / 100 = 2.
#
# Worked example B (cost in both periods): r = 0.05, costs = (50, 50),
# benefits = (0, 105).
#   PV(C) = 50 + 50 / 1.05 = 50 + 47.619047619047620 = 97.619047619047620,
#   PV(B) = 105 / 1.05 = 100,
#   NPV   = 2.380952380952380,
#   BCR   = 100 / 97.619047619047620 = 105 / 102.5 = 1.024390243902439.
#
# Example B is deliberately a case where the discounting convention MATTERS:
# under an end-of-first-period convention (every flow discounted once) the
# ratio is unchanged but both present values shift by a factor 1.05, which the
# present-value assertions below detect.

test_that("decide_bcr() reproduces the hand-computed two-period example", {
  v <- decide_bcr(benefits = c(0, 210), costs = c(100, 0),
                  discount_rate = 0.05, grounding = grounding_grounded())

  expect_s7_class(v, valuation)
  expect_identical(v@type, "bcr")
  expect_false(v@abstained)
  expect_equal(v@components$present_value_costs, 100, tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(v@components$present_value_benefits, 200, tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(v@components$npv, 100, tolerance = 1e-12, ignore_attr = TRUE)
  expect_equal(v@value, 2, tolerance = 1e-12, ignore_attr = TRUE)
  expect_identical(v@components$horizon, 2L)
  expect_equal(v@components$discount_factors, c(1, 1 / 1.05),
               tolerance = 1e-12, ignore_attr = TRUE)
})

test_that("decide_bcr() reproduces the hand-computed two-sided example", {
  v <- decide_bcr(benefits = c(0, 105), costs = c(50, 50),
                  discount_rate = 0.05, grounding = grounding_grounded())
  expect_equal(v@components$present_value_costs, 97.619047619047620,
               tolerance = 1e-10, ignore_attr = TRUE)
  expect_equal(v@components$present_value_benefits, 100, tolerance = 1e-10,
               ignore_attr = TRUE)
  expect_equal(v@components$npv, 2.380952380952380, tolerance = 1e-10,
               ignore_attr = TRUE)
  expect_equal(v@value, 1.024390243902439, tolerance = 1e-10,
               ignore_attr = TRUE)
})

test_that("period zero is the present and is not discounted", {
  # A one-period stream must come back undiscounted; discounting it once would
  # return 210 / 1.05 = 200 instead.
  v <- decide_bcr(benefits = c(210), costs = c(100), discount_rate = 0.05,
                  grounding = grounding_grounded())
  expect_equal(v@components$present_value_benefits, 210, tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(v@value, 2.1, tolerance = 1e-12, ignore_attr = TRUE)
})

test_that("a zero discount rate is the undiscounted sum", {
  v <- decide_bcr(benefits = c(0, 100, 100), costs = c(150, 0, 0),
                  discount_rate = 0, grounding = grounding_grounded())
  expect_equal(v@components$present_value_benefits, 200, tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(v@value, 200 / 150, tolerance = 1e-12, ignore_attr = TRUE)
})

test_that("a longer horizon zero-pads, and an over-long stream stops", {
  v <- decide_bcr(benefits = c(0, 210), costs = c(100, 0),
                  discount_rate = 0.05, horizon = 5L,
                  grounding = grounding_grounded())
  expect_identical(v@components$horizon, 5L)
  expect_equal(v@value, 2, tolerance = 1e-12, ignore_attr = TRUE)
  expect_length(v@components$benefit_stream, 5L)
  expect_error(
    decide_bcr(benefits = c(0, 210, 10), costs = c(100, 0),
               discount_rate = 0.05, horizon = 2L,
               grounding = grounding_grounded()),
    "lengthen the horizon"
  )
})

test_that("an un-grounded benefit stream abstains, never a ratio", {
  v <- decide_bcr(benefits = c(0, 210), costs = c(100, 0),
                  discount_rate = 0.05)
  expect_true(v@abstained)
  expect_identical(v@abstain_reason, "input_ungrounded")
  expect_true(is.na(v@value))
  expect_true(any(grepl("_abstention$", class(v))))
})

test_that("a non-positive discounted cost base is an undefined ratio", {
  v <- decide_bcr(benefits = c(0, 210), costs = c(0, 0),
                  discount_rate = 0.05, grounding = grounding_grounded())
  expect_true(v@abstained)
  expect_identical(v@abstain_reason, "undefined_ratio")
  expect_true(is.na(v@value))
})

test_that("decide_bcr() reads the stream and grounding from a manifest", {
  bcr_manifest <- S7::new_class(
    "bcr_manifest",
    properties = list(
      outputs         = S7::new_property(S7::class_any, default = NULL),
      metadata        = S7::new_property(S7::class_list, default = list()),
      summary         = S7::new_property(S7::class_any, default = NULL),
      run_id          = S7::new_property(S7::class_character,
                                         default = "bcr-run"),
      emitter_package = S7::new_property(S7::class_character,
                                         default = "grainPlan")
    )
  )
  set.seed(2026L)
  n <- 4000L
  # Posterior benefit draws for two periods: nothing now, 210 on average next
  # period. The point ratio is the ratio of the MEAN stream, which is worked
  # example A above up to Monte Carlo error in the mean.
  draws <- cbind(rep(0, n), stats::rnorm(n, mean = 210, sd = 30))
  m <- bcr_manifest(
    outputs  = draws,
    metadata = list(grounding = grounding_grounded())
  )
  v <- decide_bcr(costs = c(100, 0), discount_rate = 0.05, manifest = m)

  expect_false(v@abstained)
  expect_identical(v@inputs$emitter_package, "grainPlan")
  expect_equal(v@value, mean(draws[, 2L]) / 1.05 / 100, tolerance = 1e-10,
               ignore_attr = TRUE)
  expect_equal(v@value, 2, tolerance = 0.02, ignore_attr = TRUE)
  expect_identical(v@components$n_draws, n)
  expect_length(v@components$bcr_quantiles, 3L)
  expect_lt(v@components$bcr_quantiles[[1L]], v@components$bcr_quantiles[[3L]])

  ungrounded <- bcr_manifest(
    outputs  = draws,
    metadata = list(grounding = grounding_unverified())
  )
  vu <- decide_bcr(costs = c(100, 0), discount_rate = 0.05,
                   manifest = ungrounded)
  expect_true(vu@abstained)
  expect_identical(vu@abstain_reason, "input_ungrounded")
})

test_that("decide_bcr() validates its arguments", {
  expect_error(
    decide_bcr(benefits = c(0, 1), costs = c(1, 0), discount_rate = -2),
    "greater than -1"
  )
  expect_error(
    decide_bcr(costs = c(1, 0), discount_rate = 0.05),
    "supply `benefits`"
  )
  expect_error(
    decide_bcr(benefits = c(0, NA), costs = c(1, 0), discount_rate = 0.05,
               grounding = grounding_grounded()),
    "no NA"
  )
})
