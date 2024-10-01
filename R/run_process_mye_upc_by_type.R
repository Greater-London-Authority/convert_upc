library(dplyr)
library(tidyr)
library(readxl)
library(readr)

source("R/functions/fetch_and_clean_mye_data.R")
source("R/functions/optimise_gross_flows.R")
source("R/functions/split_gross_flows.R")

if(!dir.exists("data/raw/")) dir.create("data/raw/", recursive = TRUE)
if(!dir.exists("data/intermediate/")) dir.create("data/intermediate/", recursive = TRUE)
if(!dir.exists("data/processed/")) dir.create("data/processed/", recursive = TRUE)

#2011-onward MYE

# fetch and clean mid-year estimate data if it hasn't already been done

if(!file.exists("data/intermediate/mye_2011_on(2023_geog).rds")) {

  fetch_and_clean_mye_data(url_raw = "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/estimatesofthepopulationforenglandandwales/mid2011tomid2023detailedtimeserieseditionofthisdataset/myebtablesenglandwales20112023.xlsx",
                           fpath_raw = "data/raw/mye_2011_on(2023_geog).xlsx",
                           fpath_clean = "data/intermediate/mye_2011_on(2023_geog).rds",
                           sheet_name = "MYEB2")
}

mye_2011_on <- readRDS("data/intermediate/mye_2011_on(2023_geog).rds")

# first step is to fit total in and out flows to the total net that includes the UPC component

mye_total_flows <- mye_2011_on %>%
  filter(year >= 2012) %>%
  group_by(gss_code, gss_name, sex, age, year) %>%
  summarise(base_in = sum(value[component == "international_in"]) + sum(value[component == "internal_in"]),
            base_out = sum(value[component == "international_out"]) + sum(value[component == "international_out"]),
            total_net = sum(value[component %in% c("international_net", "internal_net", "unattrib")]),
            .groups = "drop") %>%
  mutate(base_in  = pmax(base_in, 0.5)) %>%
  mutate(base_out  = pmax(base_out, 0.5))


modelled_total_flows <- mye_total_flows %>%
  mutate(model_flows = optimise_gross_flows(base_in, base_out, total_net)) %>%
  unnest_wider(col = model_flows) %>%
  select(-c(base_in, base_out)) %>%
  rename(total_in = inflow,
         total_out = outflow) %>%
  pivot_longer(cols = contains("total_"),
               names_to = "component",
               values_to = "value")

# the next step is to split the modelled total gross flows between international and domestic

# in this example shall just use blanket assumptions about the relative accuracy of
# the base flows by direction. programatically, it would be simple to apply these differently
# by age, sex, year, and location

relative_international_confidence_inflow = 0.8
relative_international_confidence_outflow = 0.3

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


modelled_inflows <- modelled_total_flows %>%
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

modelled_outflows <- modelled_total_flows %>%
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

#create new series by substituting modelled flows for original ones and UPC

modelled_netflows <- bind_rows(
  modelled_inflows,
  modelled_outflows
) %>%
  group_by(gss_code, gss_name, sex, age, year) %>%
  summarise(international_net = sum(value[component == "international_in"]) - sum(value[component == "international_out"]),
            internal_net = sum(value[component == "internal_in"]) - sum(value[component == "internal_out"]),
            .groups = "drop") %>%
  pivot_longer(cols = c("internal_net", "international_net"),
               names_to = "component", values_to = "value")

modelled_mye <- mye_2011_on %>%
  filter(!component %in% c("international_out", "internal_out",
                           "international_in", "internal_in",
                           "internal_net", "international_net",
                           "unattrib")) %>%
  bind_rows(modelled_total_flows,
            modelled_inflows,
            modelled_outflows,
            modelled_netflows) %>%
  arrange(gss_code, component, year, sex, age)

#save RDS file in tidy format

saveRDS(modelled_mye, "data/processed/modelled_mye_series_2011_on.rds")

# create csv output in same general format as ONS published table

new_mye_series_wide <- modelled_mye %>%
  mutate(value = round(value, 4)) %>%
  mutate(component_year = paste0(component, "_", year)) %>%
  select(-c(component, year)) %>%
  pivot_wider(names_from = "component_year", values_from = "value") %>%
  arrange(gss_code, sex, age)


write_csv(new_mye_series_wide,
          file = "data/processed/modelled_mye_series_2011_on_wide.csv",
          na = "0")
