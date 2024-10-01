library(dplyr)
library(tidyr)
library(readxl)
library(readr)

source("R/functions/fetch_and_clean_dpm_data.R")
source("R/functions/split_gross_flows.R")
source("R/functions/fetch_and_clean_mye_data.R")

if(!dir.exists("data/raw/")) dir.create("data/raw/", recursive = TRUE)
if(!dir.exists("data/intermediate/")) dir.create("data/intermediate/", recursive = TRUE)
if(!dir.exists("data/processed/")) dir.create("data/processed/", recursive = TRUE)


# fetch and clean DPM data (mid-2011 to mid-2023 edition) if it hasn't already been downloaded
if(!file.exists("data/intermediate/dpm_2011_on(2023_geog).rds")) {

  fetch_and_clean_dpm_data(url_raw = "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/adminbasedpopulationestimatesforlocalauthoritiesinenglandandwales/mid2011tomid2023/abpe15072024.xlsx",
                           fpath_raw = "data/raw/abpe15072024.xlsx",
                           fpath_clean = "data/intermediate/dpm_2011_on(2023_geog).rds")
}

#2011-onward MYE
# fetch and clean mid-year estimate data if it hasn't already been downloaded

if(!file.exists("data/intermediate/mye_2011_on(2023_geog).rds")) {

  fetch_and_clean_mye_data(url_raw = "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/estimatesofthepopulationforenglandandwales/mid2011tomid2023detailedtimeserieseditionofthisdataset/myebtablesenglandwales20112023.xlsx",
                           fpath_raw = "data/raw/mye_2011_on(2023_geog).xlsx",
                           fpath_clean = "data/intermediate/mye_2011_on(2023_geog).rds",
                           sheet_name = "MYEB2")
}

#read and prep inputs

dpm_2011_on <- readRDS("data/intermediate/dpm_2011_on(2023_geog).rds")

mye_2011_on <- readRDS("data/intermediate/mye_2011_on(2023_geog).rds")

mye_inflows <- mye_2011_on %>%
  filter(year >= 2012) %>%
  filter(component %in% c("internal_in", "international_in")) %>%
  mutate(value = case_when(
    value < 0.5 ~ 0.5,
    TRUE ~ value
  )) %>%
  pivot_wider(names_from = "component", values_from = "value")

mye_outflows <- mye_2011_on %>%
  filter(year >= 2012) %>%
  mutate(value = case_when(
    value < 0.5 ~ 0.5,
    TRUE ~ value
  )) %>%
  filter(component %in% c("internal_out", "international_out")) %>%
  pivot_wider(names_from = "component", values_from = "value")

# model dpm flows

relative_international_confidence_inflow = 3
relative_international_confidence_outflow = 0.3

modelled_dpm_inflows <- dpm_2011_on %>%
  filter(component == "total_in") %>%
  rename(total_in = value) %>%
  select(-component) %>%
  left_join(mye_inflows, by = NULL) %>%
  mutate(model_flows = split_gross_flows(base_international = international_in,
                                         base_domestic = internal_in,
                                         target_total = total_in,
                                         relative_international_confidence = relative_international_confidence_inflow)) %>%
  unnest_wider(col = model_flows) %>%
  select(-c(international_in, internal_in, total_in)) %>%
  rename(international_in = new_international,
         internal_in = new_domestic) %>%
  pivot_longer(cols = c("international_in", "internal_in"),
               names_to = "component",
               values_to = "value")

modelled_dpm_outflows <- dpm_2011_on %>%
  filter(component == "total_out") %>%
  rename(total_out = value) %>%
  select(-component) %>%
  left_join(mye_outflows, by = NULL) %>%
  mutate(model_flows = split_gross_flows(base_international = international_out,
                                         base_domestic = internal_out,
                                         target_total = total_out,
                                         relative_international_confidence = relative_international_confidence_outflow)) %>%
  unnest_wider(col = model_flows) %>%
  select(-c(international_out, internal_out, total_out)) %>%
  rename(international_out = new_international,
         internal_out = new_domestic) %>%
  pivot_longer(cols = c("international_out", "internal_out"),
               names_to = "component",
               values_to = "value")

# add modelled flows to DPM series and save

modelled_dpm_netflows <- bind_rows(
  modelled_dpm_inflows,
  modelled_dpm_outflows
) %>%
  group_by(gss_code, gss_name, sex, age, year) %>%
  summarise(international_net = sum(value[component == "international_in"]) - sum(value[component == "international_out"]),
            internal_net = sum(value[component == "internal_in"]) - sum(value[component == "internal_out"]),
            .groups = "drop") %>%
  pivot_longer(cols = c("internal_net", "international_net"),
               names_to = "component", values_to = "value")

modelled_dpm <- bind_rows(dpm_2011_on,
                          modelled_dpm_inflows,
                          modelled_dpm_outflows,
                          modelled_dpm_netflows) %>%
  arrange(gss_code, component, year, sex, age)

saveRDS(modelled_dpm, "data/processed/new_dpm_series_2011_on.rds")

# create csv output in same general format as ONS published table

modelled_dpm_wide <- modelled_dpm %>%
  mutate(value = round(value, 4)) %>%
  mutate(component_year = paste0(component, "_", year)) %>%
  select(-c(component, year)) %>%
  pivot_wider(names_from = "component_year", values_from = "value") %>%
  arrange(gss_code, sex, age)

write_csv(modelled_dpm_wide,
          file = "data/processed/new_dpm_series_2011_on_wide.csv",
          na = "0")
