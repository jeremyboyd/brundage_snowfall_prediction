# Description: Model of Jena weather data from Chollet & Allaire (2018)


# Rework this based on most recent example here: https://keras.io/examples/timeseries/timeseries_weather_forecasting/
# See I can redo solely in R. Might be able to borrow code from here: https://github.com/sydeaka/neural_networks_longitudinal
# Once I get it working, can I improve by doing a cnn-lstm? Can I improve using GRU.
# How does TimeDistributed work?



# Resources
rm(list = ls())
library(tibble)
library(readr)
library(keras)
library(ggplot2)

# Download & unzip Jena dataset
# download.file("https://s3.amazonaws.com/keras-datasets/jena_climate_2009_2016.csv.zip", paste0(getwd(), "/jena_climate_2009_2016.csv.zip"))
# unzip(paste0(getwd(), "/jena_climate_2009_2016.csv.zip"))

# Read in data
data <- read_csv("jena_climate_2009_2016.csv")
glimpse(data)

# Plot temperature
ggplot(data, aes(x = 1:nrow(data), y = `T (degC)`)) +
    geom_line()

# First 10 days only
ggplot(data[1:1440,], aes(x = 1:1440, y = `T (degC)`)) +
    geom_line()

# Convert to matrix, discarding first column
data <- data.matrix(data[, -1])

# Compute mean & sd for each column based on training data only
train_data <- data[1:200000,]
mean <- apply(train_data, 2, mean)
std <- apply(train_data, 2, sd)

# Normalize all data
data <- scale(data, center = mean, scale = std)

# Version of generator function from book
# generator <- function(data, lookback, delay, min_index, max_index,
#                       shuffle = FALSE, batch_size = 128, step = 6) {
#     if (is.null(max_index)) max_index <- nrow(data) - delay - 1
#     i <- min_index + lookback
#     function() {
#         if (shuffle) {
#             rows <- sample(c((min_index+lookback):max_index), size = batch_size)
#         } else {
#             if (i + batch_size >= max_index)
#                 i <<- min_index + lookback
#             rows <- c(i:min(i+batch_size, max_index))
#             i <<- i + length(rows)
#         }
#         samples <- array(0, dim = c(length(rows),
#                                     lookback / step,
#                                     dim(data)[[-1]]))
#         targets <- array(0, dim = c(length(rows)))
#         for (j in 1:length(rows)) {
#             indices <- seq(rows[[j]] - lookback, rows[[j]],
#                            length.out = dim(samples)[[2]])
#             samples[j,,] <- data[indices,]
#             targets[[j]] <- data[rows[[j]] + delay,2]
#         }
#         list(samples, targets)
#     }
# }

# Version of generator function from published errata
generator <- function(data, lookback, delay, min_index, max_index,
                      shuffle = FALSE, batch_size = 128, step = 6) {
    if (is.null(max_index))
        max_index <- nrow(data) - delay - 1
    i <- min_index + lookback
    function() {
        if (shuffle) {
            rows <- sample(c((min_index+lookback):max_index), size = batch_size)
        } else {
            if (i + batch_size >= max_index)
                i <<- min_index + lookback
            rows <- c(i:min(i+batch_size-1, max_index))
            i <<- i + length(rows)
        }
        
        samples <- array(0, dim = c(length(rows),
                                    lookback / step,
                                    dim(data)[[-1]]))
        targets <- array(0, dim = c(length(rows)))
        
        for (j in 1:length(rows)) {
            
            # The "-1" here is different
            indices <- seq(rows[[j]] - lookback, rows[[j]]-1,
                           length.out = dim(samples)[[2]])
            samples[j,,] <- data[indices,]
            targets[[j]] <- data[rows[[j]] + delay,2]
        }           
        list(samples, targets)
    }
}

# Instantiate generator functions for training, validation, test
lookback <- 1440
step <- 6
delay <- 144
batch_size <- 128

train_gen <- generator(
    data,
    lookback = lookback,
    delay = delay,
    min_index = 1,
    max_index = 200000,
    shuffle = TRUE,
    step = step,
    batch_size = batch_size
)

