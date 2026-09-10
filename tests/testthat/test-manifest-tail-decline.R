# test-manifest-tail-decline.R -- the tail declines typed, it does not crash.
#
# A consensus manifest that reached no quorum carries no draws on purpose. The
# tail used to meet that with a bare `stop()`, so `is_orchestra_decline()`
# returned FALSE and the chain could not tell a producer's honest abstention
# from a broken consumer.

.mini_manifest <- function(outputs = NULL, metadata = list()) {
  cls <- S7::new_class(
    "mini_manifest",
    properties = list(
      outputs         = S7::new_property(S7::class_any, default = NULL),
      metadata        = S7::new_property(S7::class_list, default = list()),
      summary         = S7::new_property(S7::class_any, default = NULL),
      run_id          = S7::new_property(S7::class_character, default = ""),
      emitter_package = S7::new_property(S7::class_character, default = "")
    )
  )
  cls(outputs = outputs, metadata = metadata)
}

test_that("a manifest carrying no draws declines typed, not bare", {
  m <- .mini_manifest()
  err <- tryCatch(
    decide_from_manifest(m, candidates = c("a", "b")),
    condition = function(e) e
  )
  expect_s3_class(err, "decideR_abstention")
  expect_s3_class(err, "orchestra_refusal")
  expect_true(orchestraManifest::is_orchestra_decline(err))
  expect_identical(err$reason, "no_draws")
})

test_that("a manifest whose payload is not numeric declines typed", {
  m <- .mini_manifest(outputs = data.frame(lens = "hub", weight = "high"))
  err <- tryCatch(
    decide_from_manifest(m, candidates = c("a", "b")),
    condition = function(e) e
  )
  expect_s3_class(err, "decideR_abstention")
  expect_true(orchestraManifest::is_orchestra_decline(err))
  expect_identical(err$reason, "unreadable_draws")
})

test_that("a caller-argument error is still an error, not a decline", {
  # candidates is the caller's argument, not the producer's payload: a mistake
  # here is a programming error and must not be dressed as an abstention.
  m <- .mini_manifest(outputs = matrix(rnorm(20L), ncol = 2L))
  err <- tryCatch(
    decide_from_manifest(m, candidates = character(0L)),
    condition = function(e) e
  )
  expect_s3_class(err, "error")
  expect_false(orchestraManifest::is_orchestra_decline(err))
})

test_that("a readable but ungrounded payload abstains, it does not price", {
  # Not a defect: an ungrounded input forces the safe action. Recorded here
  # because it is easy to mistake for one -- the decision is returned, typed
  # and abstained, rather than raised.
  set.seed(1L)
  m <- .mini_manifest(outputs = cbind(a = rnorm(200L, 10), b = rnorm(200L, 12)))
  d <- decide_from_manifest(m, candidates = c("a", "b"))
  expect_true(d@abstained)
  expect_identical(d@abstain_reason, "input_ungrounded")
  expect_s3_class(d, "decideR_abstention")
})

test_that("a grounded payload prices normally", {
  set.seed(1L)
  m <- .mini_manifest(
    outputs  = cbind(a = rnorm(200L, 10), b = rnorm(200L, 12)),
    metadata = list(grounding = grounding_grounded())
  )
  d <- decide_from_manifest(m, candidates = c("a", "b"))
  expect_false(d@abstained)
  expect_identical(d@action, "b")
})
