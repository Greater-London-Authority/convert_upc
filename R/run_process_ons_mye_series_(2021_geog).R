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

# fetch and clean mid-year estimate data if it hasn't already been done

if(!file.exists("data/intermediate/mye_2011_on(2021_geog).rds")) {

  fetch_and_clean_mye_data(url_raw = "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/estimatesofthepopulationforenglandandwales/mid2011tomid2022detailedtimeseries/myebtablesenglandwales20112022v3.xlsx",
                           fpath_raw = "data/raw/myebtablesenglandwales20112022v3.xlsx",
                           fpath_clean = "data/intermediate/mye_2011_on(2021_geog).rds",
                           sheet_name = "MYEB2 (2021 Geography)")
}

mye_2011_on <- readRDS("data/intermediate/mye_2011_on(2021_geog).rds")

mye_international_total_net <- mye_2011_on %>%
  filter(between(year, 2012, 2021)) %>%
  group_by(gss_code, gss_name, sex, age, year) %>%
  summarise(base_in = sum(value[component == "international_in"]),
            base_out = sum(value[component == "international_out"]),
            total_net = sum(value[component %in% c("international_net", "unattrib")]),
            .groups = "drop") %>%
  mutate(base_in  = pmax(base_in, 0.5)) %>%
  mutate(base_out  = pmax(base_out, 0.5))

mye_2022_on <- mye_2011_on %>%
  filter(year >= 2022)

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
  bind_rows(modelled_international_flows) %>%
  filter(year < 2022) %>%
  bind_rows(mye_2022_on) %>%
  arrange(gss_code, component, year, sex, age)

#save RDS file in tidy format

saveRDS(new_mye_series, "data/processed/new_mye_series_2011_on(2021_geog).rds")

# create csv output in same general format as ONS published table

new_mye_series_wide <- new_mye_series %>%
  mutate(value = round(value, 4)) %>%
  mutate(component_year = paste0(component, "_", year)) %>%
  select(-c(component, year)) %>%
  pivot_wider(names_from = "component_year", values_from = "value") %>%
  arrange(gss_code, sex, age)


write_csv(new_mye_series_wide,
          file = "data/processed/new_mye_series_2011_on_(2021_geog)wide.csv",
          na = "0")
