import customtkinter as ctk
import sounddevice as sd
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


def record_loopback(duration: float, stop_event: threading.Event) -> np.ndarray | None:
    """Record system audio via WASAPI loopback (what the PC is playing)."""
    # sd.default.device[1] is the default output device index
    device_idx = sd.default.device[1]
    frames = int(duration * SAMPLE_RATE)
    wasapi = sd.WasapiSettings(loopback=True)

    recording = sd.rec(
        frames,
        samplerate=SAMPLE_RATE,
        channels=2,
        dtype="float32",
        device=device_idx,
        extra_settings=wasapi,
        blocking=False,
    )

    deadline = time.monotonic() + duration
    while time.monotonic() < deadline:
        if stop_event.is_set():
            sd.stop()
            return None
        time.sleep(0.05)

    sd.wait()
    return recording


def audio_to_wav_bytes(audio: np.ndarray) -> bytes:
    buf = io.BytesIO()
    sf.write(buf, audio, SAMPLE_RATE, format="WAV", subtype="PCM_16")
    buf.seek(0)
    return buf.read()


def query_audd(wav_bytes: bytes) -> dict | None:
    try:
        resp = requests.post(
            AUDD_ENDPOINT,
            data={"return": "spotify,apple_music"},
            files={"audio": ("audio.wav", wav_bytes, "audio/wav")},
            timeout=15,
        )
        data = resp.json()
        if data.get("status") == "success" and data.get("result"):
            return data["result"]
    except Exception:
        pass
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
        self.geometry("440x600")
        self.resizable(False, False)

        self._running   = False
        self._stop_evt  = threading.Event()
        self._history   = load_history()

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

        self.history_box = ctk.CTkScrollableFrame(self, height=170)
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
                audio = record_loopback(CHUNK_SECONDS, self._stop_evt)
            except Exception as exc:
                self._set_status(f"Audio-Fehler: {exc}", COLOR_ERR)
                self._reset_btn()
                return

            if self._stop_evt.is_set():
                self._set_status("Gestoppt", "gray")
                self._reset_btn()
                return

            self._set_status("Erkenne...", "white")
            wav = audio_to_wav_bytes(audio)
            result = query_audd(wav)

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
                fg_color=("gray85", "gray20"),
                corner_radius=6,
            )
            row.pack(fill="x", pady=2, padx=2)

            ctk.CTkLabel(
                row,
                text=f"{entry['title']}  —  {entry['artist']}",
                font=ctk.CTkFont(size=12, weight="bold"),
                anchor="w", wraplength=260,
            ).pack(side="left", padx=10, pady=6)

            ctk.CTkLabel(
                row,
                text=entry.get("time", ""),
                font=ctk.CTkFont(size=10),
                text_color="gray", anchor="e",
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
