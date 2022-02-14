# Author: Jeremy Boyd (jeremyboyd@pm.me)
# Description: Function that takes a buoy ID as input and returns all available
# mean daily wave heights from the buoy.

# Resources
library(tidyverse)
library(rvest)
library(R.utils)
library(rnoaa)
library(lubridate)
library(padr)
library(purrr)

# Get station info
# x <- buoy_stations(refresh = TRUE)

# buoy_id <- "51101"

# Table with URLs for buoys with standard meteorological data
stdmet_buoys <- buoys(dataset = "stdmet") %>%
    as_tibble()

# Function definition
get_buoy_data <- function(buoy_id) {
    
    # URL for selected buoy
    buoy_url <- stdmet_buoys %>%
        filter(id == buoy_id) %>%
        pull(url)
    
    # Years that data is available
    years <- read_html(buoy_url) %>%
        html_nodes("a tt") %>%
        xml_text() %>%
        as_tibble() %>%
        filter(str_detect(value, "h[0-9]+")) %>%
        pull(value) %>%
        str_extract("h[0-9]+") %>%
        str_remove("h")
    
    # User message
    message(paste("Collecting data from",
                  length(years),
                  "files..."))
    
    # Get data for all years
    df <- map_dfr(years, function(year) {
        
        # Get data
        df1 <- buoy(dataset = "stdmet",
                    buoyid = buoy_id,
                    year = year)
        
        # Missing value for wave height
        wave_height_na <- df1$meta$wave_height$missval
        
        # Clean up
        df1$data %>%
            mutate(time = ymd_hms(time),
                   wave_height = if_else(wave_height == wave_height_na,
                                         NA_real_,
                                         wave_height),
                   buoy_id = buoy_id,
                   year_file = year) %>%
            select(buoy_id, year_file, time:lon, wvht = wave_height)
    })
    
    # Drop duplicate times
    df2 <- df %>%
        group_by(buoy_id, time) %>%
        filter(year_file == max(as.integer(year_file))) %>%
        ungroup() %>%
        arrange(time) %>%
        
        # Thicken to day and compute day means
        thicken(interval = "day") %>%
        group_by(buoy_id, time_day) %>%
        summarize(wvht = mean(wvht, na.rm = TRUE),
                  .groups = "drop") %>%
        rename(date = time_day) %>%
        filter(!is.na(wvht))
    
    # Add padding
    df3 <- df2 %>%
        pad(interval = "day")
    
    # Tell user how much padding has been added. This helps to evaluate data
    # quality.
    message(paste("Added",
                  nrow(filter(df3, is.na(wvht))),
                  "padding rows."))
    
    # Return this
    return(df3)
}
