# The roxygen `@examples` blocks for the manifest tail are (D-07) the only
# place the package's own doc claimed to exercise a *real* consumption of an
# S7-shaped manifest -- everything else was wrapped in `\dontrun{}` or built
# an S3 stand-in the duck-typed reader cannot see. Extract the example code
# straight from the shipped .Rd source and actually run it, so a future
# regression back to an unreadable stand-in or an undefined variable fails
# here rather than passing `R CMD check` silently.
#
# Reads the parsed Rd from the installed package's help database when one is
# available (the shape `R CMD check` runs tests in, where the source `man/`
# tree is not present), falling back to the source `man/*.Rd` file for local
# iteration under `devtools::load_all()`.

.get_parsed_rd <- function(topic_file) {
  installed_db <- tryCatch(tools::Rd_db("decideR"), error = function(e) NULL)
  if (!is.null(installed_db) && topic_file %in% names(installed_db)) {
    return(installed_db[[topic_file]])
  }
  testthat::test_path("..", "..", "man", topic_file)
}

.run_rd_examples <- function(topic_file) {
  rd <- .get_parsed_rd(topic_file)
  ex_file <- tempfile(fileext = ".R")
  on.exit(unlink(ex_file), add = TRUE)
  tools::Rd2ex(rd, ex_file, defines = NULL)
  env <- new.env(parent = globalenv())
  source(ex_file, local = env, echo = FALSE)
  env
}

test_that("decide_from_manifest()'s @examples run for real, not \\dontrun (D-07)", {
  env <- .run_rd_examples("decide_from_manifest.Rd")
  expect_true(exists("m", envir = env))
  expect_s7_class(get("m", envir = env), get("demo_manifest", envir = env))
})

test_that("decide_rate_from_manifest()'s @examples run for real, not \\dontrun (D-07)", {
  env <- .run_rd_examples("decide_rate_from_manifest.Rd")
  expect_true(exists("m", envir = env))
  expect_s7_class(get("m", envir = env), get("demo_manifest", envir = env))
})