val_gen = generator(
    data,
    lookback = lookback,
    delay = delay,
    min_index = 200001,
    max_index = 300000,
    step = step,
    batch_size = batch_size
)

test_gen <- generator(
    data,
    lookback = lookback,
    delay = delay,
    min_index = 300001,
    max_index = NULL,
    step = step,
    batch_size = batch_size
)

# Define
# These have to be floored integers in order to work with fit_generator()
val_steps <- (300000 - 200001 - lookback) / batch_size
test_steps <- (nrow(data) - 300001 - lookback) / batch_size

# Example training batch. First element is input, last is output. Input is a 3-dimensional array, where the first dimension is batch, the second is sample, and the third is predictor
# x <- train_gen()
# str(x)
# str(x[[1]])

# Naive evalution method
evaluate_naive_method <- function() {
    batch_maes <- c()
    for (step in 1:val_steps) {
        c(samples, targets) %<-% val_gen()
        preds <- samples[, dim(samples)[[2]], 2]
        mae <- mean(abs(preds - targets))
        batch_maes <- c(batch_maes, mae)
    }
    print(mean(batch_maes))
}
celsius_mae <- evaluate_naive_method() * std[["T (degC)"]]

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#### Generator issue ####
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Issue: During fitting, freezes on Epoch 1, 1/500. This has something to do with the R keras generators not being compatible with Tensorflow >= 2.0. I've tried a couple of fixes:

# 1. Make Tensorflow recognize the R generators as Python generators, like so:
# train_gen2 <- keras:::as_generator.function(train_gen)
# val_gen2 <- keras:::as_generator.function(val_gen)

# See post by rdinnager at https://github.com/rstudio/keras/issues/1090 for more
# info. This gets me through two epochs, but then freezes.

# 2. Revert to Tensorflow < 2.0. I reverted to 1.15.0, and the model seems to be
# fitting. But it's doing a weird behavior where it seems to be fitting each
# epoch twice. See the same issue reported here:
# https://stackoverflow.com/questions/61546520/keras-epoch-runs-twice. Wonder if
# it has something to do with val_steps not being an integer?

# 3. Use Python keras, which seems to be more developed than the R version.

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#### GRU model ####
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Model
model <- keras_model_sequential() %>%
    layer_gru(units = 32,
              
              # Second dimension is the number of time series
              input_shape = list(NULL, dim(data)[[-1]])) %>%
    layer_dense(units = 1)

model %>% compile(
    optimizer = optimizer_rmsprop(),
    loss = "mae"
)

# Fit
history <- model %>%
    fit_generator(
        generator = train_gen,
        steps_per_epoch = 500,
        epochs = 20,
        validation_data = val_gen,
        validation_steps = val_steps)

# Looks like we start overfitting after 4 epochs.
plot(history)

# Get minimum validation loss
min(history$metrics$val_loss)

# Translate to Celsius
min(history$metrics$val_loss) * std[["T (degC)"]]

# This beats the naive method by ~ 0.20 degrees Celsius
celsius_mae - min(history$metrics$val_loss) * std[["T (degC)"]]

# Min occurs after 4 epochs of training
which(history$metrics$val_loss == min(history$metrics$val_loss))

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#### LSTM model ####
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Model
model_lstm <- keras_model_sequential() %>%
    layer_lstm(units = 32,
              
              # Second dimension is the number of time series
              input_shape = list(NULL, dim(data)[[-1]])) %>%
    layer_dense(units = 1)

model_lstm %>% compile(
    optimizer = optimizer_rmsprop(),
    loss = "mae"
)

# Fit. Getting same doubling of epochs that I did for GRU
history_lstm <- model_lstm %>%
    fit_generator(
        generator = train_gen,
        steps_per_epoch = 500,
        epochs = 20,
        validation_data = val_gen,
        validation_steps = val_steps)

# So far, LSTM only beats naive model by ~ 0.11, whereas GRU beats it by ~ 0.20.
celsius_mae - min(history_lstm$metrics$val_loss) * std[["T (degC)"]]


# Todo: For both GRU & LSTM, evaluate performance on test set.
