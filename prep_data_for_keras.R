# Author: Jeremy Boyd (jeremyboyd@pm.me) Description: R function that prepares
# an input dataframe for timeseries modeling in Keras Python.

# Resources
library(lubridate)

# Function definition
prep_data_for_keras <- function(data, outcome, predictors, split_fraction,
                                train_split, past, future) {
    
    # Add yday if specifed as a predictor
    if(sum(str_detect(predictors, "yday")) > 0){
        data <- data %>%
            mutate(yday = yday(date))
    }
    
    # Keep date, outcome, predictors
    prep <- data %>%
        select(all_of(outcome), all_of(predictors)) %>%
        mutate(row = row_number() - 1)
    
    # Compute number of training rows
    train_split = as.integer(split_fraction * nrow(data))
    
    # Compute mean & sd for outcome training set
    outcome_train <- prep %>%
        filter(row < train_split) %>%
        pull(outcome)
    outcome_mean <- mean(outcome_train)
    outcome_sd <- sd(outcome_train)
    
    # Apply normalization based on training set
    prep_norm <- map_dfc(names(prep)[-ncol(prep)], function(x) {
        column <- prep %>% 
            filter(row < train_split) %>%
            pull(x)
        col_mean <- mean(column)
        col_sd <- sd(column)
        (prep %>% pull(x) - col_mean) / col_sd
    })
    prep_norm <- bind_cols(prep_norm, prep$row)
    names(prep_norm) <- names(prep)
    
    # Divide into training & validation sets
    train_data <- prep_norm %>%
        filter(row < train_split)
    val_data <- prep_norm %>%
        filter(row >= train_split)

    # Training input
    x_train <- train_data %>% select(all_of(predictors))
    
    # Training output
    start <- past + future
    end <- start + train_split -1
    y_train <- prep_norm %>%
        filter(row %in% start:end) %>%
        select(all_of(outcome))
    
    # Define end of validation input, and start of validation labels
    x_end = nrow(val_data) - past - future
    label_start = train_split + past + future
    
    # Validation input
    x_val <- val_data %>%
        filter(row_number() <= x_end) %>%
        select(all_of(predictors))
    
    # Validation ouptut
    y_val <- prep_norm %>%
        filter(row >= label_start) %>%
        select(all_of(outcome))
    
    # Convert all sets to matrix. These will become numpy arrays in Python.
    return(list(preds = paste(predictors, collapse = ", "),
                x_train = as.matrix(x_train),
                y_train = as.matrix(y_train),
                x_val = as.matrix(x_val),
                y_val = as.matrix(y_val),
                outcome_mean = outcome_mean,
                outcome_sd = outcome_sd))
}
