library(tidyr)
library(dplyr)
library(readxl)
library(stringr)

clean_dpm <- function(fpath_raw) {

  population_df <- read_excel(path = fpath_raw,
                              sheet = "1",
                              skip = 7,
                              col_names = c("gss_code", "gss_name", "year", "sex",
                                            "age", "value", "lower_ci", "upper_ci")) %>%
    mutate(age = as.numeric(str_extract(age, "[0-9]+"))) %>%
    select(-c(lower_ci, upper_ci)) %>%
    mutate(component = "population")

  births_df <- read_excel(path = fpath_raw,
                          sheet = "2",
                          skip = 6,
                          col_names = c("gss_code", "gss_name", "year", "sex", "value")) %>%
    mutate(component = "births") %>%
    mutate(age = 0)

  deaths_df <- read_excel(path = fpath_raw,
                              sheet = "3",
                              skip = 6,
                              col_names = c("gss_code", "gss_name", "year", "sex",
                                            "age", "value")) %>%
    mutate(age = as.numeric(str_extract(age, "[0-9]+"))) %>%
    mutate(component = "deaths")

  total_out_df <- read_excel(path = fpath_raw,
                              sheet = "4",
                              skip = 7,
                              col_names = c("gss_code", "gss_name", "year", "sex",
                                            "age", "value", "lower_ci", "upper_ci")) %>%
    mutate(age = as.numeric(str_extract(age, "[0-9]+"))) %>%
    select(-c(lower_ci, upper_ci)) %>%
    mutate(component = "total_out")

  total_in_df <- read_excel(path = fpath_raw,
                             sheet = "5",
                             skip = 7,
                             col_names = c("gss_code", "gss_name", "year", "sex",
                                           "age", "value", "lower_ci", "upper_ci")) %>%
    mutate(age = as.numeric(str_extract(age, "[0-9]+"))) %>%
    select(-c(lower_ci, upper_ci)) %>%
    mutate(component = "total_in")


  out_df <- bind_rows(
    population_df,
    births_df,
    deaths_df,
    total_out_df,
    total_in_df
  ) %>%
    mutate(sex = recode(sex,
                        "Female" = "female",
                        "Male" = "male"))

  return(out_df)
}
