# * codebook with summary stats
# * codebook converted into binary presence/absence per country and assessments, making it easy to do
#   `filter(hisced >= 8)` -- or maybe more flexible so we can do `mutate(across(everything(), ~ .x >= 0.50) |> summarize(across(everything()), sum, .by='economy') |> filter(hisced >= 8) |> pull(economy)`
#   and then use that in a semi-join
# ** or perhaps we know which countries we care about and we want to get the coverage,
#    `filter(economy %in% economies_subset) |> summarize(across(c(hisced, hisei, escs)), ~ `
# * organizational membership so folks can do e.g. `filter(membership == 'European Union', accession <= 2000) |> pull(economy)`
#   and then use that in a semi-join; for now we'll stick to OECD and EU but of course we can add other supranational organizations later on

library("tidyverse")
library("arrow")

#### Codebook ####

CYCLES <- c(2000, 2003, 2006, 2009, 2012, 2015, 2018, 2022)

assessments <- open_dataset('build/pisa.rx') |>
  select(!starts_with('pv') & !starts_with('w_') & !starts_with('f_') & !ends_with('_id') & !ends_with('_uid') & !ends_with('_iso')) |>
  collect()

grid <- assessments |>
  select(country, economy, region) |>
  distinct() |>
  cross_join(tibble(cycle = CYCLES))

coverage <- assessments |>
  full_join(grid) |>
  group_by(cycle, country, economy, region) |>
  summarize(across(everything(), \(x) round(1 - mean(is.na(x)), 2))) |>
  ungroup()

write_csv(coverage, 'build/coverage.csv')

# # Example: find countries that have at least 50% non-na values for
# # `speaks_test_language_at_home` in every cycle
# coverage <- read_csv('build/coverage.csv')
# usable_countries <- coverage |>
#   mutate(across(everything(), min), .by = 'country') |>
#   filter(speaks_test_language_at_home >= 0.5)
#
# assessments |>
#   semi_join(usable_countries, by = c('cycle', 'country'))
#
# # Example: find countries that have 50% non-na values for
# # `speaks_test_language_at_home` for at least 6 out of 8 cycles
# # (slightly more involved because we need to calculate by region
# # and then summarize down to country, otherwise countries with
# # multiple regions get counted more than once)
# coverage <- read_csv('build/coverage.csv')
# usable_countries <- coverage |>
#   filter(speaks_test_language_at_home >= 0.5) |>
#   count(country, region) |>
#   summarize(n = min(n), .by = 'country') |>
#   filter(n >= 6)
#
# assessments |>
#   semi_join(usable_countries, by = c('cycle', 'country'))

#### Memberships ####

file.copy("data/memberships.csv", "build/memberships.csv")

# Example:
#
# memberships <- read_csv('data/memberships.csv')
# pisa |>
#   semi_join(
#     filter(memberships, organization == 'European Union', since <= 2000, is.na(until)),
#     by = 'country_iso')
