# The grade-band loss is the threshold-economics primitive: a step value
# schedule whose payoff jumps at quality breakpoints. These tests pin the band
# semantics (the on-break convention is load-bearing for a delivery standard)
# and the worked grain example end to end through decide().

test_that("grade_band_value places outcomes in the right band (on-break clears up)", {
  v <- grade_band_value(breaks = c(10.5, 11.5, 13), values = c(300, 330, 360, 400))
  # below first break, on a break (clears up), interior, at last break, above
  expect_identical(v(c(9.0, 10.5, 11.0, 11.5, 13.0, 14.0)),
                   c(300, 330, 330, 360, 400, 400))
})

test_that("grade_band_value honours the right-closed convention", {
  v <- grade_band_value(c(10.5, 11.5, 13), c(300, 330, 360, 400), right = TRUE)
  # on a break the outcome stays in the lower band
  expect_identical(v(c(10.5, 11.5, 13.0)), c(300, 330, 360))
})

test_that("print.grade_band_value dispatches to the band table (D-03)", {
  v <- grade_band_value(c(10.5, 11.5), c(300, 330, 360))
  out <- capture.output(print(v))
  expect_match(out[1L], "<grade_band_value> 3 bands", fixed = TRUE)
  expect_true(any(grepl("330", out)))
})

test_that("grade_band_value propagates NA and carries the schedule", {
  v <- grade_band_value(c(11.5), c(300, 360))
  expect_identical(v(c(11.0, NA, 12.0)), c(300, NA, 360))
  expect_identical(attr(v, "breaks"), 11.5)
  expect_identical(attr(v, "values"), c(300, 360))
  expect_s3_class(v, "grade_band_value")
})

test_that("grade_band_value validates breaks and values", {
  expect_error(grade_band_value(c(11.5, 10.5), c(1, 2, 3)), "strictly increasing")
  expect_error(grade_band_value(c(10, 11), c(1, 2)), "one more element")
  expect_error(grade_band_value(numeric(0L), 1), "non-empty")
  expect_error(grade_band_value(c(10, NA), c(1, 2, 3)), "no NA")
})

test_that("grade_band_utility builds a decide()-ready utility (additive default)", {
  v <- grade_band_value(c(11.5), c(300, 360))
  u <- grade_band_utility(v)                          # quality = theta + action
  # action 1 shifts a draw of 10.7 to 11.7, clearing the band
  expect_equal(u(1, 10.7), 360)
  expect_equal(u(0, 10.7), 300)
})

test_that("grade_band_utility applies a numeric per-unit cost", {
  v <- grade_band_value(c(11.5), c(300, 360))
  u <- grade_band_utility(v, cost = 5)
  expect_equal(u(2, 12.0), 360 - 10)                  # cleared band, minus 2*5
})

test_that("worked grain example: the band premium pulls protein over the threshold", {
  # An APW-style protein payoff (per tonne): feed 300, milling 360, premium 420.
  # Nitrogen lifts protein with diminishing returns; the per-ha value folds in a
  # 5.5 t/ha yield, and N costs 1.3 per unit rate.
  v <- grade_band_value(breaks = c(11.5, 13.0), values = c(300, 360, 420))
  qshift <- function(rate, base_protein) base_protein + 3.0 * (1 - exp(-rate / 50))
  yield  <- 5.5
  u <- function(rate, base_protein) {
    yield * v(qshift(rate, base_protein)) - 1.3 * rate
  }
  set.seed(1L)
  base_protein <- stats::rnorm(4000L, mean = 10.6, sd = 0.5)
  rates <- seq(0, 150, by = 15)
  d <- decide(base_protein, u, candidates = rates,
              grounding = grounding_grounded(), safe_action = 0)
  expect_false(d@abstained)
  # the optimum is interior: enough N to clear the milling band reliably, not so
  # much that the N cost outruns the premium
  expect_true(d@action > 0 && d@action < 150)
  prot_best <- qshift(d@action, base_protein)
  expect_gt(mean(prot_best >= 11.5), 0.9)             # milling band reliably cleared
})

test_that("an un-grounded grade-band decision abstains (IOP firewall)", {
  v <- grade_band_value(c(11.5, 13.0), c(300, 360, 420))
  u <- grade_band_utility(v, quality_shift = function(r, p) p + 0.05 * r,
                          cost = 1.3)
  set.seed(2L)
  protein <- stats::rnorm(2000L, mean = 11.0, sd = 0.5)
  d <- decide(protein, u, candidates = seq(0, 150, by = 25),
              grounding = grounding_unverified(), safe_action = 0)
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "input_ungrounded")
})
