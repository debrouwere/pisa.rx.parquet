# time spent on homework, amount of school periods for math/scie/read, effort, ...

library('tidyverse')
library('testthat')

source('src/helpers.R')


# TODO: for most years, in-class learning time is specified in minutes but
# for 2022 it is instead specified in class periods, so this must be combined
# with the school dataset where each school reports how many minutes are
# in a class period


# `class_learning_time_literacy` `class_learning_time_math` `class_learning_time_science`
# `class_learning_time` (total)
#
# (this is in-class, some but maybe not all editions also have information on
# time spent on homework or total learning time at home; if we include this, I
# think it would make sense to have variable names such as
# `class_learning_time_math`, `home_learning_time_math`, `homework_time_math`)


# TODO: mmins for 2006
# 0-99
# 100-199
# 200-299

# BASIC METHOD: for each level in 2006, create an ECDF from mmins in 2003
# and then generate random numbers to get a realistic spread of possible values within that level;
# this will be noisy but unbiased (alternatively, could also do a tree model based on all possible predictors,
# and preferably also use both 2003 and 2009 data)

# this is a little bit weird in a Belgian context, but for PISA, an hour of instruction
# must represent a full 60 minutes, so so 5 blocks of math instruction is equal to 4 hours, not 5
# (with 50-minute cutpoints, the imputed values for mmins are very far away from those of
# PISA 2003 and PISA 2009)

description <- 'Time spent in class'

is_stable <- FALSE

columns <- tribble()

process <- function(raw, processed) {

}

mmins <- pisa2003 |> filter(country_iso == 'BEL') |> select(mmins)
ref00 <- mmins |> filter(mmins <= 30) |> pull(mmins) |> ecdf()
ref12 <- mmins |> filter(mmins > 59, mmins <= 119) |> pull(mmins) |> ecdf()
ref34 <- mmins |> filter(mmins > 119, mmins <= 239) |> pull(mmins) |> ecdf()
ref56 <- mmins |> filter(mmins > 239) |> pull(mmins) |> ecdf()

n <- table(pisa2006[pisa2006$country_iso == 'BEL', 'st31q04'])

st31q04 <- pisa2006$st31q04
levels(st31q04) <- c(levels(st31q04), '(NA)')
st31q04 <- replace_na(st31q04, '(NA)')

pisa2006$st31q04 <- NA
pisa2006[(pisa2006$country_iso == 'BEL') & (st31q04 == names(n)[1]), 'st31q04'] <- quantile(ref00, runif(n[1]))
pisa2006[(pisa2006$country_iso == 'BEL') & (st31q04 == names(n)[2]), 'st31q04'] <- quantile(ref12, runif(n[2]))
pisa2006[(pisa2006$country_iso == 'BEL') & (st31q04 == names(n)[3]), 'st31q04'] <- quantile(ref34, runif(n[3]))
pisa2006[(pisa2006$country_iso == 'BEL') & (st31q04 == names(n)[4]), 'st31q04'] <- quantile(ref56, runif(n[4]))

# sanity checks for mmins
mmins_to_st31q04_2003 <- cut(pisa2003$mmins, breaks=c(0, 25, 100, 200, 300, 600), right=FALSE)
prop.table(table(mmins_to_st31q04_2003))
prop.table(table(pisa2006$st31q04))

summary(pisa2000[pisa2000$country_iso == 'BEL', ]$mmins)
summary(pisa2003[pisa2003$country_iso == 'BEL', ]$mmins)
summary(pisa2006[pisa2006$country_iso == 'BEL', ]$st31q04)
summary(pisa2009[pisa2009$country_iso == 'BEL', ]$mmins)
