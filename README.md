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
install.packages('arrow')

library('tidyverse')
library('arrow')

# load the whole damn thing (not recommended)
pisa <- open_dataset('pisa.parquet', partitioning='country') %>% collect()

# preselect the data you are interested in
pisa2000 <- open_dataset('pisa.parquet', partitioning='country') %>%
  select(c(starts_with('pv'), starts_with('w_'), 'escs', 'grade', 'gender')) %>%
  filter(country == 'Belgium', year == 2000) %>%
  collect()
```

When working with large datasets in CSV or FWF format, it is common to read in the entire dataset even if you need only a handful of columns, which uses a lot of memory but avoids having to wait endless minutes while reading in the data yet again if you decide you need to include an additional column or two. However, reading in Parquet data is nearly instantaneous so you will work faster and use less memory if you preselect the data you need while reading it in.
