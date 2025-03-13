#### verification ####

outcomes <- list(
  wide = c(
    'pv1literacy',
    'pv1math',
    'pv1math_content_shape',
    'pv1math_content_change',
    'pv1science',
    'pv2literacy',
    'pv2math',
    'pv2math_content_shape',
    'pv2math_content_change',
    'pv2science',
    'w_literacy_student_final',
    'w_math_student_final',
    'w_science_student_final'
  ),
  long = c(
    'i',
    'literacy',
    'math',
    'math_content_shape',
    'math_content_change',
    'science',
    'w_literacy_student_final',
    'w_math_student_final',
    'w_science_student_final'
  ),
  imputed = c(
    'i',
    'literacy',
    'math',
    'math_content_shape',
    'math_content_change',
    'science',
    'w_student_final'
  )
)

covariates <- c(
  'grade_lead',
  'age',
  'sex',
  'immigrant_generation',
  'speaks_test_language_at_home',
  'mothers_isced',
  'fathers_isced',
  'highest_isei',
  'escs',
  'grade_lag',
  'highest_isced',
  'parental_education',
  'parental_education_by_country'
)

observed <- read_parquet('build/wide/cycle=2000/country=Albania/part-0.parquet', col_select = all_of(c(outcomes$wide, covariates)))
repeated <- read_parquet('build/long/observed/cycle=2000/country=Albania/part-0.parquet', col_select = all_of(c(outcomes$long, covariates)))
imputed <- read_parquet('build/long/imputed/cycle=2000/country=Albania/part-0.parquet', col_select = all_of(c(outcomes$imputed, covariates)))
nrow(imputed) / nrow(observed)

observed |> slice(2) |> glimpse()
repeated |> group_by(i) |> slice(2) |> ungroup() |> glimpse()
imputed |> group_by(i) |> slice(2) |> ungroup() |> glimpse()

observed |> slice(133) |> glimpse()
repeated |> group_by(i) |> slice(133) |> ungroup() |> glimpse()
imputed |> group_by(i) |> slice(133) |> ungroup() |> glimpse()




observed <- read_parquet('build/wide/cycle=2000/country=Belgium/part-0.parquet', col_select = all_of(c(outcomes$wide, covariates)))
repeated <- read_parquet('build/long/observed/cycle=2000/country=Belgium/part-0.parquet', col_select = all_of(c(outcomes$long, covariates)))
imputed <- read_parquet('build/long/imputed/cycle=2000/country=Belgium/part-0.parquet', col_select = all_of(c(outcomes$imputed, covariates)))
imputed_1 <- imputed |> filter(i == 1)
nrow(imputed) / nrow(observed)

observed |> slice(10) |> glimpse()
repeated |> group_by(i) |> slice(10) |> ungroup() |> glimpse()
imputed |> group_by(i) |> slice(10) |> ungroup() |> glimpse()

weighted.mean(observed$pv1math, observed$w_math_student_final, na.rm = TRUE)
weighted.mean(imputed_1$math, imputed_1$w_student_final, na.rm = TRUE)
weighted.mean(imputed$math, imputed$w_student_final, na.rm = TRUE)

weighted.mean(observed$pv1math, observed$w_math_student_final, na.rm = TRUE)
weighted.mean(imputed_1$math, imputed_1$w_student_final, na.rm = TRUE)
weighted.mean(imputed$math, imputed$w_student_final, na.rm = TRUE)

weighted.mean(observed$pv1science, observed$w_science_student_final, na.rm = TRUE)
weighted.mean(imputed_1$science, imputed_1$w_student_final, na.rm = TRUE)
weighted.mean(imputed$science, imputed$w_student_final, na.rm = TRUE)

quantile(observed$pv1science, c(0.1, 0.5, 0.9), na.rm = TRUE)
quantile(repeated$science, c(0.1, 0.5, 0.9), na.rm = TRUE)
quantile(imputed$science, c(0.1, 0.5, 0.9), na.rm = TRUE)
