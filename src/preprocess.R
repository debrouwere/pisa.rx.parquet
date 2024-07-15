# Each preprocessor is expected to define the following variables:
#
# * description (chr):
#     a description of the kinds of columns that are being preprocessed, without reference to the
#     particular steps involved in the preprocessing (e.g. "Identifiers" instead of "Generate
#     # unique identifiers", "Demographics" instead of "Harmonization of age and gender")
# * columns (tibble):
#     `name`: exported column
#     `original_name`: the most similar column in the raw dataset, if applicable
#     `is_complete`: whether the new variable contains the same information as the old one, even if transformed
#     `is_exact`: whether creation of the harmonized variable involved any substantial guesses, imputed values,
#       opinionated choices etc. (we allow some leeway for very minor data munging)
#     `description`: if notable, a short description of the operations that were performed to harmonize the data
# * is_stable (logi):
#     stable preprocessors are those that (1) return columns for every
#     observation in the dataset and (2) return them in the original order, so
#     that we can just bind the columns together without having to check whether
#     the unique identifiers match (this is much faster than joining on a unique key)
# * process (fun):
#     a function with signature `process(raw, processed)` that returns harmonized columns;
#     it should not return existing columns, only those newly processed
# * verify (fun):
#     a function with signature `verify(raw, processed)` that checks whether the operations
#     performed in `process` had the expected effect, usually with the help of the {testthat}
#     package

options(readr.show_col_types = FALSE)

library('tidyverse', quietly = TRUE)
library('arrow', quietly = TRUE)
library('cli')

source('src/helpers.R')

CYCLES <- c(2000, 2003, 2006, 2009, 2012, 2015, 2018, 2022)

PISA_PATH <- '../pisa.parquet/build'

PV_PATTERN <- '^pv\\d+[a-z]+\\d?$'
REPLICATE_WEIGHTS_PATTERN <- '^w_(\\w+_)?FSTU?R(WT)?\\d+$'
WEIGHTS_PATTERN <- '^(w_|scweight|wnrschb)'

columns_by_assessment <- read_csv('data/columns-by-year.csv')

load <- function(cycles) {
  cli_progress_step('Load PISA datasets')

  map(cycles, function(year) {
    year <- as.character(year)
    assessment <- read_parquet(
      file = file.path(PISA_PATH, year, 'students.parquet'),
      col_select=c(
        na.omit(columns_by_assessment[[year]]),
        matches(PV_PATTERN),
        matches(WEIGHTS_PATTERN)
      )
    )
  }) |> set_names(cycles)
}

processed <- tibble()

preprocessors <- list(
  'identifiers',
  'outcomes',
  'weights',
  'sampling',
  'grade',
  'demographics',
  'parental-education',
  'parental-occupation'
)

# TODO: consider error recovery where, if an error is encountered,
# an intermediate .parquet file is written to file named `intermediate-{last_step}`,
# making it easier to bugfix preprocessors that are lower down on the list

cli_h1('Harmonize and merge PISA 2000-2022 datasets')

raw <- load(CYCLES)

# harmonize the identifiers before we run other preprocessors
cli_h3('Identifiers')
identifiers <- preprocessor('identifiers')
result <- identifiers$process(raw, processed)

# chicken and egg... backport identifiers to the raw data to make it easier
# to join preprocessed data together using the `student_uid` column
cli_progress_message('Make unique identifiers available to preprocessors')

uids <- result |>
  select(cycle, nth_cycle, country, economy, region, student_uid) |>
  group_by(cycle) |>
  group_split(.keep = TRUE)

# arrange raw and processed data by student_uid to ensure stable output when
# a preprocessor uses a `.by` grouped computation
raw <- pmap(list(raw, uids), function(df, ids) {
  df |> bind_cols(ids) |> arrange(student_uid)
})
processed <- result |> arrange(student_uid)

identifiers$verify(raw, processed)

cli_progress_done()



for (name in preprocessors[-1]) {
  ns <- preprocessor(name)
  cli_h3(ns$description)
  result <- ns$process(raw, processed)

  if (ns$is_stable) {
    processed <- bind_cols(select(processed, !any_of(colnames(result))), result)
  } else {
    processed <- left_join(processed, result, by = 'student_uid')
  }

  ns$verify(raw, processed)

  gc()
}

write_dataset(processed,
              path = 'build/pisa.rx',
              partitioning = c('cycle', 'country'),
              compression = 'zstd',
              compression_level = 10)
