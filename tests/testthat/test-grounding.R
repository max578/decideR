test_that("canonical tokens are exactly the federation strings", {
  expect_identical(grounding_grounded(), "grounded")
  expect_identical(grounding_unverified(), "ungrounded")
})

test_that("combine_grounding is worst-case", {
  g <- grounding_grounded()
  u <- grounding_unverified()
  expect_identical(combine_grounding(c(g, g)), g)
  expect_identical(combine_grounding(c(g, u)), u)
  expect_identical(combine_grounding(c(u, u)), u)
  expect_identical(combine_grounding(u), u)
  # an empty input is treated as un-grounded, never as vacuously grounded
  expect_identical(combine_grounding(character(0L)), u)
})

test_that("a non-canonical synonym is rejected loudly (IOP)", {
  expect_error(combine_grounding("unverified"), "non-canonical")
  expect_error(combine_grounding(c("grounded", "not grounded")), "non-canonical")
})

test_that("the token of decideR 0.2.0 and earlier is still read as ungrounded", {
  expect_identical(combine_grounding("[unverified]"), "ungrounded")
  expect_identical(combine_grounding(c("grounded", "[unverified]")), "ungrounded")
  expect_false(is_grounded(decision(grounding = "[unverified]")))
  expect_identical(valuation(grounding = "[unverified]")@grounding, "[unverified]")
  expect_identical(decision()@grounding, "ungrounded")
})
