# Author: Jeremy Boyd (jeremyboyd@pm.me)
# Description: Function that takes a station ID and min date as input and
# returns various weather timeseries for the station from min date, plus a table
# of flags for the timeseries. For more info on data characteristics, including
# definitions and unit measurements, see
# https://www1.ncdc.noaa.gov/pub/data/ghcn/daily/readme.txt.

# Resources
library(tidyverse)
library(rnoaa)
library(padr)
library(lubridate)

# Get info on all GHCND (Global historical climatology network-daily) weather stations
# station_info <- ghcnd_stations()

# # Summary of the types of data, date ranges available from Snowbird station
# station_info %>% filter(id == "USS0011J42S")

# Snowbird station
# station_id <- "USS0011J42S"
# min_date <- "1980-01-01"

# Function definition
get_station_data <- function(station_id, min_date) {
    
    # Need to run this to refresh cached data
    ghcnd_search(stationid = station_id,
                 date_min = min_date,
                 var = "all",
                 refresh = TRUE)
    
    # Get tidy version of data. This is accessing the cached data from
    # ghcnd_search().
    df <- meteo_tidy_ghcnd(stationid = station_id,
                           keep_flags = TRUE,
                           var = "all",
                           date_min = min_date)
    
    # Flag data
    flags <- df %>% select(id, date, matches("flag_"))
    
    # Number of measurements from the station
    n_measures <- sum(!str_detect(names(df), "id|date|flag"))
    
    # Clean up
    df2 <- df %>%
        
        # Drop flags
        select(!matches("flag")) %>%
        
        # Drop rows where all measurements are missing
        # Is there a way to do the column select in c_across without having to
        # know variable names?
        mutate(n_measures = n_measures) %>%
        rowwise() %>%
        mutate(n_missing = sum(is.na(c_across(prcp:wesd)))) %>%
        ungroup() %>%
        filter(n_missing != n_measures) %>%
        
        # Make all data cols numeric
        mutate(across(.cols = -matches("id|date"), as.numeric)) %>%

        # Precip is in tenths of mm and temps are in tenths of degree C, so
        # convert to mm and degrees C, respectively.
        mutate(across(.c = matches("prcp|^t"), ~ .x / 10))
    
    # Add padding so that every day from start to end of series has a row
    df3 <- df2 %>%
        pad(interval = "day") %>%
        
        # Recompute n_missing. This will tell us how many padded rows there are
        rowwise() %>%
        mutate(n_missing = sum(is.na(c_across(prcp:wesd)))) %>%
        ungroup() %>%
        select(-n_measures) %>%
        mutate(n_measures = n_measures)
    
    # Tell user how much padding is added. This helps to evaluate data quality
    message(paste("Padding rows added:",
                  nrow(filter(df3, n_missing == n_measures))))
    
    # Drop extra columns
    df4 <- df3 %>% select(-c(n_missing, n_measures))
    
    # Return list of dataframes
    return(list(data = df4,
                flags = flags)
           )
}
