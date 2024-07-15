library('tidyverse')
library('haven')
library('brr')

# the best comparisons between the new and old trended ESCS are 2012 and 2015:
# * 2018 introduced changes to how ESCS was computed
# * we don't have concurrent data for both the new and original index before 2012

escs12 <- read_sas("data/escs/2012/escs_2012.sas7bdat") |>
  transmute(
    cycle = 5,
    cnt = cnt,
    schoolid = as.integer(schoolid),
    studentid = as.integer(stidstd),
    escs = escs_trend
  )

hisei12 <- raw$`2012` |>
  select(country_iso, stidstd, schoolid, hisei) |>
  transmute(
    cycle = 5,
    cnt = country_iso,
    schoolid = as.integer(str_sub(schoolid, 3)),
    studentid = as.integer(stidstd),
    hisei = hisei,
  )

status12 <- full_join(escs12, hisei12, by = c('cycle', 'cnt', 'schoolid', 'studentid'))

nrow(status12)
nrow(hisei12)
nrow(escs12)

status15 <- raw$`2015` |>
  select(country_iso, cntstuid, cntschid, escs, hisei) |>
  transmute(
    cycle = 6,
    cnt = country_iso,
    schoolid = as.integer(str_sub(cntschid, 4)),
    studentid = as.integer(str_sub(cntstuid, 4)),
    escs = escs,
    hisei = hisei,
  )

trended <- bind_rows(status12, status15)

retrended <- read_csv('data/escs/2022/escs_trend.csv') |>
  filter(cycle %in% c(5, 6)) |>
  rename(escs = 'escs_trend', hisei = 'hisei_trend')

comparison <- full_join(trended, retrended, by = c('cycle', 'cnt', 'schoolid', 'studentid'), suffix = c('_prev', '_curr'))

nrow(trended)
nrow(retrended)
nrow(comparison)

write_parquet(comparison, 'build/calibration-escs.parquet', compression = 'zstd', compression_level = 10)

ex <- comparison |>
  drop_na() |>
  group_by(cycle, cnt) |>
  slice_head(n=100) |>
  ungroup()

plot(ex$escs_prev, ex$escs_curr)
abline(a = 0, b = 1, col = 'red')

# 98% correlation
escs_fit_ab <- lm(escs_curr ~ escs_prev, data=comparison)
summary(escs_fit_ab)
escs_fit_ab_coef <- coef(escs_fit_ab)
escs_fit_ab_corr <- sqrt(summary(escs_fit_ab)$r.squared)
escs_fit_ab_sigma <- summary(escs_fit_ab)$sigma

# a = -0.187283287132468
# s =  0.283049676562631
escs_fit_a <- lm(I(escs_curr - escs_prev) ~ 1, data=comparison)
summary(escs_fit_a)
escs_fit_a_coef <- coef(escs_fit_a)
escs_fit_a_corr <- NA
escs_fit_a_sigma <- summary(escs_fit_a)$sigma

escs_fit_a_sigma / escs_fit_ab_sigma

# compare between cycles
summary(lm(escs_curr ~ escs_prev, data=comparison[comparison$cycle == 5,]))
summary(lm(escs_curr ~ escs_prev, data=comparison[comparison$cycle == 6,]))




#### HISEI ####

plot(ex$hisei_prev, ex$hisei_curr)
abline(a = 0, b = 1, col = 'red')
abline(a = -0.09, b = 1, col = 'blue')

hisei_fit_ab <- lm(hisei_curr ~ hisei_prev, data = comparison)
summary(hisei_fit_ab)
hisei_fit_ab_coef <- coef(hisei_fit_ab)
hisei_fit_ab_corr <- sqrt(summary(hisei_fit_ab)$r.squared)
hisei_fit_ab_sigma <- summary(hisei_fit_ab)$sigma

# a = 0.0871992180632055
# s = 0.9326125052451850
hisei_fit_a <- lm(I(hisei_curr - hisei_prev) ~ 1, data = comparison)
summary(hisei_fit_a)
hisei_fit_a_coef <- coef(hisei_fit_a)
hisei_fit_a_corr <- sqrt(summary(hisei_fit_a)$r.squared)
hisei_fit_a_sigma <- summary(hisei_fit_a)$sigma

hisei_fit_a_sigma / hisei_fit_ab_sigma


