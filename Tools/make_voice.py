"""Generates the spoken workout cues with Cartesia and bundles them in the app.

    uv run --no-project Tools/make_voice.py

Reads CARTESIA_API_KEY from the environment, or from a `.env` file in this
project or its parent folder. Optional: CARTESIA_VOICE_ID for another voice.

Writes one short WAV per cue into C25K/Voice/, then run `xcodegen generate`.
The app plays these clips when the timer is on screen, and uses the same
files as notification sounds so the cue is spoken on the lock screen too.
Any cue without a clip falls back to the built-in iOS voice.

The key is only used here, at build time. It never ships inside the app.

Clip names are `<kind>-<seconds>.wav`, matching `Announcer.clipName` in
Swift. If the schedule in Program.swift gains a new interval length, add it
to CUES below and re-run.
"""

import json
import os
import sys
import urllib.error
import urllib.request
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "C25K" / "Voice"
VOICE_ID = os.environ.get("CARTESIA_VOICE_ID", "62ae83ad-4f6a-430b-af41-a9bede9286ca")  # "Gemma"
MODEL = "sonic-2"
API_VERSION = "2025-04-16"
RATE = 22050  # iOS notification sounds must be uncompressed PCM, under 30 s

# Every interval length in the schedule, by kind.
RUNS = [60, 90, 180, 300, 480, 600, 1200, 1500, 1680, 1800]
WALKS = [90, 120, 150, 180, 300]


def spoken(seconds: int) -> str:
    if seconds < 120 and seconds % 60:
        return f"{seconds} seconds"
    m, half = divmod(seconds, 60)
    if half == 30:
        return f"{m} and a half minutes"
    return "1 minute" if m == 1 else f"{m} minutes"


CUES: dict[str, str] = {
    "warmup-300": "Let's go! Start with a brisk warm-up walk. 5 minutes.",
    "cooldown-300": "Great work! Time for your cool-down walk. 5 minutes.",
    "finished": "Workout complete. Great job!",
    "finished-final": "Workout complete. You just finished Couch to 5K. You're a runner!",
    **{f"run-{s}": f"Start running. {spoken(s)}." for s in RUNS},
    **{f"walk-{s}": f"Start walking. {spoken(s)}." for s in WALKS},
}


def api_key() -> str:
    if key := os.environ.get("CARTESIA_API_KEY"):
        return key
    for env in (ROOT / ".env", ROOT.parent / ".env"):
        if env.is_file():
            for line in env.read_text().splitlines():
                name, _, value = line.partition("=")
                if name.strip() == "CARTESIA_API_KEY":
                    return value.strip().strip("'\"")
    sys.exit("Set CARTESIA_API_KEY, or add it to a .env file here or in the parent folder.")


def synthesize(text: str, key: str) -> bytes:
    """Raw 16-bit mono PCM."""
    body = {
        "model_id": MODEL,
        "transcript": text,
        "voice": {"mode": "id", "id": VOICE_ID},
        "output_format": {"container": "raw", "encoding": "pcm_s16le", "sample_rate": RATE},
        "language": "en",
    }
    req = urllib.request.Request(
        "https://api.cartesia.ai/tts/bytes",
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Cartesia-Version": API_VERSION,
                 "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"Cartesia returned {e.code}: {e.read().decode()[:300]}")


def main() -> None:
    key = api_key()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, text in CUES.items():
        pcm = synthesize(text, key)
        with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)  # 16-bit
            w.setframerate(RATE)
            w.writeframes(pcm)
        print(f"{name}.wav  {len(pcm) / 2 / RATE:4.1f}s  {text}")
    print(f"\nWrote {len(CUES)} clips to {OUT}. Now run: xcodegen generate")


if __name__ == "__main__":
    main()
