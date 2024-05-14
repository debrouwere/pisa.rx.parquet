# reading literacy (2000, 2009, 2018):
# * cognitive
#   * access and retrieval
#   * integration and interpretation
#   * reflection and evaluation
# * text structure
#   * single
#   * multiple
#
# mathematics (2003, 2012, 2022):
# * content
#   * space and shape
#   * change and relationships
#   * uncertainty and data
#   * quantity
# * process
#   * employing mathematical concepts / facts / procedures
#   * formulating situations mathematically
#   * interpreting / applying / evaluating mathematical outcomes
#   * reasoning
#
# science (2006, 2015):
# * interest
#   * interest in science
#   * support for scientific inquiry
# * competency
#   * explain phenomena scientifically
#   * evaluate and design scientific enquiry / identify scientific issues
#   * use scientific evidence / interpret data and evidence scientifically
# * knowledge
#   * scientific content knowledge
#   * procedural and epistemic scientific knowledge
# * system
#   * physical
#   * living
#   * earth

# NOTE: I've chosen for long names, and for a structure that makes it easy to do
# analyses on combinations of subscales (e.g. `contains('math_process')` gets
# you all 40 plausible values); we can show how, with `dplyr`, it is easy to
# rename these into shorter variants if desired, e.g. by leaving out the
# prefixes

library('tidyverse')
library('testthat')

source('src/helpers.R')

description <- 'Reading, mathematics and science'

is_stable <- TRUE

columns <- tribble()

aliases_table <- read_csv('data/domains-by-year.csv')

# NOTE: if we want to stick to these long names, we'll probably
# also want to rename the weights and the sample fractions
aliases <- aliases_table |>
  select(all_of(as.character(CYCLES))) |>
  as.list() |>
  list_transpose() |>
  set_names(aliases_table$scale)

expand_suffix <- function(suffix, name, n=5) {
  names <- str_c('pv', 1:n, name)
  values <- str_c('pv', 1:n, suffix)
  set_names(values, names)
}

process <- function(raw, processed) {
  cli_progress_step('Harmonize column names of outcome scales and subscales')

  assessments <- imap(CYCLES, function(y, ix) {
    y_chr <- as.character(y)
    n <- if_else(y >= 2015, 10, 5)
    columns <- map(aliases, ix) |>
      discard(is.na) |>
      imap(expand_suffix, n=n) |>
      list_c()
    raw[[y_chr]] |> select(all_of(columns))
  })

  bind_rows(assessments)
}


verify <- function(raw, processed) {
  # TODO
}
