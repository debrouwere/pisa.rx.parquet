# The derived column `hisced` (parents' highest ISCED) is not available in all
# cycles but can be inferred. `pared`, a conversion of `hisced` into a country-
# and time-specific amount of schooling can be similarly inferred when not
# available.
#
# The difference between `pared` and `paredint` is that the latter is not
# specific to country or time, but reflects the median amount of years of
# schooling that has been obtained for a particular ISCED level internationally.
# It was introduced in the 2018 cycle but we've backported it to earlier
# assessments. Both have their flaws and merits: `pared` starts from the
# assumption that what is nominally the same degree may reflect very different
# amounts of study and that this must be corrected for, whereas `paredint`
# argues that this picture is mudied because the pace of study also differs by
# country, such that ultimately the level of the degree obtained remains the
# most trustworthy indicator and that the only reason we need a mapping to years
# of education is to account for the categories not being equidistant.

library('tidyverse')
library('testthat')

source('src/helpers.R')


columns <- tribble(
  ~name,                            ~original_name, ~is_complete,  ~is_exact, ~description,
  "mothers_isced",                  "misced",       TRUE,          TRUE,      "from months to years (00)",
  "fathers_isced",                  "fisced",       TRUE,          TRUE,      "harmonized",
  "highest_isced",                  "hisced",       TRUE,          TRUE,      "harmonized",
  "parental_education_by_country",  "pared",        TRUE,          FALSE,     "inferred from misced/fisced and an isced-to-years mapping (00)",
  "parental_education",             "paredint",     TRUE,          TRUE,      "backported using the OECD mapping from 2018, Annex D",
)

# hisei, hisced, ...

description <- "Parents' education and occupation"

is_stable <- TRUE

ISCED <- c('None', 'ISCED 1', 'ISCED 2', 'ISCED 3B, C', 'ISCED 3A, ISCED 4', 'ISCED 5B', 'ISCED 5A, 6')

isced_to_years <- read_csv('data/isced/2018-isced-to-years.csv') |>
  pivot_longer(starts_with('ISCED'), names_to='hisced', values_to='pared') |>
  group_by(hisced) |>
  summarize(paredint = median(pared, na.rm = TRUE))


process <- function(raw, processed) {
  cli_progress_step("Infer parents' highest ISCED level and years of education.")

  columns <- c('country', 'economy', 'region', 'misced', 'fisced', 'pared')

  # pared is available for most assessments but not 2000
  #
  # TODO: possibly, we'll want to use the levels inferred from the 2003 dataset
  # instead of from the published 2006 mapping table
  isced_to_years_by_area <- raw$`2003` |>
    mutate(hisced = pmax(ordered(misced), ordered(fisced), na.rm = TRUE)) |>
    group_by(country, economy, region, hisced) |>
    summarize(pared = median(pared, na.rm = TRUE))

  head <- raw$`2000` |>
    select(all_of(c('country', 'region', 'economy', 'misced', 'fisced'))) |>
    mutate(
      misced = factor(misced, levels=0:6, labels=ISCED, ordered=TRUE),
      fisced = factor(fisced, levels=0:6, labels=ISCED, ordered=TRUE),
      hisced = pmax(misced, fisced, na.rm = TRUE)
    ) |>
    left_join(isced_to_years_by_area, by = c('country', 'economy', 'region', 'hisced'))

  tail <- across_cycles(raw, c('country', 'misced', 'fisced', 'pared')) |>
    discard_at('2000') |>
    bind_rows() |>
    mutate(
      misced = factor(misced, levels=ISCED, ordered=TRUE),
      fisced = factor(fisced, levels=ISCED, ordered=TRUE),
      hisced = pmax(misced, fisced, na.rm = TRUE)
    )

  bind_rows(head, tail) |>
    mutate(country = NULL, economy = NULL, region = NULL) |>
    left_join(isced_to_years, by = c('hisced')) |>
    rename(
      mothers_isced = 'misced',
      fathers_isced = 'fisced',
      highest_isced = 'hisced',
      parental_education_by_country = 'pared',
      parental_education = 'paredint'
    )
}

verify <- function(raw, processed) {
  # sanity check
  # pisa2000 |> filter(country_iso == 'BEL') |> count(pared)
  # pisa2003 |> filter(country_iso == 'BEL') |> count(pared)
  # pisa2018$fisced
}
