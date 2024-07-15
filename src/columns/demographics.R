# age, immig, testlang, gender etc.

library('tidyverse')
library('testthat')

source('src/helpers.R')

description <- 'Demographics'

is_stable <- TRUE

columns <- tribble(
  ~name,                          ~original_name, ~is_complete,  ~is_exact, ~description,
  "age",                          "age",          TRUE,          TRUE,      "from months to years (00)",
  "immigrant_generation",         "immig",        TRUE,          TRUE,      "harmonized",
  "sex",                          "gender",       TRUE,          TRUE,      "harmonized",
  "speaks_test_language_at_home", "",             FALSE,         TRUE,      "harmonized",
)

set_levels <- function(factor, values) {
  levels(factor) <- values
  factor
}

process <- function(raw, processed) {
  # uid <- bind_rows(across_assessments(raw, 'student_uid'))

  cli_progress_step('Convert age from months to years for PISA 2000')

  # `age`
  head <- tibble(age = raw$`2000`$age / 12)
  tail <- across_cycles(raw, 'age') |>
    discard_at('2000') |>
    bind_rows()
  age <- bind_rows(head, tail)

  sex <- bind_rows(across_cycles(raw, "gender")) |> rename(sex = "gender")

  cli_progress_step('Infer immigrant generation for PISA 2000')

  # NOTE: it is ambiguous how we should handle the (very rare) case where the
  # student was not born in the country of test but their parents were; with
  # this approach where we sum `is_native_student + has_native_parent` they are
  # categorized as 'Second-Generation' which seems okay
  is_native_student <- raw$`2000`$st16q01 == '<Country of Test>'
  has_native_parent <- raw$`2000`$st16q02 == '<Country of Test>' | raw$`2000`$st16q03 == '<Country of Test>'

  cli_progress_step('Harmonize factor levels for immigrant generation')

  generation <- tibble(immigrant_generation = c(
    factor(is_native_student + has_native_parent, levels=0:2, labels=c('First-Generation', 'Second-Generation', 'Native')),
    raw$`2003`$immig |> set_levels(c('Native', 'First-Generation', 'Second-Generation')),
    raw$`2006`$immig,
    raw$`2009`$immig,
    raw$`2012`$immig,
    raw$`2015`$immig,
    raw$`2018`$immig,
    raw$`2022`$immig |> set_levels(c('Native', 'Second-Generation', 'First-Generation'))
  ))

  cli_progress_step('Harmonize factor levels for language spoken at home')

  language <- tibble(speaks_test_language_at_home = c(
    raw$`2000`$st17q01 == '<Test language>',
    raw$`2003`$st16q01 == '<Test language>',
    raw$`2006`$st12q01 == 'Language of test',
    raw$`2009`$st19q01 == 'Language of test',
    raw$`2012`$st25q01 == 'Language of the test',
    raw$`2015`$st022q01ta == 'Language of test',
    raw$`2018`$st022q01ta == 'Language of the test',
    raw$`2022`$st022q01ta == 'Language of the test'
  ))

  bind_cols(age, sex, generation, language)
}

verify <- function(raw, processed) {

}
