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

test_that("low_ess is opt-in: a default call with three draws still decides (D-05)", {
  # `min_ess` defaults to NULL, so the ESS floor is off unless the caller
  # supplies one -- documented behaviour, pinned here so a change to the
  # default is a deliberate, test-visible decision.
  set.seed(9L)
  theta <- rnorm(3L, mean = 1.5, sd = 0.01)
  u <- function(a, theta) -(a - theta)^2
  d <- decide(theta, u, candidates = seq(0, 3, by = 0.5),
              grounding = grounding_grounded(), safe_action = 0)
  expect_false(d@abstained)
  expect_true(is.na(d@abstain_reason))
})

test_that("degenerate (all-NA/NaN) expected utility abstains rather than erroring (D-04)", {
  d <- decide(rnorm(100L), function(a, theta) rep(NaN, length(theta)),
              candidates = c(0, 1), grounding = grounding_grounded(),
              safe_action = 0)
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "degenerate_utility")
  expect_identical(d@action, 0)
})

test_that("the decisiveness gate fires for a categorical candidate set (D-01)", {
  # A weak, near-zero signal should abstain regardless of whether `safe_action`
  # happens to sit on the numeric candidate grid: `candidates = c(1, 2)` has no
  # slot for `safe_action = 0`, which used to disable the gate entirely
  # (`.match_candidate()` returns NA for an off-grid numeric action just as it
  # does for a categorical/list action set).
  set.seed(1L)
  theta <- rnorm(4000L, mean = 0.3, sd = 3)          # P(theta > 0) ~ 0.54
  u <- function(a, theta) a * theta
  d_on_grid  <- decide(theta, u, candidates = c(0, 1), safe_action = 0,
                       grounding = grounding_grounded())
  d_off_grid <- decide(theta, u, candidates = c(1, 2), safe_action = 0,
                       grounding = grounding_grounded())
  expect_true(d_on_grid@abstained)
  expect_true(d_off_grid@abstained)                  # previously FALSE (D-01)
  expect_identical(d_off_grid@abstain_reason, "insufficient_evidence")

  # Categorical (list) candidates route through the identical fallback and must
  # still decide confidently when the evidence is overwhelming.
  set.seed(11L)
  theta2 <- rnorm(4000L, mean = 5, sd = 0.5)         # P(theta2 > 0) ~ 1
  d_categorical <- decide(theta2, u, candidates = list(0, 1), safe_action = 0,
                          grounding = grounding_grounded())
  expect_false(d_categorical@abstained)
})

test_that("an abstained decision carries the ORCHESTRA refusal-contract class", {
  # The federation's leader-side `is_orchestra_decline()` predicate
  # (ORCHESTRA_dev/integration/refusal_contract.R) recognises a decline by a
  # `class()` suffix convention (`_refusal` / `_abstention`), independent of
  # any particular member's namespace. A decided (non-abstained) `decision`
  # must NOT carry the marker.
  set.seed(2L)
  theta <- rnorm(2000L, 1.5, 0.3)
  u <- function(a, theta) -(a - theta)^2
  d_abstained <- decide(theta, u, candidates = seq(0, 3, by = 0.5),
                       grounding = grounding_unverified(), safe_action = 0)
  d_decided <- decide(theta, u, candidates = seq(0, 3, by = 0.5),
                      grounding = grounding_grounded(), safe_action = 0)
  expect_true(d_abstained@abstained)
  expect_true(any(grepl("_(refusal|abstention)$", class(d_abstained))))
  expect_false(d_decided@abstained)
  expect_false(any(grepl("_(refusal|abstention)$", class(d_decided))))
  # `@` property access and S7 dispatch survive the extra class tag.
  expect_identical(d_abstained@abstain_reason, "input_ungrounded")
  expect_output(print(d_abstained), "ABSTAINED")
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
