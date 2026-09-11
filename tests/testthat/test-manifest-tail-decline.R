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

# --- guards added 2026-09-11 after a cross-member probe -----------------------
#
# A gpfield spatial-prediction manifest carries `outputs` whose columns are
# x, y, z, mean, sd and n_support -- coordinates and summaries, not draws. With
# six candidates the column count matched, so the tail priced a coordinate as an
# agronomic action and returned a confident number. Nothing in decideR's own
# suite could see it, because every fixture here is shaped correctly by
# construction.

.typed_manifest <- function(outputs = NULL, target = NA_character_) {
  cls <- S7::new_class(
    "typed_manifest",
    properties = list(
      outputs            = S7::new_property(S7::class_any, default = NULL),
      metadata           = S7::new_property(S7::class_list, default = list()),
      summary            = S7::new_property(S7::class_any, default = NULL),
      run_id             = S7::new_property(S7::class_character, default = ""),
      emitter_package    = S7::new_property(S7::class_character, default = ""),
      inferential_target = S7::new_property(S7::class_character,
                                            default = NA_character_)
    )
  )
  cls(outputs = outputs, inferential_target = target)
}

test_that("outputs whose column names are not the candidate labels decline", {
  m <- .typed_manifest(
    outputs = data.frame(x = 1:3, y = 1:3, z = 1:3,
                         mean = 1:3, sd = 1:3, n_support = 1:3),
    target = "predictions"
  )
  err <- tryCatch(
    decide_from_manifest(m, candidates = c(0, 25, 50, 75, 100, 125)),
    condition = function(e) e
  )
  expect_s3_class(err, "decideR_abstention")
  expect_true(orchestraManifest::is_orchestra_decline(err))
  expect_identical(err$reason, "outputs_not_action_indexed")
})

test_that("action-indexed outputs still price without a utility", {
  m <- .typed_manifest(
    outputs = data.frame(`0` = c(1, 2), `50` = c(3, 4), check.names = FALSE),
    target = "predictions"
  )
  d <- decide_from_manifest(m, candidates = c(0, 50))
  expect_s7_class(d, decision)
})

test_that("a structure manifest is declined by target, not by shape", {
  m <- .typed_manifest(
    outputs = matrix(c(0, 0, 1, 0), 2, 2),
    target = "structure"
  )
  err <- tryCatch(
    decide_from_manifest(m, candidates = c("a", "b")),
    condition = function(e) e
  )
  expect_s3_class(err, "decideR_abstention")
  expect_identical(err$reason, "target_not_priceable")
})

test_that("a candidate/column shape mismatch declines typed, not bare", {
  m <- .typed_manifest(outputs = matrix(1:6, nrow = 2), target = "predictions")
  err <- tryCatch(
    decide_from_manifest(m, candidates = c("a", "b")),
    condition = function(e) e
  )
  expect_s3_class(err, "decideR_abstention")
  expect_identical(err$reason, "candidate_shape_mismatch")
})
