"""
model_utils.py

Loads and performs inference using:

1. TensorFlow Keras model (.keras)
2. TensorFlow Lite model (.tflite)

Both models return the same output format.
"""

import time
import numpy as np
import tensorflow as tf

from config import (
    KERAS_MODEL_PATH,
    TFLITE_MODEL_PATH,
    CLASS_NAMES,
)

# ============================================================
# KERAS MODEL
# ============================================================

class KerasModel:

    def __init__(self):
        self.model = tf.keras.models.load_model(KERAS_MODEL_PATH)

    def predict(self, x):
        """
        Parameters
        ----------
        x : ndarray
            Shape (1,64,216,1)

        Returns
        -------
        dict
        """

        start = time.perf_counter()

        probabilities = self.model.predict(
            x,
            verbose=0
        )[0]

        elapsed = (time.perf_counter() - start) * 1000

        predicted_index = int(np.argmax(probabilities))

        confidence = float(probabilities[predicted_index])

        return {

            "model": "Keras",

            "prediction": CLASS_NAMES[predicted_index],

            "confidence": confidence,

            "probabilities": probabilities,

            "class_index": predicted_index,

            "time_ms": elapsed

        }


# ============================================================
# TFLITE MODEL
# ============================================================

class TFLiteModel:

    def __init__(self):

        self.interpreter = tf.lite.Interpreter(
            model_path=str(TFLITE_MODEL_PATH)
        )

        self.interpreter.allocate_tensors()

        self.input_details = self.interpreter.get_input_details()

        self.output_details = self.interpreter.get_output_details()

    def predict(self, x):

        start = time.perf_counter()

        self.interpreter.set_tensor(
            self.input_details[0]["index"],
            x.astype(np.float32)
        )

        self.interpreter.invoke()

        probabilities = self.interpreter.get_tensor(
            self.output_details[0]["index"]
        )[0]

        elapsed = (time.perf_counter() - start) * 1000

        predicted_index = int(np.argmax(probabilities))

        confidence = float(probabilities[predicted_index])

        return {

            "model": "TensorFlow Lite",

            "prediction": CLASS_NAMES[predicted_index],

            "confidence": confidence,

            "probabilities": probabilities,

            "class_index": predicted_index,

            "time_ms": elapsed

        }


# ============================================================
# MODEL MANAGER
# ============================================================

class ModelManager:

    """
    Loads both models once.

    Streamlit will use this class.
    """

    def __init__(self):

        self.keras = KerasModel()

        self.tflite = TFLiteModel()

    def predict_keras(self, tensor):

        return self.keras.predict(tensor)

    def predict_tflite(self, tensor):

        return self.tflite.predict(tensor)

    def compare(self, tensor):

        return {

            "keras": self.predict_keras(tensor),

            "tflite": self.predict_tflite(tensor)

        }


# ============================================================
# Helper
# ============================================================

def top_predictions(probabilities, top_n=3):
    """
    Returns top-N predictions sorted by confidence.
    """

    idx = np.argsort(probabilities)[::-1][:top_n]

    results = []

    for i in idx:

        results.append({

            "label": CLASS_NAMES[i],

            "confidence": float(probabilities[i])

        })

    return results