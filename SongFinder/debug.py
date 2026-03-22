"""Standalone debug script — run while a song is playing."""
import pyaudiowpatch as pyaudio
import numpy as np
import soundfile as sf
import requests
import io

CHUNK_SECONDS = 5

def record():
    p = pyaudio.PyAudio()
    wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)
    default_out = p.get_device_info_by_index(wasapi_info["defaultOutputDevice"])
    print(f"Default output: {default_out['name']}")

    loopback_dev = None
    for dev in p.get_loopback_device_info_generator():
        if default_out["name"] in dev["name"]:
            loopback_dev = dev
            break

    if loopback_dev is None:
        print("FEHLER: Kein Loopback-Device gefunden")
        p.terminate()
        return None, None

    sr       = int(loopback_dev["defaultSampleRate"])
    channels = loopback_dev["maxInputChannels"]
    chunk    = 1024
    n        = int(sr / chunk * CHUNK_SECONDS)
    print(f"Loopback: {loopback_dev['name']} | {sr} Hz | {channels} Kanäle")

    stream = p.open(format=pyaudio.paInt16, channels=channels,
                    rate=sr, input=True,
                    input_device_index=loopback_dev["index"])

    print(f"Nehme {CHUNK_SECONDS}s auf...")
    frames = [stream.read(chunk, exception_on_overflow=False) for _ in range(n)]
    stream.stop_stream()
    stream.close()
    p.terminate()

    raw   = b"".join(frames)
    audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    audio = audio.reshape(-1, channels)[:, :2]

    peak = np.abs(audio).max()
    rms  = np.sqrt(np.mean(audio**2))
    print(f"Audio-Peak: {peak:.4f}  RMS: {rms:.4f}", end="  ")
    if rms < 0.001:
        print("=> WARNUNG: Audio fast still! Läuft der Song laut genug?")
    else:
        print("=> Audio OK")

    return audio, sr

def send_to_audd(audio, sr):
    buf = io.BytesIO()
    sf.write(buf, audio, sr, format="WAV", subtype="PCM_16")
    buf.seek(0)
    wav_bytes = buf.read()
    print(f"WAV-Größe: {len(wav_bytes)} bytes")

    print("Sende an AudD...")
    try:
        resp = requests.post(
            "https://api.audd.io/",
            data={"return": "spotify,apple_music"},
            files={"audio": ("audio.wav", wav_bytes, "audio/wav")},
            timeout=15,
        )
        print(f"HTTP Status: {resp.status_code}")
        print(f"Antwort: {resp.text[:500]}")
    except Exception as e:
        print(f"Netzwerk-Fehler: {e}")

if __name__ == "__main__":
    audio, sr = record()
    if audio is not None:
        send_to_audd(audio, sr)
    input("\nEnter drücken zum Beenden...")
