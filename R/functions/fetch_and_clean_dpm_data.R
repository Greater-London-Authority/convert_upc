source("R/functions/clean_dpm.R")

fetch_and_clean_dpm_data <- function(url_raw,
                                     fpath_raw,
                                     fpath_clean) {

  if(!dir.exists("data/raw/")) dir.create("data/raw/", recursive = TRUE)
  if(!dir.exists("data/intermediate/")) dir.create("data/intermediate/", recursive = TRUE)


  download.file(url = url_raw,
                destfile = fpath_raw,
                mode = "wb")

  dpm_data <- clean_dpm(fpath_raw)

  saveRDS(dpm_data, file = fpath_clean)
}
