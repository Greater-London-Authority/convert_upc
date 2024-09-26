library(dplyr)
library(tidyr)
library(readxl)
library(readr)

source("R/functions/fetch_and_clean_mye_data.R")
source("R/functions/optimise_gross_flows.R")

if(!dir.exists("data/raw/")) dir.create("data/raw/", recursive = TRUE)
if(!dir.exists("data/intermediate/")) dir.create("data/intermediate/", recursive = TRUE)
if(!dir.exists("data/processed/")) dir.create("data/processed/", recursive = TRUE)

#2011-onward MYE

# fetch and clean mid-year estimate data

fetch_and_clean_mye_data(url_raw = "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/estimatesofthepopulationforenglandandwales/mid2011tomid2023detailedtimeserieseditionofthisdataset/myebtablesenglandwales20112023.xlsx",
                         fpath_raw = "data/raw/mye_2011_on(2023_geog).xlsx",
                         fpath_clean = "data/intermediate/mye_2011_on(2023_geog).rds",
                         sheet_name = "MYEB2")

mye_2011_on <- readRDS("data/intermediate/mye_2011_on(2023_geog).rds")

mye_international_total_net <- mye_2011_on %>%
  group_by(gss_code, gss_name, sex, age, year) %>%
  summarise(base_in = sum(value[component == "international_in"]),
            base_out = sum(value[component == "international_out"]),
            total_net = sum(value[component %in% c("international_net", "unattrib")]),
            .groups = "drop")


# take new international net to be original international net estimate + unattrib
# fit new international gross flows consistent with this new international net

modelled_international_flows <- mye_international_total_net %>%
  mutate(model_flows = optimise_gross_flows(base_in, base_out, total_net)) %>%
  unnest_wider(col = model_flows) %>%
  select(-c(base_in, base_out)) %>%
  rename(international_in = inflow,
         international_out = outflow,
         international_net = total_net) %>%
  pivot_longer(cols = contains("international"),
               names_to = "component",
               values_to = "value")


#create new series by substituting modelled international flows for original and unattib

new_mye_series <- mye_2011_on %>%
  filter(!component %in% c("international_in",
                           "international_out",
                           "international_net",
                           "unattrib")) %>%
  bind_rows(modelled_international_flows)

#save RDS file in tidy format

saveRDS(new_mye_series, "data/processed/new_mye_series_2011_on.rds")

# create csv output in same general format as ONS published table

new_mye_series_wide <- new_mye_series %>%
  mutate(component_year = paste0(component, "_", year)) %>%
  select(-c(component, year)) %>%
  pivot_wider(names_from = "component_year", values_from = "value")


write_csv(new_mye_series_wide,
        "data/processed/new_mye_series_2011_on_wide.csv")
