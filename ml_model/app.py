import os
import tempfile
import time

import librosa
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import streamlit as st

from streamlit_mic_recorder import mic_recorder
import soundfile as sf

from audio_utils import (
    preprocess_audio,
    create_display_spectrogram,
    get_audio_rms
)

from model_utils import (
    ModelManager,
    top_predictions,
)

from config import *


# ==========================================================
# PAGE CONFIG
# ==========================================================

st.set_page_config(
    page_title="Emergency Sound Detection",
    page_icon="🚨",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ==========================================================
# CUSTOM CSS
# ==========================================================

st.markdown("""
<style>
.main{ padding-top:1rem; }
.block-container{ padding-top:2rem; }
.metric-container{ border-radius:10px; }
.big-font{ font-size:28px; font-weight:bold; }
.prediction-alert{ font-size:32px; color:#ff4b4b; font-weight:bold; }
.prediction-safe{ font-size:32px; color:#28a745; font-weight:bold; }
.confidence{ font-size:20px; color:#4A4A4A; }
</style>
""", unsafe_allow_html=True)

# ==========================================================
# CACHE MODELS
# ==========================================================

@st.cache_resource
def load_models():
    return ModelManager()

models = load_models()

# ==========================================================
# TITLE & SIDEBAR
# ==========================================================

st.title(APP_TITLE)
st.markdown(APP_DESCRIPTION)
st.divider()

with st.sidebar:
    st.header("⚙ Settings")
    model_choice = st.radio(
        "Choose Model",
        ["Keras", "TensorFlow Lite", "Compare Both"]
    )

    confidence_threshold = st.slider(
        "Confidence Threshold", 0.0, 1.0, 0.60, 0.05
    )

    enable_rms_gate = st.toggle("Enable Silence Gate", value=True)
    rms_threshold = st.slider(
        "Silence Threshold (RMS)", 0.001, 0.050, DEFAULT_RMS_THRESHOLD, 0.001,
        help="Clips below this energy level are classified directly as Background."
    )

    st.divider()

    st.subheader("Target Emergency Classes")
    for label in CLASS_NAMES:
        if label in EMERGENCY_CLASSES:
            st.write(f"{EMOJI[label]} `{label.replace('_', ' ').title()}`")

    st.subheader("Non-Emergency Class")
    st.write(f"{EMOJI['background']} `Background / Noise`")

# ==========================================================
# DISPLAY HELPERS
# ==========================================================

def show_prediction(result):
    pred = result['prediction']
    confidence = result['confidence']

    # Logic branch: Emergency vs Safe state
    if pred in EMERGENCY_CLASSES and confidence >= confidence_threshold:
        st.markdown(
            f"<div class='prediction-alert'>🚨 EMERGENCY DETECTED: {EMOJI[pred]} {pred.replace('_', ' ').title()}</div>",
            unsafe_allow_html=True
        )
    else:
        st.markdown(
            f"<div class='prediction-safe'>✅ STATUS NORMAL: {EMOJI['background']} No Emergency (Background)</div>",
            unsafe_allow_html=True
        )

    st.markdown(
        f"<div class='confidence'>Top Class Confidence: <b>{confidence*100:.2f}%</b></div>",
        unsafe_allow_html=True
    )
    st.metric("Inference Time", f"{result['time_ms']:.2f} ms")


def probability_chart(result):
    probs = result["probabilities"]
    df = pd.DataFrame({
        "Class": [c.replace("_", " ").title() for c in CLASS_NAMES], 
        "Probability": probs
    })
    st.bar_chart(df, x="Class", y="Probability", use_container_width=True)


def show_spectrogram(audio_path):
    mel = create_display_spectrogram(audio_path)
    fig, ax = plt.subplots(figsize=(8, 3.5))
    img = librosa.display.specshow(
        mel, sr=SAMPLE_RATE, hop_length=HOP_LENGTH, x_axis="time", y_axis="mel", ax=ax
    )
    plt.colorbar(img)
    st.pyplot(fig)

# ==========================================================
# INFERENCE PIPELINE RUNNER
# ==========================================================

def run_analysis(audio_path):
    rms_energy = get_audio_rms(audio_path)
    st.caption(f"Audio Energy Volume (RMS): `{rms_energy:.4f}`")

    # If audio is silent/low volume and RMS gate is active
    if enable_rms_gate and rms_energy < rms_threshold:
        st.info("ℹ Low volume / silence detected. Automatically categorized as **Background**.")
        
        # Artificial background result vector
        bg_probs = np.zeros(NUM_CLASSES)
        bg_probs[CLASS_NAMES.index("background")] = 1.0
        
        dummy_result = {
            "prediction": "background",
            "confidence": 1.0,
            "probabilities": bg_probs,
            "time_ms": 0.0
        }
        
        if model_choice == "Compare Both":
            col1, col2 = st.columns(2)
            with col1:
                st.subheader("Keras")
                show_prediction(dummy_result)
                probability_chart(dummy_result)
            with col2:
                st.subheader("TensorFlow Lite")
                show_prediction(dummy_result)
                probability_chart(dummy_result)
        else:
            show_prediction(dummy_result)
            probability_chart(dummy_result)
            
        st.subheader("Mel Spectrogram")
        show_spectrogram(audio_path)
        return

    # Standard model inference
    tensor = preprocess_audio(audio_path)

    if model_choice == "Keras":
        result = models.predict_keras(tensor)
        show_prediction(result)
        probability_chart(result)
        show_spectrogram(audio_path)
        st.subheader("Top Predictions")
        for item in top_predictions(result["probabilities"]):
            st.write(f"**{item['label'].replace('_', ' ').title()}**: {item['confidence']*100:.2f}%")

    elif model_choice == "TensorFlow Lite":
        result = models.predict_tflite(tensor)
        show_prediction(result)
        probability_chart(result)
        show_spectrogram(audio_path)
        st.subheader("Top Predictions")
        for item in top_predictions(result["probabilities"]):
            st.write(f"**{item['label'].replace('_', ' ').title()}**: {item['confidence']*100:.2f}%")

    else:
        comparison = models.compare(tensor)
        col1, col2 = st.columns(2)
        with col1:
            st.subheader("Keras")
            show_prediction(comparison["keras"])
            probability_chart(comparison["keras"])
        with col2:
            st.subheader("TensorFlow Lite")
            show_prediction(comparison["tflite"])
            probability_chart(comparison["tflite"])

        st.subheader("Mel Spectrogram")
        show_spectrogram(audio_path)

# ==========================================================
# MAIN TABS
# ==========================================================

tab_live, tab_upload = st.tabs(["🎤 Live Detection", "📁 Upload Audio"])

# --- LIVE DETECTION TAB ---
with tab_live:
    st.subheader("🎤 Live Microphone Detection")
    st.write("Press Record and speak or play an emergency sound.")

    audio = mic_recorder(
        start_prompt="🎤 Start Recording",
        stop_prompt="⏹ Stop Recording",
        just_once=False,
        use_container_width=True,
        key="mic"
    )

    if audio:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".webm") as temp_mic:
            temp_mic.write(audio["bytes"])
            temp_mic_path = temp_mic.name

        try:
            run_analysis(temp_mic_path)
        finally:
            if os.path.exists(temp_mic_path):
                os.remove(temp_mic_path)

# --- AUDIO UPLOAD TAB ---
with tab_upload:
    st.subheader("📁 Upload Audio")

    uploaded = st.file_uploader(
        "Upload an audio file",
        type=["wav", "mp3", "ogg", "flac"]
    )

    if uploaded is not None:
        st.audio(uploaded)

        ext = os.path.splitext(uploaded.name)[1].lower()

        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as temp_audio:
            temp_audio.write(uploaded.read())
            temp_audio_path = temp_audio.name

        try:
            run_analysis(temp_audio_path)
        finally:
            if os.path.exists(temp_audio_path):
                os.remove(temp_audio_path)

# ==========================================================
# FOOTER
# ==========================================================

st.divider()
st.caption(
    "Emergency Sound Detection Dashboard • "
    "TensorFlow • TensorFlow Lite • Streamlit"
)