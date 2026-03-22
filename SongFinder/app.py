import ctypes
ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("SongFinder")

import customtkinter as ctk
import pyaudiowpatch as pyaudio
import numpy as np
import soundfile as sf
import requests
import json
import threading
import io
import time
import webbrowser
from datetime import datetime
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────
SAMPLE_RATE    = 44100
CHUNK_SECONDS  = 5      # seconds per recognition attempt
MAX_SECONDS    = 30     # give up after this many seconds
MAX_HISTORY    = 20
HISTORY_FILE   = Path(__file__).parent / "history.json"
AUDD_ENDPOINT  = "https://api.audd.io/"

# ── Helpers ───────────────────────────────────────────────────────────────────
def load_history() -> list:
    if HISTORY_FILE.exists():
        try:
            return json.loads(HISTORY_FILE.read_text(encoding="utf-8"))
        except Exception:
            return []
    return []


def save_history(history: list) -> None:
    HISTORY_FILE.write_text(
        json.dumps(history, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def record_loopback(duration: float, stop_event: threading.Event):
    """Record system audio via WASAPI loopback (what the PC is playing).
    Returns (audio_array, sample_rate) or (None, None) if stopped."""
    p = pyaudio.PyAudio()
    try:
        wasapi_info  = p.get_host_api_info_by_type(pyaudio.paWASAPI)
        default_out  = p.get_device_info_by_index(wasapi_info["defaultOutputDevice"])

        # Find the loopback device matching the default output
        loopback_dev = None
        for dev in p.get_loopback_device_info_generator():
            if default_out["name"] in dev["name"]:
                loopback_dev = dev
                break
        if loopback_dev is None:
            raise RuntimeError("Kein WASAPI-Loopback-Device gefunden")

        sample_rate = int(loopback_dev["defaultSampleRate"])
        channels    = loopback_dev["maxInputChannels"]
        chunk_size  = 1024
        n_chunks    = int(sample_rate / chunk_size * duration)

        stream = p.open(
            format=pyaudio.paInt16,
            channels=channels,
            rate=sample_rate,
            input=True,
            input_device_index=loopback_dev["index"],
        )

        frames = []
        for _ in range(n_chunks):
            if stop_event.is_set():
                stream.stop_stream()
                stream.close()
                return None, None
            frames.append(stream.read(chunk_size, exception_on_overflow=False))

        stream.stop_stream()
        stream.close()
    finally:
        p.terminate()

    raw   = b"".join(frames)
    audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    audio = audio.reshape(-1, channels)
    # AudD erwartet Stereo — erste 2 Kanäle nehmen (oder mono duplizieren)
    if channels >= 2:
        audio = audio[:, :2]
    else:
        audio = np.column_stack([audio, audio])
    return audio, sample_rate


def query_audd(audio: np.ndarray, sample_rate: int) -> dict | None:
    import tempfile, os, wave
    # Write to a real temp file — most reliable way to send to requests
    audio_int16 = (np.clip(audio, -1.0, 1.0) * 32767).astype(np.int16)
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.close()
    try:
        with wave.open(tmp.name, "wb") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(audio_int16.tobytes())
        with open(tmp.name, "rb") as f:
            resp = requests.post(
                AUDD_ENDPOINT,
                data={"return": "spotify,apple_music", "api_token": "f270b9cb50c74583398864227f393086"},
                files={"file": ("audio.wav", f, "audio/wav")},
                timeout=15,
            )
        data = resp.json()
        if data.get("status") == "success" and data.get("result"):
            return data["result"]
    except Exception:
        pass
    finally:
        os.unlink(tmp.name)
    return None


# ── App ───────────────────────────────────────────────────────────────────────
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

BTN_BLUE   = ("#3B8ED0", "#1F6AA5")
BTN_HOVER  = ("#36719F", "#144870")
BTN_RED    = "#c94444"
BTN_RED_H  = "#a83535"
COLOR_OK   = "#4CAF50"
COLOR_ERR  = "#ff6b6b"


class SongFinder(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("SongFinder")
        self.geometry("440x660")
        self.resizable(False, False)

        self._running   = False
        self._stop_evt  = threading.Event()
        self._history   = load_history()

        icon_path = Path(__file__).parent / "icon.ico"
        if icon_path.exists():
            self.iconbitmap(str(icon_path))

        self._build_ui()
        self._render_history()

    # ── UI ────────────────────────────────────────────────────────────────────
    def _build_ui(self):
        # Title
        ctk.CTkLabel(
            self, text="SongFinder",
            font=ctk.CTkFont(size=26, weight="bold")
        ).pack(pady=(28, 4))

        ctk.CTkLabel(
            self, text="Erkennt Musik die gerade auf dem PC läuft",
            font=ctk.CTkFont(size=12), text_color="gray"
        ).pack(pady=(0, 16))

        # Recognize button
        self.btn = ctk.CTkButton(
            self, text="Erkennen",
            font=ctk.CTkFont(size=16, weight="bold"),
            width=210, height=52,
            command=self._toggle,
        )
        self.btn.pack(pady=(0, 8))

        # Status
        self.lbl_status = ctk.CTkLabel(
            self, text="Bereit",
            font=ctk.CTkFont(size=13), text_color="gray"
        )
        self.lbl_status.pack(pady=(0, 14))

        # Result card
        self.card = ctk.CTkFrame(self, corner_radius=10)
        self.card.pack(padx=24, pady=(0, 6), fill="x")

        self.lbl_title = ctk.CTkLabel(
            self.card, text="",
            font=ctk.CTkFont(size=16, weight="bold"), wraplength=370
        )
        self.lbl_title.pack(pady=(14, 2), padx=16)

        self.lbl_artist = ctk.CTkLabel(
            self.card, text="",
            font=ctk.CTkFont(size=13), text_color="gray"
        )
        self.lbl_artist.pack(pady=(0, 10), padx=16)

        # Link buttons (hidden until a result arrives)
        self.links_row = ctk.CTkFrame(self.card, fg_color="transparent")
        self.links_row.pack(pady=(0, 12))

        self.btn_spotify = ctk.CTkButton(
            self.links_row, text="Spotify",
            width=120, height=30,
            fg_color="#1DB954", hover_color="#17a349",
        )
        self.btn_apple = ctk.CTkButton(
            self.links_row, text="Apple Music",
            width=130, height=30,
            fg_color="#fc3c44", hover_color="#e0353c",
        )

        # History
        ctk.CTkLabel(
            self, text="Verlauf",
            font=ctk.CTkFont(size=14, weight="bold"), anchor="w"
        ).pack(anchor="w", padx=24, pady=(8, 4))

        self.history_box = ctk.CTkScrollableFrame(self, height=210)
        self.history_box.pack(padx=24, pady=(0, 16), fill="x")

    # ── Button toggle ─────────────────────────────────────────────────────────
    def _toggle(self):
        if self._running:
            self._request_stop()
        else:
            self._start()

    def _start(self):
        self._running = True
        self._stop_evt.clear()
        self.btn.configure(text="Stopp", fg_color=BTN_RED, hover_color=BTN_RED_H)
        self._set_status("Höre zu...", "white")
        self._clear_result()
        threading.Thread(target=self._recognition_loop, daemon=True).start()

    def _request_stop(self):
        self._stop_evt.set()

    # ── Recognition loop (runs in thread) ─────────────────────────────────────
    def _recognition_loop(self):
        elapsed = 0
        attempt = 0

        while not self._stop_evt.is_set() and elapsed < MAX_SECONDS:
            attempt += 1
            self._set_status(f"Versuch {attempt} — nehme {CHUNK_SECONDS}s auf...", "white")

            try:
                audio, sr = record_loopback(CHUNK_SECONDS, self._stop_evt)
            except Exception as exc:
                self._set_status(f"Audio-Fehler: {exc}", COLOR_ERR)
                self._reset_btn()
                return

            if self._stop_evt.is_set():
                self._set_status("Gestoppt", "gray")
                self._reset_btn()
                return

            self._set_status("Erkenne...", "white")
            result = query_audd(audio, sr)

            if result:
                self._on_found(result)
                return

            elapsed += CHUNK_SECONDS

        if not self._stop_evt.is_set():
            self._set_status("Kein Song erkannt", COLOR_ERR)
        else:
            self._set_status("Gestoppt", "gray")

        self._reset_btn()

    # ── Result handling ───────────────────────────────────────────────────────
    def _on_found(self, result: dict):
        title   = result.get("title", "Unbekannt")
        artist  = result.get("artist", "Unbekannt")

        spotify_url = None
        apple_url   = None
        try:
            spotify_url = result["spotify"]["external_urls"]["spotify"]
        except (KeyError, TypeError):
            pass
        try:
            apple_url = result["apple_music"]["url"]
        except (KeyError, TypeError):
            pass

        # Update UI (thread-safe via after)
        self.after(0, lambda: self._show_result(title, artist, spotify_url, apple_url))

        # Save to history
        entry = {
            "title":   title,
            "artist":  artist,
            "spotify": spotify_url,
            "apple":   apple_url,
            "time":    datetime.now().strftime("%d.%m.%Y %H:%M"),
        }
        self._history.insert(0, entry)
        self._history = self._history[:MAX_HISTORY]
        save_history(self._history)

        self.after(0, self._render_history)
        self._set_status("Erkannt!", COLOR_OK)
        self._reset_btn()

    def _show_result(self, title: str, artist: str, spotify_url, apple_url):
        self.lbl_title.configure(text=title)
        self.lbl_artist.configure(text=artist)

        for w in self.links_row.winfo_children():
            w.pack_forget()

        if spotify_url:
            self.btn_spotify.configure(command=lambda: webbrowser.open(spotify_url))
            self.btn_spotify.pack(side="left", padx=5)
        if apple_url:
            self.btn_apple.configure(command=lambda: webbrowser.open(apple_url))
            self.btn_apple.pack(side="left", padx=5)

    def _clear_result(self):
        self.lbl_title.configure(text="")
        self.lbl_artist.configure(text="")
        for w in self.links_row.winfo_children():
            w.pack_forget()

    # ── History ───────────────────────────────────────────────────────────────
    def _render_history(self):
        for w in self.history_box.winfo_children():
            w.destroy()

        if not self._history:
            ctk.CTkLabel(
                self.history_box, text="Noch keine Songs erkannt",
                text_color="gray", font=ctk.CTkFont(size=12)
            ).pack(pady=10)
            return

        for entry in self._history:
            row = ctk.CTkFrame(
                self.history_box,
                fg_color=("gray78", "#484848"),
                corner_radius=6,
            )
            row.pack(fill="x", pady=3, padx=2)

            ctk.CTkLabel(
                row,
                text=f"{entry['title']}  —  {entry['artist']}",
                font=ctk.CTkFont(size=13, weight="bold"),
                anchor="w", wraplength=255, text_color=("gray10", "white"),
            ).pack(side="left", padx=10, pady=8)

            ctk.CTkLabel(
                row,
                text=entry.get("time", ""),
                font=ctk.CTkFont(size=10),
                text_color=("gray30", "gray70"), anchor="e",
            ).pack(side="right", padx=10)

    # ── Helpers ───────────────────────────────────────────────────────────────
    def _set_status(self, text: str, color: str = "gray"):
        self.after(0, lambda: self.lbl_status.configure(text=text, text_color=color))

    def _reset_btn(self):
        self._running = False
        self.after(0, lambda: self.btn.configure(
            text="Erkennen", fg_color=BTN_BLUE, hover_color=BTN_HOVER
        ))


if __name__ == "__main__":
    app = SongFinder()
    app.mainloop()
