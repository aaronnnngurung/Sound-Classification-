"""
config.py
Configuration file for the Emergency Sound Detection Streamlit App
"""

from pathlib import Path

# ==========================================================
# PROJECT PATHS
# ==========================================================

# Root directory of the project
BASE_DIR = Path(__file__).resolve().parent

# Model paths
MODELS_DIR = BASE_DIR / "models"

KERAS_MODEL_PATH = MODELS_DIR / "best_model.keras"
TFLITE_MODEL_PATH = MODELS_DIR / "emergency_audio_classifier.tflite"

# Folder for temporary microphone recordings
RECORDINGS_DIR = BASE_DIR / "recordings"
RECORDINGS_DIR.mkdir(exist_ok=True)

# ==========================================================
# AUDIO CONFIGURATION
# ==========================================================

# These should match your training notebook
SAMPLE_RATE = 22050
DURATION = 5                # seconds
N_MELS = 64
N_FFT = 2048
HOP_LENGTH = 512
TOP_DB = 80

# Number of samples in one recording
SAMPLES = SAMPLE_RATE * DURATION

# Expected model input shape
MODEL_INPUT_SHAPE = (64, 216, 1)

# ==========================================================
# CLASS LABELS
# ==========================================================

CLASS_NAMES = [
    "siren",
    "crying_baby",
    "door_wood_knock",
    "glass_breaking",
    "fireworks",
    "car_horn"
]

NUM_CLASSES = len(CLASS_NAMES)

# ==========================================================
# STREAMLIT SETTINGS
# ==========================================================

APP_TITLE = "🚨 Emergency Sound Detection"

APP_DESCRIPTION = """
Detect emergency and environmental sounds using either:

• TensorFlow Keras (.keras)

• TensorFlow Lite (.tflite)

Supports:
- Live microphone recording
- Audio upload
- Side-by-side comparison
"""

# ==========================================================
# DISPLAY SETTINGS
# ==========================================================

PROGRESS_COLORS = {
    "siren": "#FF3B30",
    "crying_baby": "#0A84FF",
    "door_wood_knock": "#A2845E",
    "glass_breaking": "#30D158",
    "fireworks": "#BF5AF2",
    "car_horn": "#FF9500"
}

EMOJI = {
    "siren": "🚨",
    "crying_baby": "👶",
    "door_wood_knock": "🚪",
    "glass_breaking": "🪟",
    "fireworks": "🎆",
    "car_horn": "🚗"
}

# ==========================================================
# RECORDING SETTINGS
# ==========================================================

DEFAULT_RECORD_SECONDS = 5

REALTIME_INTERVAL = 5      # Automatically analyze every 5 seconds

CHANNELS = 1

DTYPE = "float32"

# ==========================================================
# CONFIDENCE
# ==========================================================

HIGH_CONFIDENCE = 0.90
MEDIUM_CONFIDENCE = 0.70
LOW_CONFIDENCE = 0.50