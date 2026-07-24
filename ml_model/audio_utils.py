"""
audio_utils.py

Audio preprocessing utilities for the Emergency Sound Detection System.
"""

import os
import time
import tempfile
import subprocess
import numpy as np
import librosa
import sounddevice as sd
import soundfile as sf
import imageio_ffmpeg  # <-- Portable FFmpeg binary getter

from config import (
    SAMPLE_RATE,
    DURATION,
    SAMPLES,
    N_MELS,
    N_FFT,
    HOP_LENGTH,
    TOP_DB,
    MODEL_INPUT_SHAPE,
)

# --------------------------------------------------------
# Recording
# --------------------------------------------------------

def record_audio(
    duration=DURATION,
    sample_rate=SAMPLE_RATE,
    channels=1
):
    """
    Record audio from the default microphone.
    """
    print("Recording...")

    recording = sd.rec(
        int(duration * sample_rate),
        samplerate=sample_rate,
        channels=channels,
        dtype="float32"
    )

    sd.wait()
    print("Finished recording.")

    return recording.flatten()


# --------------------------------------------------------
# Save Recording
# --------------------------------------------------------

def save_recording(audio, filename):
    """
    Save microphone recording.
    """
    sf.write(
        filename,
        audio,
        SAMPLE_RATE
    )


# --------------------------------------------------------
# Load Audio (Fixed for Windows)
# --------------------------------------------------------

def load_audio(audio_path):
    """
    Load any audio format (WAV, MP3, WebM, OGG, etc.).
    Uses imageio-ffmpeg to locate FFmpeg reliably on Windows.
    """
    ext = os.path.splitext(audio_path)[1].lower()

    # Load directly if already standard WAV
    if ext == ".wav":
        audio, sr = librosa.load(audio_path, sr=SAMPLE_RATE, mono=True)
        return audio

    # Otherwise, convert to temporary .wav first
    wav_file = tempfile.NamedTemporaryFile(
        delete=False,
        suffix=".wav"
    ).name

    # Gets exact path to portable ffmpeg.exe installed by pip
    ffmpeg_executable = imageio_ffmpeg.get_ffmpeg_exe()

    try:
        subprocess.run(
            [
                ffmpeg_executable,
                "-y",
                "-i", audio_path,
                "-ar", str(SAMPLE_RATE),
                "-ac", "1",
                wav_file
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )

        audio, sr = librosa.load(
            wav_file,
            sr=SAMPLE_RATE,
            mono=True
        )

    finally:
        if os.path.exists(wav_file):
            os.remove(wav_file)

    return audio


# --------------------------------------------------------
# Fix Length
# --------------------------------------------------------

def fix_audio_length(audio):
    """
    Pad or trim to exactly 5 seconds.
    """
    if len(audio) > SAMPLES:
        audio = audio[:SAMPLES]
    elif len(audio) < SAMPLES:
        padding = SAMPLES - len(audio)
        audio = np.pad(
            audio,
            (0, padding),
            mode="constant"
        )

    return audio


# --------------------------------------------------------
# Mel Spectrogram
# --------------------------------------------------------

def audio_to_mel(audio):
    """
    Convert waveform to Log-Mel Spectrogram.
    """
    mel = librosa.feature.melspectrogram(
        y=audio,
        sr=SAMPLE_RATE,
        n_fft=N_FFT,
        hop_length=HOP_LENGTH,
        n_mels=N_MELS,
        power=2.0
    )

    mel_db = librosa.power_to_db(
        mel,
        ref=np.max,
        top_db=TOP_DB
    )

    return mel_db


# --------------------------------------------------------
# Resize
# --------------------------------------------------------

def resize_spectrogram(mel):
    """
    Ensure width = 216 frames.
    """
    target_width = MODEL_INPUT_SHAPE[1]
    current_width = mel.shape[1]

    if current_width < target_width:
        pad = target_width - current_width
        mel = np.pad(
            mel,
            ((0, 0), (0, pad)),
            mode="constant"
        )
    elif current_width > target_width:
        mel = mel[:, :target_width]

    return mel


# --------------------------------------------------------
# Normalize
# --------------------------------------------------------

def normalize(mel):
    """
    Normalize spectrogram.
    """
    mean = np.mean(mel)
    std = np.std(mel)

    mel = (mel - mean) / (std + 1e-8)

    return mel


# --------------------------------------------------------
# Full Pipeline
# --------------------------------------------------------

def preprocess_audio(audio_path):
    """
    Complete preprocessing pipeline.
    """
    audio = load_audio(audio_path)
    audio = fix_audio_length(audio)
    mel = audio_to_mel(audio)
    mel = resize_spectrogram(mel)
    mel = normalize(mel)

    mel = mel.astype(np.float32)
    mel = np.expand_dims(mel, axis=-1)
    mel = np.expand_dims(mel, axis=0)

    return mel


# --------------------------------------------------------
# Temporary Recording
# --------------------------------------------------------

def record_to_tempfile():
    audio = record_audio()
    temp = tempfile.NamedTemporaryFile(
        delete=False,
        suffix=".wav"
    )
    save_recording(audio, temp.name)
    return temp.name


# --------------------------------------------------------
# Spectrogram Display
# --------------------------------------------------------

def create_display_spectrogram(audio_path):
    """
    Used for Streamlit visualization.
    """
    audio = load_audio(audio_path)
    audio = fix_audio_length(audio)
    mel = audio_to_mel(audio)

    return mel