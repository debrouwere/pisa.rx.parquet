# Read in only a weighted fraction of the data by filtering on the
# `f_literacy`, `f_math` or `f_science` column. (From
# 2003 onwards, selecting a particular `f_literacy` will lead to a similar
# fraction of the total weight for math and science too, and vice versa, but for
# 2000 these fractions are not interchangeable.)
#
# open_dataset('pisa.rx') |>
#   filter(f_literacy <= 0.10) |>
#   collect()
#
# Reading in only a fraction is not faster than reading in the entire dataset (as every
# row must still be scanned), but it will use less memory and will speed up analyses.
# For faster reading, select fewer columns, if possible.

description <- 'Data fractions'

# .by maintains the existing stratum ordering (unlike group_by, which is alphabetical)
# so we can keep this preprocessor stable despite the grouping operation
is_stable <- TRUE

columns <- tribble()

library('tidyverse')
library('testthat')

source('src/helpers.R')

# randomly order observations and express the ordering as a vector of weighted
# quantiles (even a completely random sample that ignores strata and weights
# will be an unbiased representation of the full sample, but this decreases the
# variance)
random_order <- function(w) {
  ixs <- sample.int(length(w))
  cdf <- cumsum(w[ixs]) / sum(w)
  cdf[order(ixs)]
}

process <- function(raw, processed) {
  cli_progress_step('Assign a sample proportion to each observation, within strata.')

  set.seed(2024)

  # for 2003 and beyond, there is a single final weight that is valid for all
  # domains, but not for 2000, and as such our fractions need to be split by
  # outcome too
  processed |>
    transmute(
      f_literacy = random_order(w_literacy_student_final),
      f_math = random_order(w_math_student_final),
      f_science = random_order(w_science_student_final),
      .by = 'stratum_uid'
    )
}

verify <- function(raw, processed) {

}
