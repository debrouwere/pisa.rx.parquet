# v2 of impute.R
# changes are mostly limited to the `process_region` function

library("tidyverse")
library("arrow")
library("parallel")
library("optparse")

# multithreaded parquet reads in a multithreaded script is asking for trouble
options(arrow.use_threads = FALSE)

domains <- read_csv('build/domains.csv')

SCALES <- list(
  LONG = domains |> pull(scale) |> unique(),
  WIDE = domains |>
    group_by(scale) |>
    summarize(m = max(pvs)) |>
    mutate(pattern = str_c('pv{1:', m, '}', scale)) |>
    pull(pattern) |>
    map(\(pattern) str_glue(pattern)) |>
    list_c()
)

process <- function(part, group, quality = 50, impute = TRUE) {
  print(str_glue("pivoting {part$filename}"))

  # because pisa.rx is a cross-cycle dataset, even e.g. the 2000 dataset will
  # contain columns like `pv10literacy`, which will be full of NAs; we filter
  # these out of the long format dataset by requiring that i <= m
  m <- part$imputations

  wide <- read_parquet(part$source)
  long <- wide |>
    pivot_longer(all_of(SCALES$WIDE),
      names_pattern = 'pv(\\d+)(.+)',
      names_to = c('i', '.value'),
      names_transform = list(i = as.integer)
    ) |>
    filter(i <= {{ m }}) |>
    arrange(i)

  if (!dir.exists(dirname(part$destination))) dir.create(dirname(part$destination), recursive = TRUE)
  write_parquet(long, part$destination, compression = 'zstd', compression_level = 10)

  rm(wide, long)
}

main <- function(source, destination, nnodes, limit, safe, help) {
  parts <- tibble(source = Sys.glob(file.path(source, '*/*/part-0.parquet'))) |>
    mutate(
      filename = str_sub(source, str_length(source) + 2),
      destination = file.path({{ destination }}, filename),
      cycle = as.integer(str_match(filename, 'cycle=(\\d+)/.+')[,2]),
      imputations = if_else(cycle >= 2015, 10, 5),
    )

  chunks <- list_transpose(as.list(parts), simplify = FALSE)

  if (limit > 0) chunks <- head(chunks, n = limit)
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
  add_option(c("-s", "--safe"), action="store_true", default=FALSE)

args <- parse_args2(parser)
args$options$source <- args$args[1]
args$options$destination <- args$args[2]
do.call(main, args$options)
