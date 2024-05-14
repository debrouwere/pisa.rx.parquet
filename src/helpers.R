library('tidyverse')

CYCLES <- c(2000, 2003, 2006, 2009, 2012, 2015, 2018, 2022)

space <- function(file) {
  env <- new.env()
  sys.source(file, envir = env)
  env
}

preprocessor <- function(name) {
  file <- file.path('src', 'columns', str_c(name, '.R'))
  space(file)
}

default <- function(x, missing) {
  if_else(is.na(x), missing, x)
}

columns_by_assessment <- read_csv('data/columns-by-year.csv')

aliases <- map(as.character(CYCLES), function(assessment) {
  mapping <- as.list(columns_by_assessment[[assessment]])
  names(mapping) <- columns_by_assessment[['name']]
  mapping
})

names(aliases) <- as.character(CYCLES)

across_cycles <- function(cycles, aliased_selection) {
  imap(cycles, function(data, cycle)  {
    variables <- map_chr(aliased_selection, function(var) {
      alias <- aliases[[cycle]][[var]]
      if (is.null(alias) || is.na(alias)) { var } else { alias }
    })
    names(variables) <- aliased_selection
    data |> select(any_of(variables))
  })
}
