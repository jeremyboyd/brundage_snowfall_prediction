# Author: Jeremy Boyd (jeremyboyd@pm.me)
# Description: Simple LSTM model of buoy data predicting Brundage snowfall.

# Resources
library(tidyverse)
library(feather)
library(lubridate)
library(keras)

# Precipitation data is one measurement per day
p <- read_feather("brundage_reservoir_2000-2020.feather") %>%
    filter(datatype == "PRCP") %>%
    mutate(date = ymd(date)) %>%
    arrange(desc(date))

# Runs from January 1, 2000 to December 8, 2020. "T" value for attributes means that trace amount of precipitation was recorded. One row also has "I". Don't know what that means.
summary(p)

# Load buoy data
load(file = "npac_data.RData")

# Each list item is data from one of 51 buoys with the names shown below
length(npac_data)
names(npac_data)

# For this buoy we have 48 tables worth of data
length(npac_data[["46001"]])
npac_data[["46001"]][[1]]
npac_data[["46001"]][[length(npac_data[["46001"]])]]

# Need to automatically extract and put in a single table with cols representing time and WVHT.

# All data from buoy 51101
b <- npac_data[["51101"]]

# Loop over tables
df <- map_dfr(b, function(x) {
    
    # Fix name of year column
    if("#YY" %in% names(x)) {
        x <- x %>%
            rename(YYYY = `#YY`)
    }
    
    # Select cols and turn 99s into NA
    x %>%
        select(matches(c("YY", "MM", "DD", "hh", "mm", "WVHT"))) %>%
        mutate(WVHT = if_else(WVHT == 99, NA_real_, WVHT)) %>%
    
    # Code for date
    mutate(date = ymd(paste0(YYYY, "-", MM, "-", DD))) })

# Some screwy stuff going on in 2018. No data for May-August and too much data for October-December, e.g.
df %>% filter(YYYY == "2018" & MM == "4")
df %>% filter(YYYY == "2018" & MM == "8")
df %>% filter(YYYY == "2018" & MM == "10")

# Summarize by date
df2 <- df %>%
    group_by(date) %>%
    summarize(n = sum(!is.na(WVHT)),
              mWVHT = mean(WVHT, na.rm = TRUE), .groups = "drop")
    

# Shows (1) very little data in 2008, (2) missing data in 2014 and 2018, and (3)
# values that are consistently too high in the end of 2018.
df2 %>%
    mutate(year = year(date),
           yday = yday(date)) %>%
    ggplot(aes(x = yday, y = mWVHT)) +
    geom_path() +
    facet_wrap(~year)

# Need a method to fix up or exclude problematic data. Guess I'm looking for the number of complete samples I can create. Depends on how many time steps I want to include per sample. Say 3 weeks. Then I need 3 full weeks of data (21 days) leading up to and including the day 21 output measurement for precipitation.

#####
# Could take each brundage measurement, starting with the most recent and grab all wave data for that date and 20 days prior. If there ends up being fewer than 21 days of wave data in the sample, discard it. Also discard if the wave data includes stuff that's consistently too high, like at the end of 2018.

# Check precipitation data for problems


# Drop weird wave data
df2.1 <- df2 %>%
    filter(n != 0 & n < 50)

# Get this many days preceding
lag <- 21

# Test
p.test <- p %>%
    filter(date > "2017-01-01", date < "2017-01-04")

# Loop over precipitation dates
df3 <- map_dfr(p$date, function(precip_date) {

    # Get precip measurement
    precip_in <- p %>%
        filter(date == precip_date) %>%
        pull(value)
        
    # Compute vector of dates to get wave data for
    wave_dates <- as.character(precip_date - c(0:lag))
    wave_dates <- precip_date - c(0:lag)
    
    # Filter to wave data
    df2.1 %>%
        filter(date %in% wave_dates) %>%
        mutate(date = as.character(date),
               precip_date = as.character(precip_date),
               precip_in = precip_in) %>%
        rename(wave_date = date) %>%
        arrange(desc(wave_date)) })
    
# Vector of precip dates with 22 rows
df4 <- df3.1 %>%
    group_by(precip_date) %>%
    summarize(n = n(), .groups = "drop") %>%
    filter(n == 22) %>%
    pull(precip_date)

# Filter df3 to only full samples
df3.1 <- df3 %>%
    filter(precip_date %in% df4) %>%
    mutate(wave_date = ymd(wave_date),
           precip_date = ymd(precip_date))

