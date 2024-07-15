# TODO: rescaled indices for ESCS + isei + consider to what extent the subscales are comparable over time

# PISA 2000 to 2012 (?) did not contain an ESCS measure but did contain its subscales
# so that it was possible to backport, and this was done in 2015.
#
# In PISA 2018 and 2022 some changes were made to how ESCS and HISEI was calculated, and
# adjusted scores were made available for 2012 to 2018.
#
# The 2022 backport is not on the same scale as the 2015 backport, but because the methodological differences
# are so slight, it is possible to backport with a simple (intercept-only) calibration.

library('tidyverse')
library('testthat')
library('haven')

source('src/helpers.R')

columns <- tribble(
  ~name,                            ~original_name, ~is_complete, ~is_exact, ~description,
  "escs",                           "escs",         TRUE,         FALSE,     "calibrated across changes in method (r=0.98)",
  "highest_isced",                  "hisced",       TRUE,         FALSE,     "calibrated across changes in method (r=0.99)",
)

description <- "Parents' occupation and social, economic and cultural status"

is_stable <- TRUE

pad5 <- function(x) {
  str_pad(x, 5, side = 'left', pad = '0')
}

process <- function(raw, processed) {
  cli_progress_step('Load retrended ESCS and HISEI data')

  escs1234 <- bind_rows(
    transmute(read_sas("data/escs/2012/escs_2000.sas7bdat"),
      nth_cycle = 1,
      country_iso = cnt,
      school_id = pad5(schoolid),
      student_id = pad5(stidstd),
      escs = escs_trend
    ),
    transmute(read_sas("data/escs/2012/escs_2003.sas7bdat"),
      nth_cycle = 2,
      country_iso = cnt,
      school_id = pad5(schoolid),
      student_id = pad5(stidstd),
      escs = escs_trend
    ),
    transmute(read_sas("data/escs/2012/escs_2006.sas7bdat"),
      nth_cycle = 3,
      country_iso = cnt,
      school_id = pad5(schoolid),
      student_id = pad5(stidstd),
      escs = escs_trend
    ),
    transmute(read_sas("data/escs/2012/escs_2009.sas7bdat"),
      nth_cycle = 4,
      country_iso = cnt,
      school_id = pad5(schoolid),
      student_id = pad5(stidstd),
      escs = escs_trend
    )
  )

  escs567 <- hisei567 <- read_csv('data/escs/2022/escs_trend.csv') |>
    rename(
      nth_cycle = 'cycle',
      country_iso = 'cnt',
      school_id = 'schoolid',
      student_id = 'studentid',
      escs = 'escs_trend',
      hisei = 'hisei_trend',
      homepos = 'homepos_trend',
    ) |> mutate(
      school_id = pad5(school_id),
      student_id = pad5(student_id),
    ) |>
    filter(nth_cycle >= 4)

  data <- across_cycles(raw, c('nth_cycle', 'country_iso', 'cntstuid', 'cntschid', 'hisei', 'escs'))

  cli_progress_step('Calibrate 2000-2009 ESCS and HISEI variables to the 2022 scale')

  hisei1234 <- data |>
    keep_at(c('2000', '2003', '2006', '2009')) |>
    bind_rows() |>
    mutate(hisei = hisei + 0.0871992180632055) |>
    rename(student_id = 'cntstuid', school_id = 'cntschid')
  hisei567 <- hisei567
  hisei8 <- raw$`2022` |>
    select(nth_cycle, country_iso, cntschid, cntstuid, hisei, escs) |>
    transmute(
      nth_cycle = nth_cycle,
      country_iso = country_iso,
      school_id = str_c('0', str_sub(cntschid, 3)),
      student_id = str_c('0', str_sub(cntstuid, 3)),
      hisei = hisei,
    )

  escs1234 <- escs1234 |>
    mutate(escs = escs - 0.187283287132468)
  escs567 <- hisei567
  escs8 <- hisei8

  hisei <- bind_rows(hisei1234, hisei567, hisei8) |>
    select(nth_cycle, country_iso, school_id, student_id, hisei)
  escs <- bind_rows(escs1234, escs567, escs8) |>
    select(nth_cycle, country_iso, school_id, student_id, escs)

  cli_progress_step('Merge calibrated variables')

  ids <- c('nth_cycle', 'country_iso', 'school_id', 'student_id')
  calibrated <- processed |>
    select(all_of(c('student_uid', ids))) |>
    left_join(hisei, by = ids) |>
    left_join(escs, by = ids) |>
    rename(highest_isei = 'hisei')

  calibrated
}

verify <- function(raw, processed) {
  expect_true(nrow(processed) <= 5000000)
  # escs |> group_by(cycle) |> summarize(mu = mean(escs, na.rm = TRUE), sd = sd(escs, na.rm = TRUE))
}
