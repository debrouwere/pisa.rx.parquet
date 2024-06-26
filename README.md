# pisa.rx.parquet

The Programme for International Student Assessment (PISA) is a large-scale educational test of students' aptitude in mathematics, science and reading literacy, administered worldwide to 15 year old students every three years and coordinated by the Organisation for Economic Co-operation and Development (OECD).

The design of the PISA questionnaires and cognitive tests allows for comparisons across time, but this is not straightforward because the same question will not necessarily have the same column name in every cycle, factor levels are often worded differently, what is supposed to be the same numerical variable across cycles may not always be on the same scale, and so on. `pisa.rx.parquet` harmonizes the 2000-2022 PISA datasets, and makes them available as a Parquet dataset.


### Features

Convenient:

* fast reads: because Parquet stores and compresses data column by column, reading in a selection of columns is extremely fast
* descriptive column names, e.g. `highest_parental_education` instead of `paredint` or `st01q01`
* human-readable factor levels, e.g. `Second-Generation` instead of `2`

Uniform:

* stable country, economy and region identifiers across cycles, very useful when merging with external datasets (e.g. gdp, social spending, educational spending by country)
* uniform names for scales, subscales, weights and other key variables
* separate student weights for literacy, math and science to make the weights of later cycles compatible with PISA 2000
* harmonization of (a subset of) questionnaire items related to student demographics, parents and learning progress

Reliable:

* separation of sentinel values (valid skip, not reached, not applicable, invalid, non response, system missing) into a separate dataset so they are never accidentally treated as real data
* harmonization code is available for review, mostly tested and mostly documented
* columns that have not been harmonized (yet) are excluded from the dataset, which avoids analysis of incomparable data

### Usage

```r
install.packages("arrow")

library("tidyverse")
library("arrow")

# load the whole damn thing (not recommended)
pisa <- open_dataset("build/pisa.rx") |> collect()

# preselect the data you are interested in
pisa2000 <- open_dataset("build/pisa.rx") |> 
  select(c(starts_with("pv"), starts_with("w_"), "escs", "grade", "gender")) |> 
  filter(country == "Belgium", cycle == 2000) |> 
  collect()
```

When working with large datasets in CSV or FWF format, it is common to read in the entire dataset even if you need only a handful of columns, which uses a lot of memory but avoids having to wait endless minutes while reading in the data yet again if you decide you need to include an additional column or two. However, reading in Parquet data is nearly instantaneous so you will work faster and use less memory if you preselect the data you need while reading it in.

### Subsets of the data

Very often, scholars do not work with the entire PISA dataset but limit themselves to a particular set of countries, either because those countries are in a particular part of the world that they are interested in (e.g. Europe) or because they have sufficient coverage (i.e. non-`NA` values) for the variables that they are interested in. For simple cases, this is as easy as:

```r
assessments <- open_dataset("build/pisa.rx") |>
  filter(country_iso %in% c("NLD", "BEL", "LUX")) |> 
  collect()
```

We also provide more advanced filtering with the help of metadata tables that contain additional information about countries and cycles that is not a part of the main dataset. Currently we provide two such tables: `memberships.csv` and `coverage.csv`. These tables can be used as a key with which to subset the main dataset, passed on to `dplyr::semi_join`. (Of course they can also be used for exploration, for example to see whether there is a sufficient amount of countries with coverage of the variables that you are interested in, or vice versa, to see what variables are covered for your countries of interest.)

Arrow and Parquet have native support for semi joins, which means that rows are filtered on the fly. This saves time and memory because we never read rows into memory that we don't need.

**Consider only current member countries that joined the European Union before or during 2000.**

```r
memberships <- read_csv("data/memberships.csv")
is_eu27 <- memberships |> 
  filter(organization == "European Union", since <= 2000, is.na(until))
assessments <- open_dataset("build/pisa.rx") |>
  semi_join(is_eu27, by = "country_iso") |> 
  select(cycle, country, starts_with("pv"), starts_with("w_")) |> 
  collect()
```

**Find countries that have at least 50% non-`NA` values for `speaks_test_language_at_home` in every cycle**

```r
coverage <- read_csv("build/coverage.csv")
usable_countries <- coverage |>
  mutate(across(everything(), min), .by = "country") |>
  filter(speaks_test_language_at_home >= 0.5)

assessments <- open_dataset("build/pisa.rx") |>
  semi_join(usable_countries, by = c("cycle", "country")) |> 
  select(cycle, country, starts_with("pv"), starts_with("w_")) |> 
  collect()
```

**Find countries that have 50% non-`NA` values for `speaks_test_language_at_home` for at least 6 out of 8 cycles**

```r
coverage <- read_csv("build/coverage.csv")
usable_countries <- coverage |>
  filter(speaks_test_language_at_home >= 0.5) |>
  count(country, region) |>
  summarize(n = min(n), .by = "country") |>
  filter(n >= 6)

assessments <- open_dataset("build/pisa.rx") |>
  semi_join(usable_countries, by = c("cycle", "country")) |> 
  select(cycle, country, starts_with("pv"), starts_with("w_")) |> 
  collect()
```

(This last example needs an extra `summarize` operation in order to calculate by region and then summarize down to the country level, otherwise countries with multiple regions would get counted more than once.)
