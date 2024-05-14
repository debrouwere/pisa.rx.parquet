# grade, relative_grade, stream (for Flanders), ...

library('tidyverse')
library('testthat')

source('src/helpers.R')


description <- 'Student grade level'

is_stable <- TRUE

# credit: Ken Williams
most_common <- function(x, na.rm=FALSE) {
  if (na.rm) {
    x <- na.omit(x)
  }
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

rename_relative_grade <- function(df) {
  df |> transmute(
    grade_lead = grade,
    grade_lag = -grade_lead,
    grade = NULL
  )
}

add_relative_grade <- function(df, col) {
  modes <- df |>
    rename(grade = col) |>
    group_by(country) |>
    summarize(modal_grade = most_common(grade))

  df |>
    rename(grade = col) |>
    select(country, grade) |>
    left_join(modes, by='country') |>
    mutate(grade = grade - modal_grade) |>
    rename_relative_grade()
}

process <- function(raw, processed) {
  cli_progress_step('Make student grade relative to the modal grade for 2000-2009')

  # uid <- bind_rows(across_assessments(raw, 'student_uid'))

  bind_rows(
    add_relative_grade(raw$`2000`, 'st02q01'),
    add_relative_grade(raw$`2003`, 'st01q01'),
    add_relative_grade(raw$`2006`, 'st01q01'),
    add_relative_grade(raw$`2009`, 'st01q01'),
    rename_relative_grade(raw$`2012`),
    rename_relative_grade(raw$`2015`),
    rename_relative_grade(raw$`2018`),
    rename_relative_grade(raw$`2022`)
  )
}

verify <- function(raw, processed) {

}



# ASO <- regex('^bel.+(general|regular|reg\\.)', ignore_case=TRUE)
# TSO <- regex('^bel.+(technical|techn\\.)', ignore_case=TRUE)
# KSO <- regex('^bel.+(artistic|art\\.)', ignore_case=TRUE)
# BSO <- regex('^bel.+(vocational|voc\\.)', ignore_case=TRUE)
#
# be_progn_to_stream <- function(progn) {
#   stream <- rep(NA, length(progn))
#   stream[str_detect(progn, ASO)] <- 'ASO'
#   stream[str_detect(progn, TSO)] <- 'TSO'
#   stream[str_detect(progn, KSO)] <- 'KSO'
#   stream[str_detect(progn, BSO)] <- 'BSO'
#   factor(stream)
# }
#
# pisa2000$stream <- NA
# pisa2003$stream <- be_progn_to_stream(pisa2003$progn)
# pisa2006$stream <- be_progn_to_stream(pisa2006$progn)
# pisa2009$stream <- be_progn_to_stream(pisa2009$progn)
# pisa2012$stream <- be_progn_to_stream(pisa2012$progn)
# pisa2015$stream <- be_progn_to_stream(pisa2015$progn)
# pisa2018$stream <- be_progn_to_stream(pisa2018$progn)
# pisa2022$stream <- be_progn_to_stream(pisa2022$progn)
