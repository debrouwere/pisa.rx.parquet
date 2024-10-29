# The unique identifiers are (re)constructed so that
#
#   cycle       = cycle
#   country_uid = cycle + country_id
#   economy_uid = cycle + country_id + economy_id
#   region_uid  = cycle + country_id + economy_id + region_id
#   school_uid  = cycle + country_id + economy_id + region_id + school_id
#   student_uid = cycle + country_id + economy_id + region_id + school_id + student_id
#
# (This is mostly how PISA itself has been constructing its identifiers, and
# in particular `cntstuid`, included since 2015, is unique within a cycle, but
# they didn't always adhere to this formula and they don't include the cycle
# either. This approach is generally useful because you can always join
# at the most specific level you’re interested in and don’t have to include
# the higher levels. This is for internal joins (student data to aggregated
# student data, student data to school data, etc.), for external datasets
# such as GDP etc. it seems more likely that you'd use cycle and/or country_iso.
#
# Note generally that for the country_id, economy_id and region_id columns we
# do guarantee consistency over time and uniqueness within a cycle, so these
# keys can be used to join across cycles, as clustering variables in a multilevel
# analysis etc.)

# The approach taken here to harmonize subnations is as follows:
# * For 2000, subnation names are masked, but often it is possible to use
# circumstantial evidence to figure out which identifier refers to which
# subnation, e.g. by comparing the participants in a coverage table to the
# sum of final weights per subnation
# * For later years, look up the subnation names for a country, come up with a standardized name,
# and add the mapping to `data/subnations.csv`
#
# Then, we also consider whether the same subnations occur in all editions, as often
# a subnation may be a different combination of provinces or communities in every
# edition. In that case, we can sometimes still construct regions that are consistent
# from 2000 to 2022 by taking the subnations and including or excluding certain strata,
# as the strata also often include information about the subregions. In some cases
# this does mean that whereas the subnation may have been adjudicated in some cycles,
# we can no longer give the same guarantee for the harmonized regions.

# In the simplest case, country, economy and region will be identical to each other.
# This allows us to easily take subsets of the data:
#
# * select countries and economies
#   => filter()
# * select countries but not economies
#   => filter(country == economy)
# * select economies but not countries
#   => filter(economy != country)
# * select regions but not countries
#   => filter(region != country, region != economy)
# * select regions and economies (that are not countries)
#   => filter(region != country)
#
# When selecting countries and/or economies, we can analyze
# at that level but we can also still group by region.
#
# The OECD uses a mix of colloquial names, official names and compromise names
# to avoid geopolitical sensitivities, with a small number of differences in
# naming between assessments that we have standardized.
#
# Most of the time, PISA analyses work at the economy level (which may be
# identical to the country), e.g. PISA reports Hong Kong, Macao and
# Beijing-Shanghai-Jiangsu-Zhejiang separately although they are all part of
# China. Economies and regions are (at least for PISA 2000 to PISA 2022)
# mutually exclusive: some countries participate with multiple regions, others
# with multiple economies, but there are never different regions within an
# economy.
#
# In a handful of cases we have "upgraded" an economy to a country:
# * Spain (regions) -- because it seems to include *all* regions!?
# * XKK,KSV,Kosovo
# * MKD,ROM,North Macedonia
# * SRB,YUG,Serbia

description <- 'Identifiers'

is_stable <- TRUE

columns <- tribble()

library('tidyverse')
library('testthat')

source('src/helpers.R')

cycle_to_ix <- 1:8
names(cycle_to_ix) <- CYCLES

countries <- read_csv('data/countries.csv')
iso_to_name <- countries$name
iso_to_official_name <- countries$official_name
iso_to_oecd_name <- countries$oecd_name
names(iso_to_name) <- names(iso_to_official_name) <- names(iso_to_oecd_name) <- countries$iso_alpha_3

name_to_iso <- official_name_to_iso <- oecd_name_to_iso <- countries$iso_alpha_3
names(name_to_iso) <- countries$name
names(official_name_to_iso) <- countries$official_name
names(oecd_name_to_iso) <- countries$oecd_name

