# Author: Jeremy Boyd (jeremyboyd@pm.me)
# Model Brundage precipitation based on North Pacific buoy data.

# Resources
library(tidyverse)
library(lubridate)
library(feather)

# Take a look at rnoaa package to pull data. Is it better/faster than what I've written?
# https://cran.r-project.org/web/packages/rnoaa/index.html


load("npac_data.RData")


# This page says missing data is coded using "a variable number of 9's", e.g. 999.0, or 99.0.
# https://www.ndbc.noaa.gov/measdes.shtml

# Times in both historical and realtime files are UTC.
# WVHT is significant wave height in meters. Calculate as the average of the highest one-third of all of the wave heights during the 20-minute sampling period.

# MWD: the directoin from wich the waves of the dominant period (DPD) are coming. The units are degrees from thru North, increasing clockwise.
# How do you differentiate 99 degrees from true north with an NA? Looks like they're using 999 in that case. Guessing that the rule is to use 99 when it can't be confused with the actual measurements, and 999 otherwise.
# For WVHT, 99 must be NA, since we probably can't get waves that are 99 meters tall



# Put all data from 51101 into a single dataframe
df <- map_dfr(npac_data[["51101"]], function(year) { year }) %>%
    rename(YYYY = `#YY`) %>%
    mutate(time = ymd_hm(paste(YYYY, MM, DD, hh, mm, sep = "-")),
           date = date(time),
           WVHT = if_else(WVHT == 99, NA_real_, WVHT))

# Missing about 1 in 3 wave height measurements
sum(is.na(df$WVHT)) / length(df$WVHT)

# Since you can get multiple wave height measurements in a single day, maybe take the mean to get an average per day?

# Looks like there's a ceiling on wave height of about 9 (or 9.5). Also looks like measurements tend to peak in the middle of winter, which makes sense for the north pacific.
df %>%
    ggplot(aes(x = time, y = WVHT)) +
    geom_point() +
    # geom_path() +
    scale_x_datetime(date_breaks = "1 year") +
    scale_y_continuous(limits = c(0, 10), breaks = seq(0, 10, 1))

# Go to one average measurement per day
df2 <- df %>%
    group_by(date) %>%
    summarize(n = sum(!is.na(WVHT)),
              mean_wvht = mean(WVHT, na.rm = TRUE), .groups = "drop")

# This shows the winter peak pretty clearly. Something weird going on at the end of 2018...
df2 %>%
    ggplot(aes(x = date, y = mean_wvht)) +
    geom_path() +
    scale_x_date(date_breaks = "1 year") +
    scale_y_continuous(limits = c(0, 10), breaks = seq(0, 10, 1))

# Facet by year. Shows that data may not be as densly sampled in 2008 & 2009. Most years show a u-shape indicating increased mean wave height at the end and beginnings of years (winter in the N Pacific). The 2018 data have some weirdness to them--doesn't seem to be any data over the summer, then you get pretty much constantly high numbers from October-December, which doesn't seem realistic.
df2 %>%
    mutate(year = year(date)) %>% 
    ggplot(aes(x = date, y = mean_wvht)) +
    geom_path() +
    # geom_smooth(color = "red", size = .5 ) +
    scale_x_date(date_breaks = "2 months") +
    scale_y_continuous(limits = c(0, 10), breaks = seq(0, 10, 1)) +
    facet_wrap(~ year, scales = "free_x") +
    theme(axis.text.x = element_text(angle = 30, hjust = 1))
    
# How to model these data?
# Probably have 2 time series (wave height at various stations and precipitation at brundage). We think that high values in one time series will predict high values in another at some future data. But we're not exactly sure what the lag is. For each y (precipitation) we could take wave height data anywhere from 3 weeks (21 days?) preceding and use it to predict y. So if we had 20 stations and 3 weeks of data for each station that comes to 60 predictors. If we did a forest-based model you could see which stations and lags are more predictive than others. Feels like there should be a time-series-based approach that would more naturally handle these data...


br <- read_feather("brundage_reservoir_2000-2020.feather")

# View annual precipitation
br_prcp <- br %>%
    filter(datatype == "PRCP")

# Shows that we have a single pre cipitation measurement per day
br_prcp <- br_prcp %>%
    mutate(date = date(date)) %>%
    group_by(date) %>%
    summarize(n = sum(!is.na(value)),
              prcp = mean(value, na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(n))
    
# Visualize annual precipitation from 2000-2020
br_prcp %>%
    mutate(year = year(date)) %>%
    ggplot(aes(x = date, y = prcp)) +
    geom_path() +
    geom_smooth(color = "red", size = .5 ) +
    scale_x_date(date_breaks = "2 months") +
    facet_wrap(~ year, scales = "free_x") +
    theme(axis.text.x = element_text(angle = 30, hjust = 1))



# Join wave heights and brundage precipitation
df3 <- br_prcp %>%
    select(-n) %>%
    inner_join(df2 %>%
                  select(date, mean_wvht) %>%
                  filter(year(date) %in% c("2009", "2010", "2011", "2012",
                                           "2013", "2015", "2016", "2017",
                                           "2019")),
              by = "date")

# Shows that we've excluded 2014 & 2015
df3 %>% 
    mutate(year = year(date)) %>%
    ggplot(aes(x = date, y = mean_wvht)) +
    geom_path() +
    # geom_smooth(color = "red", size = .5 ) +
    scale_x_date(date_breaks = "2 months") +
    scale_y_continuous(limits = c(0, 10), breaks = seq(0, 10, 1)) +
    facet_wrap(~ year, scales = "free_x") +
    theme(axis.text.x = element_text(angle = 30, hjust = 1))

# Write to csv
df3 %>%
    filter(!is.na(mean_wvht)) %>%
    arrange(date) %>%
    write_csv("brundage_precip_51101_wvht.csv")






# Use 2010-2012 wave height data to predict 2013 precipitation
prcp_2013 <- br_prcp %>%
    filter(date > "2012-12-31" & date <= "2013-12-31")
    


# Lay 2013 wave height and precipitation on same figure
prcp_2013 %>%
    mutate(date = date(date)) %>%
    select(date, prcp = value) %>%
    left_join(df2 %>%
                  select(date, wvht = mean_wvht),
              by = "date") %>%
    pivot_longer(cols = c("prcp", "wvht"), names_to = "type",
                 values_to = "value") %>%
    mutate(month = month(date)) %>%
    ggplot(aes(x = date, y = value, group = type, color = type)) +
    geom_path() +
    facet_wrap(~ month, scales = "free_x")
        
        








