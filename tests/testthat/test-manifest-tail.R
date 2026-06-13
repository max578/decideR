# The manifest-native tail reads an upstream manifest by its public contract and
# closes the pipeline into a decision. decideR does not depend on the contract
# package, so these tests build a minimal S7 stand-in carrying the contract's
# `outputs` / `metadata` / `summary` properties -- exactly the duck-typing the
# tail relies on in production.

# A tiny S7 class mimicking the orchestra_manifest contract surface the tail
# reads. Built here (not imported) so the test exercises the duck-typed path.
.fake_manifest <- S7::new_class(
  "fake_manifest",
  properties = list(
    outputs         = S7::new_property(S7::class_any, default = NULL),
    metadata        = S7::new_property(S7::class_list, default = list()),
    summary         = S7::new_property(S7::class_any, default = NULL),
    run_id          = S7::new_property(S7::class_character, default = "test-run"),
    emitter_package = S7::new_property(S7::class_character, default = "PESTO")
  )
)

.yield_manifest <- function(grounding, in_outputs = FALSE, seed = 1L) {
  set.seed(seed)
  rates <- seq(0, 200, by = 25)
  ymax  <- stats::rnorm(1500L, 5.5, 0.3)
  yld   <- vapply(
    rates,
    function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)) + stats::rnorm(1500L, 0, 0.1),
    numeric(1500L)
  )
  if (in_outputs) {
    .fake_manifest(outputs = yld,
                   metadata = list(grounding = grounding))
  } else {
    .fake_manifest(metadata = list(yield_draws = yld, grounding = grounding))
  }
}

test_that("decide_rate_from_manifest closes the grounded pipeline into a rate", {
  m <- .yield_manifest(grounding_grounded())
  d <- decide_rate_from_manifest(m, rates = seq(0, 200, by = 25),
                                 price_grain = 300, price_input = 1.2)
  expect_s7_class(d, decision)
  expect_false(d@abstained)
  expect_true(d@action > 0 && d@action < 200)        # interior optimum
  expect_identical(d@method, "expected_profit")
  expect_true(is_grounded(d))
  # provenance carried from the manifest into the decision's inputs
  expect_identical(d@inputs$emitter_package, "PESTO")
  expect_identical(d@inputs$manifest_run_id, "test-run")
})

test_that("an un-grounded manifest forces the status quo (IOP firewall at the tail)", {
  m <- .yield_manifest(grounding_unverified())
  d <- decide_rate_from_manifest(m, rates = seq(0, 200, by = 25),
                                 price_grain = 300, price_input = 1.2,
                                 safe_rate = 0)
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "input_ungrounded")
  expect_identical(d@action, 0)
  expect_false(is_grounded(d))
})

test_that("the tail reads draws from the contract `outputs` slot too", {
  m <- .yield_manifest(grounding_grounded(), in_outputs = TRUE)
  d <- decide_rate_from_manifest(m, rates = seq(0, 200, by = 25),
                                 price_grain = 300, price_input = 1.2)
  expect_false(d@abstained)
  expect_true(d@action > 0 && d@action < 200)
})

test_that("decide_from_manifest accepts a caller-supplied utility", {
  m <- .yield_manifest(grounding_grounded())
  rates <- seq(0, 200, by = 25)
  d <- decide_from_manifest(m, candidates = rates,
                            utility = function(r, y) 300 * y - 1.2 * r,
                            safe_action = 0)
  expect_false(d@abstained)
  expect_true(d@action > 0 && d@action < 200)
})

test_that("decide_from_manifest treats columns as utilities when utility is NULL", {
  # a manifest whose columns are already per-candidate utilities: column k has a
  # higher mean, so the engine must select the last candidate.
  set.seed(2L)
  util_cols <- vapply(1:4, function(k) stats::rnorm(1000L, mean = k, sd = 0.1),
                      numeric(1000L))
  m <- .fake_manifest(outputs = util_cols,
                      metadata = list(grounding = grounding_grounded()))
  d <- decide_from_manifest(m, candidates = c(10, 20, 30, 40), utility = NULL,
                            safe_action = 10)
  expect_false(d@abstained)
  expect_identical(d@action, 40)
})

test_that("a manifest grounding can be overridden by the caller", {
  m <- .yield_manifest(grounding_unverified())
  d <- decide_rate_from_manifest(m, rates = seq(0, 200, by = 25),
                                 price_grain = 300, price_input = 1.2,
                                 grounding = grounding_grounded())
  expect_false(d@abstained)               # override lifts the firewall
  expect_true(is_grounded(d))
})

test_that("the tail errors on a manifest with no draws and on a length mismatch", {
  empty <- .fake_manifest(metadata = list(grounding = grounding_grounded()))
  expect_error(decide_rate_from_manifest(empty, rates = c(0, 50),
                                         price_grain = 300, price_input = 1.2),
               "no predictive draws")
  m <- .yield_manifest(grounding_grounded())
  expect_error(decide_rate_from_manifest(m, rates = c(0, 50),
                                         price_grain = 300, price_input = 1.2),
               "columns but")
})

test_that("a manifest with no grounding token defaults to un-grounded (honest IOP)", {
  m <- .fake_manifest(
    outputs = matrix(stats::rnorm(300L), nrow = 100L, ncol = 3L),
    metadata = list()                                  # no grounding recorded
  )
  d <- decide_from_manifest(m, candidates = c(1, 2, 3), utility = NULL)
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "input_ungrounded")
})