# NOTE: we could possibly be a bit more disciplined about this --
# Puerto Rico gets the USA country code but Macao is treated as
# separate from China and gets the MAC code instead of CHN.
economies <- read_csv('data/economies.csv')

iso_to_economy <- economies$name
names(iso_to_economy) <- economies$economy

economy_to_country <- economies$country
names(economy_to_country) <- economies$economy

countries <- countries |>
  filter(!(iso_alpha_3 %in% economies$economy))

subnations <- read_csv('data/subnations.csv') |>
  pivot_longer(all_of(as.character(CYCLES)), names_to='cycle', values_to='subnatio') |>
  mutate(cycle = as.integer(cycle))

subnations_iso <- read_csv('data/subnations.csv') |> select(country_iso, region_iso, subnation) |> drop_na()
subnation_to_iso <- subnations_iso$region_iso
names(subnation_to_iso) <- subnations_iso$subnation

strata <- read_csv('data/strata.csv') |>
  mutate(cycle = as.integer(cycle))

str_tail <- function(x, width) {
  str_sub(x, start = -width)
}

str_pad0 <- function(x, width) {
  str_pad(x, width = width, pad = '0')
}

str_clean <- function(x, width) {
  str_replace_all(x, '[^\\d]', '')
}

process <- function(raw, processed) {
  cli_progress_step('Fetch identifiers and convert to strings')

  raw <- across_cycles(raw, c('economy_id', 'economy_iso', 'stratum_id', 'cnt', 'cntschid', 'cntstuid', 'subnatio', 'stratum', 'lang_of_test')) |>
    map(\(df) mutate(df, across(everything(), as.character))) |>
    imap(\(df, y) mutate(df, cycle = as.integer(y)))

  cli_progress_step('Identify countries and economies')

  processed <- raw |>
    bind_rows() |>
    transmute(
      cycle = cycle,
      nth_cycle = as.integer(cycle_to_ix[as.character(cycle)]),
      country_iso = if_else(economy_iso %in% countries$iso_alpha_3, economy_iso, economy_to_country[economy_iso]),
      country = iso_to_name[country_iso],
      economy_iso = economy_iso,
      economy = default(iso_to_economy[economy_iso], country),
      # leave original ids untouched for cross-referencing with other data sets that use them
      school_oid = cntschid,
      student_oid = cntstuid,
      # clean up ids
      stratum_id = case_match(cycle,
        2000 ~ str_pad0(stratum_id, 5),
        c(2003, 2006, 2009) ~ str_pad0(str_tail(stratum_id, 4), 5),
        c(2012, 2015, 2018, 2022) ~ str_pad0(str_tail(str_clean(stratum_id), 4), 5),
        ),
      # TODO: prettify the stratum column (remove country prefixes etc.)
      stratum = stratum,
      school_id = case_match(cycle,
        2000 ~ str_pad0(str_tail(cntschid, 3), 5),
        c(2003, 2006, 2009) ~ cntschid,
        2012 ~ str_tail(cntschid, 5),
        c(2015, 2018, 2022) ~ str_pad0(str_tail(cntschid, 4), 5),
        ),
      student_id = case_match(cycle,
        c(2000, 2003, 2006, 2009, 2012) ~ cntstuid,
        c(2015, 2018, 2022) ~ str_tail(cntstuid, 5),
        ),
      # PISA 2000 does not include a stratum column, but it is equal to the first two digits of the schoolid column;
      # in subsequent editions strata identifiers are unique across countries, so to match that expectation we
      # also include the country code
      stratum = default(stratum, str_c(economy_id, ': ', str_sub(cntschid, 1, 2))),
      # variables that have not been normalized yet but that we need for further processing
      subnatio = subnatio,
      lang_of_test = lang_of_test,
      )

  cli_progress_step('Harmonize regions')

  processed <- processed |>
    left_join(subnations, by=c('country_iso', 'cycle', 'subnatio'))

  # add missing subnation for Belgium in 2003
  processed <- processed |>
    mutate(subnation = ifelse(str_starts(stratum, fixed('Belgium (Flemish)')), 'Belgium: Flemish community', subnation)) |>
    mutate(subnation = ifelse(str_starts(stratum, fixed('Belgium (French)')), 'Belgium: French community', subnation))

  # create regions that are comparable from 2000 to 2022
  # and unique across the dataset (they include the country name)
  processed$region <- NA

  bel_german <- strata |> filter(region == 'Belgium: German community') |> pull(stratum)

  processed <- processed |>
    mutate(region=case_when(
      subnation == 'Belgium: Flemish community' ~ 'Belgium: Flemish community',
      # 2000
      subnation == 'Belgium: French community' ~ 'Belgium: French community',
      # 2003 onwards
      subnation == 'Belgium: French and German community' & cycle != 2018 & !(stratum %in% bel_german) ~ 'Belgium: French community',
      # 2018 (undisclosed strata)
      subnation == 'Belgium: French and German community' & cycle == 2018 & lang_of_test != 'German' ~ 'Belgium: French community',
      .default = region
    ))

  gbr_wales <- strata |> filter(region == 'United Kingdom: Wales') |> pull(stratum)
  processed <- processed |>
    mutate(region=case_when(
      subnation == 'United Kingdom: Scotland' ~ 'United Kingdom: Scotland',
      # 2000
      subnation == 'United Kingdom: England' | subnation == 'United Kingdom: Northern Ireland' ~ 'United Kingdom: England and Northern Ireland',
      # 2003 onwards
      subnation == 'United Kingdom: England, Wales and Northern Ireland' & !(stratum %in% gbr_wales) ~ 'United Kingdom: England and Northern Ireland',
      .default = region
    ))

  n_regions <- processed |> group_by(country_iso) |> summarize(n=length(unique(region))) |> deframe()
  get_n_regions <- partial(`[[`, n_regions)

  # `region` contains everything we've been able to harmonize thus far,
  # which is *not* all of the information that is available in `subnatio`
  processed <- processed |>
    mutate(region = if_else(map_int(country_iso, get_n_regions) > 1, region, economy)) |>
    mutate(region = if_else(is.na(region) & !is.na(country), str_c(country, ": rest of the country"), region))

  cli_progress_step('Create globally unique identifiers from partially unique identifiers')

  # add unique identifiers
  processed <- processed |>
    mutate(
      region_iso  = coalesce(subnation_to_iso[region], economy_iso),
      country_uid = str_c(cycle, country_iso, sep='/'),
      economy_uid = str_c(cycle, country_iso, economy_iso, sep='/'),
      region_uid  = str_c(cycle, country_iso, economy_iso, region_iso, sep='/'),
      stratum_uid = str_c(cycle, country_iso, economy_iso, region_iso, stratum_id, sep='/'),
      school_uid  = str_c(cycle, country_iso, economy_iso, region_iso, stratum_id, school_id, sep='/'),
      student_uid = str_c(cycle, country_iso, economy_iso, region_iso, stratum_id, school_id, student_id, sep='/')
    )

  # remove intermediates and helper variables
  processed |> mutate(
    subnatio = NULL,
    subnation = NULL,
    lang_of_test = NULL,
  )
}

verify <- function(raw, processed) {
  cli_progress_step('Verify extraction of countries and regions')

  # * there should be no missing country names or country isos
  # * economies should have proper names, not the names of their countries
  #   (check using the economies.csv list)

  #processed |> count(country, economy, economy_iso) |> view()
  #processed |> filter(country != economy) |> count(country, economy, economy_iso) |> view()

  # regions

  #processed |> count(country, region, economy_iso) |> view()

  # TODO: check whether every observation received a unique id, and verify that it is indeed unique
  # map(raw, function(df) sum(is.na(df$unique_id)))
  # clashes <- processed |> count(student_uid) |> filter(n > 1)
  # expect_equals(nrow(clashes), 0)

  expect_equal(n_distinct(processed$student_uid), nrow(processed))
}
