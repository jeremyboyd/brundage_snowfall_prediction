# Resources
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow import keras

# Function definition
def fit_cnn_lstm(data, step, learning_rate, batch_size, epochs, patience,
    recurrent_dropout, other_dropout):
    
    # Unpack training and validation sets
    x_train = data["x_train"]
    y_train = data["y_train"]
    x_val = data["x_val"]
    y_val = data["y_val"]
    
    # Since step = 1 (no downsampling), the sequence length is the same as the
    # number of past steps (= 18)
    sequence_length = int(r.past / step)
    
    # Create dataset of sliding windows over training data
    dataset_train = keras.preprocessing.timeseries_dataset_from_array(
        x_train,
        y_train,
        sequence_length = sequence_length,
        sampling_rate = step,
        batch_size = batch_size)
        
    # Create dataset of sliding windows over validation data
    dataset_val = keras.preprocessing.timeseries_dataset_from_array(
        x_val,
        y_val,
        sequence_length = sequence_length,
        sampling_rate = step,
        batch_size = batch_size)

    # Get tensor shapes for input and targets. The output of model.summary()
    # should match this.
    for batch in dataset_train.take(1):
        inputs, targets = batch
    print("Input shape:", inputs.numpy().shape)
    print("Target shape:", targets.numpy().shape)

    # Define model
    # NOTE: Missing TimeDistributed wrapper that's featured here:
    # https://machinelearningmastery.com/timedistributed-layer-for-long-short-term-memory-networks-in-python/
    inputs = keras.layers.Input(
        shape = (inputs.shape[1], inputs.shape[2]))
    x = keras.layers.Conv1D(
        filters = 32,
        kernel_size = 2,
        activation = "relu",
        padding = "same")(inputs)
    x = keras.layers.MaxPooling1D(
        pool_size = 2)(x)
    x = keras.layers.Dropout(rate = other_dropout)(x)
    x = keras.layers.Conv1D(
        filters = 64,
        kernel_size = 2,
        activation = "relu",
        padding = "same")(x)
    x = keras.layers.MaxPooling1D(
        pool_size = 2)(x)
    x = keras.layers.Dropout(rate = other_dropout)(x)
    x = keras.layers.Conv1D(
        filters = 128,
        kernel_size = 2,
        activation = "relu",
        padding = "same")(x)
    x = keras.layers.MaxPooling1D(
        pool_size = 2)(x)
    x = keras.layers.Dropout(rate = other_dropout)(x)
    x = keras.layers.LSTM(32,
        return_sequences = True)(x)
    x = keras.layers.LSTM(
        units = 300,
        recurrent_dropout = recurrent_dropout)(x)
    outputs = keras.layers.Dense(1)(x)
    model = keras.Model(inputs = inputs, outputs = outputs)
    model.compile(
        
        # Adam optimizer
        optimizer = keras.optimizers.Adam(learning_rate = learning_rate),
        
        # MAE loss
        loss = keras.losses.MeanAbsoluteError())
    model.summary()

    # Checkpoint path
    path_checkpoint = "model_checkpoint.h5"

    # Early stopping checkpoint. Stop if no improvement on val_loss after
    # *patience* epochs.
    es_callback = keras.callbacks.EarlyStopping(
        monitor = "val_loss",
        min_delta = 0,
        patience = patience)

    # Checkpoint callback
    modelckpt_callback = keras.callbacks.ModelCheckpoint(
        monitor = "val_loss",
        filepath = path_checkpoint,
        save_weights_only = True,
        save_best_only = True)

    # Fit model & record learning stats in history
    history = model.fit(
        dataset_train,
        epochs = epochs,
        validation_data = dataset_val,
        callbacks = [es_callback, modelckpt_callback])

    # Get predictions for the validation set
    pred_y = np.array([]).astype("float32")
    for x, y in dataset_val.take(-1):
        pred_y = np.concatenate((pred_y, model.predict(x).flatten()))

    # Get actuals for validation set
    # val_x = np.concatenate([x for x, y in dataset_val], axis = 0)
    val_y = np.concatenate([y for x, y in dataset_val], axis = 0)
    
    # Return history, actual and predicted validation set numbers
    return(
        {"preds": data["preds"],
        "loss": np.array(history.history["loss"]),
        "val_loss": np.array(history.history["val_loss"]),
        "actual_y": np.array(val_y.flatten()),
        "pred_y": pred_y}
    )
