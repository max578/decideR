test_that("decide picks the expected-utility maximiser when grounded", {
  set.seed(1L)
  theta <- rnorm(4000L, mean = 1.5, sd = 0.3)
  u <- function(a, theta) -(a - theta)^2          # quadratic loss
  d <- decide(theta, u, candidates = seq(0, 3, by = 0.5),
              grounding = grounding_grounded(), safe_action = 0)
  expect_false(d@abstained)
  expect_equal(d@action, 1.5, tolerance = 0.5)
  expect_true(is_grounded(d))
  expect_false(is.na(d@expected_utility))
})

test_that("ungrounded input abstains to the safe action (IOP firewall)", {
  set.seed(2L)
  theta <- rnorm(2000L, 1.5, 0.3)
  u <- function(a, theta) -(a - theta)^2
  d <- decide(theta, u, candidates = seq(0, 3, by = 0.5),
              grounding = grounding_unverified(), safe_action = 0,
              safe_label = "status quo")
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "input_ungrounded")
  expect_identical(d@action, 0)
  expect_false(is_grounded(d))
  expect_match(d@action_label, "\\[unverified\\]")
})

test_that("one unverified input among several taints the decision", {
  set.seed(6L)
  theta <- rnorm(2000L, 1.5, 0.3)
  u <- function(a, theta) -(a - theta)^2
  d <- decide(theta, u, candidates = seq(0, 3, by = 0.5),
              grounding = c(grounding_grounded(), grounding_unverified()),
              safe_action = 0)
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "input_ungrounded")
})

test_that("no feasible action abstains", {
  set.seed(3L)
  theta <- rnorm(1000L, 1, 0.2)
  u <- function(a, theta) -(a - theta)^2
  d <- decide(theta, u, candidates = c(0, 1, 2),
              constraint = function(a) FALSE,
              grounding = grounding_grounded(), safe_action = -1)
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "no_feasible_action")
})

test_that("a move not clearly better than the status quo abstains", {
  set.seed(4L)
  theta <- rnorm(5000L, mean = 0.3, sd = 3)       # weak positive signal
  u <- function(a, theta) a * theta               # acting pays off iff theta>0
  d <- decide(theta, u, candidates = c(0, 1),
              grounding = grounding_grounded(), safe_action = 0,
              decisive_prob = 0.6)
  expect_true(d@abstained)                         # P(theta>0) ~ 0.54 < 0.6
  expect_identical(d@abstain_reason, "insufficient_evidence")
  expect_identical(d@action, 0)                    # falls back to status quo
})

test_that("low effective sample size abstains", {
  set.seed(5L)
  theta <- rnorm(500L, 1.5, 0.3)
  u <- function(a, theta) -(a - theta)^2
  d <- decide(theta, u, candidates = seq(0, 3, by = 0.5),
              grounding = grounding_grounded(), safe_action = 0,
              ess = 20, min_ess = 100)
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "low_ess")
})

test_that("the candidate ledger records every action's expected utility", {
  set.seed(7L)
  theta <- rnorm(1500L, 1.5, 0.3)
  u <- function(a, theta) -(a - theta)^2
  rates <- seq(0, 3, by = 0.5)
  d <- decide(theta, u, candidates = rates, grounding = grounding_grounded(),
              safe_action = 0)
  expect_s3_class(d@candidates, "data.frame")
  expect_identical(nrow(d@candidates), length(rates))
  expect_true(all(d@candidates$feasible))
})
