# PISA 2000 has separate weights for reading, science and mathematics because
# not every student was tested in all domains and scores for missing tests were
# not imputed. To allow for repeat cross-sectional analyses from 2000-2022, we
# therefore need to split out the weight columns for all cycles, even though
# from 2003 onwards these three sets of weights are identical.

# NOTE: suppose we rename `w_fstuwt` and `w_fstr` to long names, what should they be?
# * we do allow for some abbreviations, we just want to minimize 'em, but w_ itself seems okay
# * fstuwt: w_student_final
# * fstr / fstur:   w_student_r
#
# e.g.
#
# * w_read_fstuwt => w_literacy_student_final
# * w_scie_fstr80 => w_science_student_r80
#
# as for school weights, these seem to be renamed almost every edition:
# WNRSCHB / SCWEIGHT / W_FSCHWT / W_SCHGRNRABWT,
# where W_SCHGRNRABWT (but really also W_FSCHWT etc.) stands for
# "GRADE NONRESPONSE ADJUSTED SCHOOL BASE WEIGHT"
# so if we were to include it in the dataset I'd settle on w_school_base
#
# (The school base weight is included in the calculation of the student final weights
# alongside an adjustment for non-response, and they are therefore generally less useful.)

description <- 'Sampling and replicate weights'

is_stable <- TRUE

columns <- tribble()

library('tidyverse')
library('testthat')

source('src/helpers.R')


REPLICATE_WEIGHTS_PATTERN <- '^w_(\\w+_)?fstu?r(wt)?\\d+$'
WEIGHTS_PATTERN <- '^w_'

process <- function(raw, processed) {
  cli_progress_step('Standardize column names of replicate and final weights')

  # change w_fsturwt into w_fstr to accord with earlier editions
  weights <- map(raw, function(df) {
    df |>
      select(matches(WEIGHTS_PATTERN)) |>
      rename_with(\(name) str_replace(name, 'urwt', 'r'))
  })

  READ_WEIGHTS <- c('w_read_fstuwt', str_glue('w_read_fstr{d}', d=1:80))
  MATH_WEIGHTS <- c('w_math_fstuwt', str_glue('w_math_fstr{d}', d=1:80))
  SCIE_WEIGHTS <- c('w_scie_fstuwt', str_glue('w_scie_fstr{d}', d=1:80))
  DOMAIN_WEIGHTS <- c(READ_WEIGHTS, MATH_WEIGHTS, SCIE_WEIGHTS)
  WEIGHTS <- c('w_fstuwt', str_glue('w_fstr{d}', d=1:80))

  # only PISA 2000 has separate weights for the different disciplines
  cli_progress_step('Generate separate weights for read, math and scie')

  expanded_weights <- map(CYCLES[-1], \(y)
    set_names(weights[[as.character(y)]][, c(WEIGHTS, WEIGHTS, WEIGHTS)], nm = DOMAIN_WEIGHTS))

  bind_rows(weights$`2000`[, DOMAIN_WEIGHTS], !!!expanded_weights) |>
    rename_with(\(name) str_replace(name, 'fstuwt', 'student_final')) |>
    rename_with(\(name) str_replace(name, 'fstr', 'student_r')) |>
    rename_with(\(name) str_replace(name, 'read', 'literacy')) |>
    rename_with(\(name) str_replace(name, 'scie', 'science'))
}

verify <- function(raw, processed) {

}
