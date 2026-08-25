# Documentation-accuracy checks that cannot be pinned by a runtime assertion
# on the returned object -- the defect is in what the roxygen text claims, not
# in what the function computes. Read from the installed Rd (the shape
# `R CMD check` runs tests in, where the source `R/` tree is not shipped),
# falling back to the source `man/*.Rd` for local iteration.

.get_parsed_rd_docs <- function(topic_file) {
  installed_db <- tryCatch(tools::Rd_db("decideR"), error = function(e) NULL)
  if (!is.null(installed_db) && topic_file %in% names(installed_db)) {
    return(installed_db[[topic_file]])
  }
  tools::parse_Rd(testthat::test_path("..", "..", "man", topic_file))
}

.rd_text <- function(topic_file) {
  rd <- .get_parsed_rd_docs(topic_file)
  txt_file <- tempfile(fileext = ".txt")
  on.exit(unlink(txt_file), add = TRUE)
  tools::Rd2txt(rd, out = txt_file)
  paste(readLines(txt_file), collapse = "\n")
}

test_that("decide_position_size documents max_drawdown as a one-period quantile, not a path drawdown (D-09)", {
  # `max_drawdown` names a single-period VaR-style constraint
  # (`quantile(f * r, loss_quantile) >= -max_drawdown`); a true drawdown is a
  # peak-to-trough statistic over a path. The rendered help must say so
  # explicitly rather than let "drawdown limit" / "drawdown cap" stand
  # unqualified, which reads to a practitioner as a path guarantee the
  # function does not make.
  txt <- .rd_text("decide_position_size.Rd")
  expect_match(txt, "one-period",
              info = "decide_position_size docs must clarify max_drawdown is a one-period quantile, not a path drawdown")
  expect_match(txt, "value-at-risk|VaR")
})
