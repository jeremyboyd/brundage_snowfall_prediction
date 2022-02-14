# Author: Jeremy Boyd (jeremyboyd@pm.me)
# Description: Gets wave height data from all buoys in the North Pacific.

# # This is the measure that's supposed to predict winter storms
# # WVHT	Significant wave height (meters) is calculated as the average of the highest one-third of all of the wave heights during the 20-minute sampling period. See the Wave Measurements section.
#
#
#
# # This kind of URL takes you to a summary page for the buoy (station) given:
# # https://www.ndbc.noaa.gov/station_history.php?station=42040
#
#
# # The bit after stdmet (standard metorological) gives the buoy number (42040), the "h" means historical, and the "2019" is the year. File is a GNU-zipped text.
# # https://www.ndbc.noaa.gov/data/historical/stdmet/42040h2019.txt.gz
#
# # Might have to go to the station homepage first and scrape all of the years that have stmet available:
# # https://www.ndbc.noaa.gov/station_history.php?station=42040
#
# # How do I get a table of all buoys, with info on where they're located, what type of data they're recording?
#
# # This page has a list of buoys:
# # https://www.ndbc.noaa.gov/wstat.shtml
#
# # Supposedly there are 968 buoys reporting recently.
#
# #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# #### Get vector of buoys to use in models ####
# #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# # Read in page listing buoys
# p <- read_html("https://www.ndbc.noaa.gov/wstat.shtml")
#
# # Table of moored stations (buoys)
# moored_stations <- html_table(p, fill = TRUE)[[6]] %>%
#     as_tibble() %>%
#     separate(col = "Location Lat/Long", into = c("lat", "long"), sep = " ") %>%
#
#     # Make lat/long numeric
#     mutate(ns_flag =  if_else(str_detect(lat, "S"), -1, 1),
#            ew_flag = if_else(str_detect(long, "W"), -1, 1),
#            lat = as.numeric(str_remove(lat, "N|S")),
#            long = as.numeric(str_remove(long, "E|W")),
#            lat = lat * ns_flag,
#            long = long * ew_flag) %>%
#
#     # Use lat/long to flag buoys that are roughly in the N Pacific
#     mutate(npac = if_else(lat > 0 & (long < -112 | long > 112), 1, 0))
#
# # List of N Pacific buoys to use in models
# npac_stations <- moored_stations %>%
#     filter(npac == 1) %>%
#     mutate(Station = str_remove(Station, "\\*")) %>%
#     pull(Station) %>%
#     unique()
#
# #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# #### Get station data ####
# #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# # For each of these buoys, need to go to its homepage, get list of years that data is available, iterate over years and pull data.
# npac_data <- map(npac_stations, function(station) {
#
#     # Read buoy page
#     station_page <- read_html(
#         paste0("https://www.ndbc.noaa.gov/station_history.php?station=",
#                station))
#
#     # Target text comes from nodes in the page fitting the "ul li ul li" pattern
#     target_text <- html_nodes(station_page, "ul li ul li") %>%
#         xml_text()
#
#     # Extract years that data is available from target text
#     years <- target_text %>%
#         as_tibble() %>%
#         filter(
#             str_detect(value, "Standard meteorological data.+\n.+[0-9]+")) %>%
#         pull(value) %>%
#         str_extract_all("[0-9]+") %>%
#         unlist()
#
#     # Base download URL
#     base_download <- paste0("https://www.ndbc.noaa.gov/data/historical/stdmet/",
#                             station, "h")
#
#     # Download data files for years
#     map(years, function(years) {
#
#         # Construct download URL for current year
#         download_url <- paste0(base_download, years, ".txt.gz")
#
#         # User message
#         message(paste("Getting", download_url))
#
#         # Get column names from first row
#         col_names <- read_table(file = download_url, n_max = 0) %>%
#             names()
#
#         # Second header
#         second_header <- read_table(
#             file = download_url, skip = 1, n_max = 0) %>%
#             names()
#
#         # Starting in 2007 it looks like files have a second header that tells
#         # you the units that the measurements are in. The second header stars
#         # with "#", so we can look for that and do a parsing procedure that
#         # skips the second header.
#
#         # Rewrite so that there's a single block to read files, but the value of skip is set based on if/else logic.
#         # Can also do read_table once an get the second header values from row 2.
#
#         if(str_detect(second_header[1], "#")) {
#             read_fwf(file = download_url,
#                      skip = 2,
#                      col_positions = fwf_empty(download_url,
#                                                col_names = col_names,
#                                                skip = 2)) %>%
#                 mutate(across(.cols = everything(), as.numeric))
#         } else {
#             read_fwf(file = download_url,
#                      skip = 1,
#                      col_positions = fwf_empty(download_url,
#                                                col_names = col_names,
#                                                skip = 1)) %>%
#                 mutate(across(.cols = everything(), as.numeric))
#         }
#     })
# })
#
# # Add station names to npac_data
# names(npac_data) <- npac_stations
#
# # Save
# save(npac_data, file = "npac_data.RData")

# # year is YY in 1998, YYYY starting in 1999
# # 16 cols through 1999, 17 cols starting in 2000--TIDE is added. Could just drop...
# # 18 cols starting in 2005--mm (minute) is added. Could just drop... unless I need to average over it?
# # Parsing failures starting in 2007--look at raw files to diagnose. One thing I can already see is that year col is labeled "#YY"
