# Author: Jeremy Boyd (jeremyboyd@pm.me)
# Description: Get Brundage snowfall data from NOAA.

# Resources
library(tidyverse)
library(httr)
library(lubridate)
library(feather)

# NCDC (National Climatic Data Center) token
token <- "xkwqbALpujIcaXNAREfvBCgAgnfAESwg"

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#### Figure out which datatype(s) I need ####
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Get the name and ID of all datatypes
all_types <- map_dfr(
    
    # The API will only return a maximum of 1K results, so I need to do two
    # requests, with the following offsets
    c("1", "1001"),
    
    # For each offset, do a request and extract the data
    function(offset) {
        
        # Make request
        types_request <- GET(
            url = paste0(
                "https://www.ncdc.noaa.gov/cdo-web/api/v2/datatypes?",
                "limit=1000&offset=", offset),
            add_headers("token" = token),
            config(verbose = TRUE)
        )
        
        # Store results
        types_results <- content(types_request)$results
        
        # Iterate over results to extract name & id
        map_dfr(1:length(types_results), function(x) {
            tibble(name = types_results[[x]]$name,
                   id = types_results[[x]]$id)
        })
    })

# Write to file
write_feather(all_types, "all_NCDC_datatypes.feather")

# Vector of all datatypes with "snow"
all_types %>%
    filter(str_detect(name, "[Ss]now")) %>%
    pull(name)

# TSNW might be the most relevant
all_types %>%
    filter(str_detect(name,
                      "Total snow fall|^Snowfall|Multiday snowfall total"))

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#### Explore data available from the Brundage reservoir station ####
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Pieces needed for data request
base_url <- "https://www.ncdc.noaa.gov/cdo-web/api/v2/data?"
station_id <- "GHCND:USS0016D09S"       # Brundage reservoir station
datasetid <- "GHCND"
startdate <- "2020-01-01"
enddate <- "2020-01-31"
units <- "standard"

# Request URL
url <- paste0(base_url, "datasetid=", datasetid, "&", "stationid=", stationid, "&", "startdate=", startdate, "&", "enddate=", enddate, "&", "units=", units, "&limit=1000")

# Make request
request <- GET(url = url,
               add_headers("token" = token),
               config(verbose = TRUE))

# Get the total number of data points in request
content(request)$metadata$resultset$count

# Vector of unique datatypes in request. Shows that this station is only measuring snow depth (SNWD), precipitation (PRCP), average temperature (TAVG), max and min temperature (TMAX, TMIN), temperature at time of observation (TOBS), and water equivalent of snow on the ground (WESD).
map_chr(content(request)$results, function(x) {
    x$datatype}) %>%
    unique()

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#### Get 20 years of data from Brundage reservoir station ####
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Max amount of data the API will give you is for a single year. So I have to
# break the requests up by year.

# Vector of years to get data for
year <- c(2000:2020)

# Loop over years
df <- map_dfr(year, function(year) {
    
    # Set start and end dates
    startdate <- paste0(year, "-01-01")
    enddate <- paste0(year, "-12-31")
    
    # Define URL to get result_count
    count_url <- paste0(base_url,
                  "datasetid=", datasetid,
                  "&stationid=", stationid,
                  "&startdate=", startdate,
                  "&enddate=", enddate,
                  "&units=", units)
    
    # Make initial request to get result_count
    count_request <- GET(url = count_url,
                         add_headers("token" = token),
                         config(verbose = TRUE))
    result_count<- content(count_request)$metadata$resultset$count
    
    # Vector of offsets
    offset <- (0:floor(result_count / 1000)) * 1000 + 1
    
    # Loop over offsets
    map_dfr(offset, function(offset) {
        
        # Define request URL
        request_url <- paste0(base_url,
                      "datasetid=", datasetid,
                      "&stationid=", stationid,
                      "&startdate=", startdate,
                      "&enddate=", enddate,
                      "&units=", units,
                      "&limit=1000",
                      "&offset=", offset)
        
        # Get data
        request <- GET(url = request_url,
                       add_headers("token" = token),
                       config(verbose = TRUE))
        results <- content(request)$results
        
        # Organize into tibble
        tibble(
            date = rvest::pluck(results, 1) %>% unlist(),
            datatype = rvest::pluck(results, 2) %>% unlist(),
            station = rvest::pluck(results, 3) %>% unlist(),
            attributes = rvest::pluck(results, 4) %>% unlist(),
            value = rvest::pluck(results, 5) %>% unlist()
        )
    })
})

# Write to feather
df %>%
    mutate(date = ymd_hms(date)) %>%
    write_feather("brundage_reservoir_2000-2020.feather")

# Next stuff to do:
# Compute snowfall for a day based on snow depth (SNWD) difference from one day
# to the next. Use this as an outcome to predict based on buoy data.
