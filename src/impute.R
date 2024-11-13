library("tidyverse")
library("arrow")
library("mice")
library("parallel")
library("optparse")

SEED <- 1

coverage <- read_csv('build/coverage.csv') |>
  pivot_longer(-c(cycle, country, economy, region, .by), names_to = 'variable', values_to = 'coverage')
coverage$.by <- NULL

# paredint
isced_to_years <- read_csv('data/isced/2018-isced-to-years.csv') |>
  pivot_longer(starts_with('ISCED'), names_to='hisced', values_to='pared') |>
  group_by(hisced) |>
  summarize(parental_education = median(pared, na.rm = TRUE)) |>
  rename(highest_isced = hisced)

# pared
# isced_to_years_by_area <- open_dataset('build/pisa.rx') |>
#   filter(cycle == 2003) |>
#   select(economy, region, highest_isced, parental_education_by_country) |>
#   collect() |>
#   group_by(economy, region, highest_isced) |>
#   summarize(parental_education_by_country = median(parental_education_by_country, na.rm = TRUE)) |>
#   ungroup()
#
# write_csv(isced_to_years_by_area, 'build/2003-isced-to-years-by-region.csv')

isced_to_years_by_area <- read_csv('build/2003-isced-to-years-by-region.csv')

parts <- tibble(source = Sys.glob('build/pisa.rx/*/*/part-0.parquet')) |>
  mutate(
    filename = str_remove(source, 'build/pisa.rx/'),
    destination = file.path('build/imputations', filename),
    cycle = as.integer(str_match(filename, 'cycle=(\\d+)/.+')[,2]),
    imputations = if_else(cycle >= 2015, 10, 5),
    )

# a subset of identifiers
IDENTIFIERS <- c('economy', 'region')

SCALES <- read_csv('build/domains.csv') |>
  group_by(scale) |>
  summarize(m = max(pvs)) |>
  mutate(pattern = str_c('pv{1:', m, '}', scale)) |>
  pull(pattern) |>
  map(\(pattern) str_glue(pattern)) |>
  list_c()

COVARIATES <- c(
  'grade_lead',
  'age',
  'sex',
  'immigrant_generation',
  'speaks_test_language_at_home',
  'mothers_isced',
  'fathers_isced',
  'escs'
  )

# TODO: reuse code from the preprocessors for these, ideally
# in the form of functions we can source
DERIVED_COVARIATES <- c(
  'grade_lag',
  'highest_isced',
  # we get a calibrated HISEI from official retrended PISA data,
  # so in a lot of cases we do have HISEI but not father's or mother's
  # ISEI, so for our purposes this isn't really a derived variable
  # 'highest_isei',
  'parental_education',
  'parental_education_by_country'
  )

# sketch of how this should work (per cycle and country)
# (we should also have a filter, possibly based on `coverage.csv`,
# to exclude certain variables from the imputation if their coverage
# is 0)
impute <- function(data, m = 5, seed = NULL) {
  imputations <- mice(data, m = m, seed = seed)
  complete(imputations, action = "long")
}

# compute derived variables: grade_lag, highest_isced, parental_education
# (paredint), parental_education_by_country (pared)
#
# TODO: verify that these derivations work without issue even when
# the entire column consists of NA
derive <- function(data) {
  data |> mutate(
    grade_lag = -grade_lead,
    highest_isced = pmax(mothers_isced, fathers_isced, na.rm = TRUE)
  ) |>
  left_join(isced_to_years, by = 'highest_isced') |>
  left_join(isced_to_years_by_area, by = c('economy', 'region', 'highest_isced'))
}

