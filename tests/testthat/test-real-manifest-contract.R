# D-08 (Independent Oracle Principle): every OTHER manifest test in this
# package consumes a stand-in class decideR authored itself (`.fake_manifest`
# above, the vignette's `vignette_manifest`). That is the exact failure mode
# the Independent Oracle Principle names -- the conformance oracle and the
# code under test share an author. This file drives the manifest tail through
# a REAL `orchestra_manifest` S7 object built from the ORCHESTRA workspace's
# own reference contract (`integration/orchestra_manifest.R`), hash-verified
# before consumption, not a decideR-authored approximation of the contract's
# shape.
#
# The workspace contract lives outside this package and decideR does not
# depend on it: the contract is a source file shared by the member packages,
# not an installed package. This test therefore runs only when
# `DECIDER_ORCHESTRA_MANIFEST_R` names that file, and skips otherwise (a fresh
# clone, CI, CRAN).

.locate_orchestra_manifest_contract <- function() {
  path <- Sys.getenv("DECIDER_ORCHESTRA_MANIFEST_R", unset = NA_character_)
  if (is.na(path) || !file.exists(path)) NULL else path
}

test_that("decide_rate_from_manifest() closes the pipeline on a REAL orchestra_manifest (D-08, IOP)", {
  contract_path <- .locate_orchestra_manifest_contract()
  testthat::skip_if(
    is.null(contract_path),
    "DECIDER_ORCHESTRA_MANIFEST_R does not name the workspace contract file"
  )
  testthat::skip_if_not_installed("digest")

  contract_env <- new.env(parent = globalenv())
  suppressWarnings(suppressMessages(sys.source(contract_path, envir = contract_env)))

  set.seed(2026L)
  rates  <- seq(0, 200, by = 25)
  n_draw <- 1500L
  ymax   <- rnorm(n_draw, mean = 5.6, sd = 0.30)
  yield_draws <- vapply(rates, function(r) 3 + (ymax - 3) * (1 - exp(-r / 80)),
                        numeric(n_draw))

  make_manifest <- function(grounding_token) {
    dh <- contract_env$.hash_payload(data.frame(), yield_draws, NULL, NULL, 2026L)
    contract_env$orchestra_manifest(
      manifest_version   = contract_env$MANIFEST_VERSION,
      emitter_package    = "PESTO",
      emitter_version    = "0.10.1",
      inferential_target = "predictions",
      run_id             = paste0("test-", substr(contract_env$.sha256(yield_draws), 1L, 8L)),
      method             = "PESTO:ies_callback (test)",
      seed               = 2026L,
      outputs            = yield_draws,
      metadata           = list(grounding = grounding_token, yield_draws = yield_draws),
      timestamp          = Sys.time(),
      data_hash          = dh
    )
  }

  m_grounded   <- make_manifest(contract_env$GROUNDING_GROUNDED)
  m_unverified <- make_manifest(contract_env$GROUNDING_UNVERIFIED)

  # Integrity-check the manifests before consuming them -- the contract's own
  # guard, an oracle decideR did not author.
  expect_true(isTRUE(contract_env$verify_manifest(m_grounded)$ok))
  expect_true(isTRUE(contract_env$verify_manifest(m_unverified)$ok))
  expect_true(S7::S7_inherits(m_grounded, contract_env$orchestra_manifest))

  d_grounded <- decide_rate_from_manifest(m_grounded, rates = rates,
                                          price_grain = 300, price_input = 1.2)
  expect_false(d_grounded@abstained)
  expect_true(d_grounded@action > 0 && d_grounded@action < 200)
  expect_identical(d_grounded@inputs$emitter_package, "PESTO")

  d_unverified <- decide_rate_from_manifest(m_unverified, rates = rates,
                                            price_grain = 300, price_input = 1.2,
                                            safe_rate = 0)
  expect_true(d_unverified@abstained)
  expect_identical(d_unverified@abstain_reason, "input_ungrounded")
  expect_identical(d_unverified@action, 0)
})
