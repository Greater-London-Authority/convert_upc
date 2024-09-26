
<!-- README.md is generated from README.Rmd. Please edit that file -->

# convert_upc

This is an example of how the Unattributable Population Change (UPC)
component included in the rebased ONS population back series could be
replaced with adjustments to the existing annual international migration
estimates.

The method shown here uses a single function that takes an initial pair
gross flows, together with a target net value, and returns new gross
flows that are consistent with this net figure and represent the minimum
‘cost’ change to the original flows.

This function was originally developed by the GLA in its process for
creating the [rebased population
estimates](https://data.london.gov.uk/dataset/modelled-population-backseries)
used as a basis for the GLA’s population projections.

The full GLA rebasing process is complex and involves fitting new annual
net flows before splitting these out into gross flows and building a
consistent annual population series.

However, if the goal is just to reassign already calculated UPC to
international flows, without modifying the estimated population, then
the process is greatly simplified.

## Instructions

The entire process is run from the script
*R/run_process_ons2023_mye_series.R*

This will:

- Fetch and clean the detailed mid-year estimates series published by
  ONS that covers the period 2011 to 2023
- Create modelled alternative annual international gross flows that are
  consistent with the sum of the international_net and UPC components
- Write out the new series to *data/processed/* as both an RDS file in
  tidy format and as a csv in a similar format to that originally
  published by ONS

## Required packages

dplyr, tidyr, readxl, readr, stringr
