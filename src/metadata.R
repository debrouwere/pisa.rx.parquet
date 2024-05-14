# * codebook with summary stats
# * codebook converted into binary presence/absence per country and assessments, making it easy to do
#   `filter(hisced >= 8)` -- or maybe more flexible so we can do `mutate(across(everything(), ~ .x >= 0.50) |> summarize(across(everything()), sum, .by='economy') |> filter(hisced >= 8) |> pull(economy)`
#   and then use that in a semi-join
# ** or perhaps we know which countries we care about and we want to get the coverage,
#    `filter(economy %in% economies_subset) |> summarize(across(c(hisced, hisei, escs)), ~ `
# * organizational membership so folks can do e.g. `filter(membership == 'European Union', accession <= 2000) |> pull(economy)`
#   and then use that in a semi-join; for now we'll stick to OECD and EU but of course we can add other supranational organizations later on
