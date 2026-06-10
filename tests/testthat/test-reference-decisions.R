# The two reference decisions exercise the SAME core from two domains -- the
# concrete proof of the shared-keystone premise.

test_that("decide_input_rate picks a profitable interior rate when grounded", {
  set.seed(1L)
  rates <- seq(0, 200, by = 25)
  # correlated draws: one posterior draw of the response curve evaluated at all
  # rates (the realistic shape a response-curve posterior emits), plus small iid
  # measurement noise.
  n <- 2000L
  ymax <- rnorm(n, mean = 5.5, sd = 0.3)
  yield_draws <- vapply(
    rates,
    function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)) + rnorm(n, 0, 0.1),
    numeric(n)
  )
  d <- decide_input_rate(yield_draws, rates, price_grain = 300,
                         price_input = 1.2, grounding = grounding_grounded())
  expect_false(d@abstained)
  expect_true(d@action > 0 && d@action < 200)      # interior optimum
  expect_identical(d@method, "expected_profit")
})

test_that("decide_input_rate abstains to the status quo on ungrounded yield", {
  set.seed(2L)
  rates <- seq(0, 200, by = 25)
  yield_draws <- vapply(rates, function(r) rnorm(1000L, 3 + r / 100, 0.25),
                        numeric(1000L))
  d <- decide_input_rate(yield_draws, rates, price_grain = 300,
                         price_input = 1.2, grounding = grounding_unverified(),
                         safe_rate = 0)
  expect_true(d@abstained)
  expect_identical(d@action, 0)
  expect_identical(d@abstain_reason, "input_ungrounded")
})

test_that("decide_position_size stakes on an edge and respects the drawdown cap", {
  set.seed(3L)
  r <- rnorm(5000L, mean = 0.02, sd = 0.03)        # clear positive edge
  d <- decide_position_size(r, capital = 1000, max_drawdown = 0.15,
                            grounding = grounding_grounded())
  expect_false(d@abstained)
  expect_true(d@action > 0)
  expect_equal(d@metadata$position, d@action * 1000)
  # the chosen fraction's 5% return quantile is within the drawdown cap
  q <- stats::quantile(d@action * r, probs = 0.05, names = FALSE)
  expect_true(q >= -0.15 - 1e-8)
})

test_that("decide_position_size goes flat when there is no edge", {
  set.seed(4L)
  r <- rnorm(5000L, mean = 0, sd = 0.03)           # zero edge
  d <- decide_position_size(r, capital = 1000, max_drawdown = 0.15,
                            grounding = grounding_grounded())
  expect_equal(d@action, 0, tolerance = 1e-8)      # flat, either decided or abstained
})

test_that("decide_position_size goes flat on ungrounded returns (capital firewall)", {
  set.seed(5L)
  r <- rnorm(3000L, 0.02, 0.03)
  d <- decide_position_size(r, capital = 1000, max_drawdown = 0.15,
                            grounding = grounding_unverified())
  expect_true(d@abstained)
  expect_identical(d@action, 0)
  expect_identical(d@abstain_reason, "input_ungrounded")
  expect_identical(d@metadata$position, 0)
})

test_that("a tighter drawdown cap yields a smaller or equal position", {
  set.seed(8L)
  r <- rnorm(5000L, mean = 0.02, sd = 0.05)        # edge with fatter risk
  loose <- decide_position_size(r, capital = 1000, max_drawdown = 0.30,
                                grounding = grounding_grounded())
  tight <- decide_position_size(r, capital = 1000, max_drawdown = 0.05,
                                grounding = grounding_grounded())
  expect_true(tight@action <= loose@action + 1e-8)
})