# e.g. filter(coverage, cycle == 2015, region == 'Belgium: Flemish community', coverage >= 0.50) |> pull(variable) |> intersect(COVARIATES)
process <- function(part, group, quality) {
  print(str_glue("imputing {part$filename}"))

  observed <- read_parquet(part$source, col_select = any_of(c(IDENTIFIERS, SCALES, COVARIATES)))

  m <- part$imputations
  cycle <- part$cycle
  region <- first(observed$region)
  economy <- first(observed$economy)
  min_coverage <- quality / 100

  # because pisa.rx is a cross-cycle dataset, even e.g. the 2000 dataset will contain columns
  # like `pv10literacy`, which will be full of NAs; we filter these out of the long format
  # dataset by requiring that i <= m
  #
  # note that `.imp` is an actual column name whereas `.value` is a sentinel that
  # enables partial pivoting
  outcomes_by_i <- observed |>
    select(all_of(c(IDENTIFIERS, SCALES))) |>
    mutate(.id = row_number()) |>
    pivot_longer(all_of(SCALES),
                 names_pattern = 'pv(\\d+)(.+)',
                 names_to = c('.imp', '.value'),
                 names_transform = list(.imp = as.integer)
                 ) |>
    filter(.imp <= {{ m }}) |>
    arrange(.imp)

  # TODO: even if we are not imputing certain colums, we still want to retain them in the data!
  impute_cols <- coverage |>
    filter(cycle == {{ cycle }}, region == {{ region }}, coverage >= {{ min_coverage }}) |>
    pull(variable) |>
    intersect(COVARIATES)
  skipped_cols <- setdiff(COVARIATES, impute_cols)

  print(str_flatten(c('* skipping ', str_flatten_comma(skipped_cols), ' (more than ', 100 - quality, '% is missing)')))

  covariates_by_i <- if (length(impute_cols)) {
    impute(select(observed, all_of(impute_cols)), m = part$imputations, seed = SEED)
  } else {
    tibble()
  }

  skipped_by_i <- rep(NA, length(skipped_cols)) |>
    set_names(skipped_cols) |>
    as_tibble_row()

  print('* computing derived columns')

  all_covariates_by_i <- covariates_by_i |>
    bind_cols(skipped_by_i, economy = economy, region = region) |>
    derive()

  print('* binding outcomes and covariates')

  # we select all columns to ensure a consistent column order across dataset parts,
  # and to get rid of intermediate columns like .imp and .id
  imputed <- outcomes_by_i |>
    select(-c(economy, region, .id, .imp)) |>
    bind_cols(all_covariates_by_i) |>
    rename(i = '.imp') |>
    select(i, any_of(c(IDENTIFIERS, SCALES, COVARIATES, DERIVED_COVARIATES)))

  print('* writing to disk')

  if (!dir.exists(dirname(part$destination))) dir.create(dirname(part$destination), recursive = TRUE)
  write_parquet(imputed, part$destination, compression = 'zstd', compression_level = 10)
}

main <- function(nnodes, limit, safe, quality, help) {
  chunks <- list_transpose(as.list(parts), simplify = FALSE)

  if (limit > 0) {
    chunks <- head(chunks, n = limit)
  }

  process <- partial(process, quality = quality)

  if (safe) process <- safely(process)

  sink <- if (nnodes > 1) {
    cl <- makeForkCluster(nnodes = nnodes, outfile = "")
    parLapplyLB(
      cl = cl,
      X = chunks,
      fun = process
    )
  } else {
      lapply(
        X = chunks,
        FUN = process
      )
  }
}

parser <- OptionParser() |>
  add_option(c("-n", "--nnodes"), type="integer", default=2) |>
  add_option(c("-l", "--limit"), type="integer", default=0) |>
  add_option(c("-q", "--quality"), type="integer", default=50) |>
  add_option(c("-s", "--safe"), action="store_true", default=FALSE)

args <- parse_args2(parser)
do.call(main, args$options)

# verification
# observed <- read_parquet('build/pisa.rx/cycle=2000/country=Albania/part-0.parquet', col_select = COVARIATES)
# imputed <- read_parquet('build/imputations/cycle=2000/country=Albania/part-0.parquet')
# nrow(imputed) / nrow(observed)
# observed |> slice(2)
# imputed |> group_by(i) |> slice(2) |> ungroup()
