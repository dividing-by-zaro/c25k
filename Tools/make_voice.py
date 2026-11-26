"""Generates the spoken workout cues with Cartesia and bundles them in the app.

    uv run --no-project Tools/make_voice.py          # only the missing clips
    uv run --no-project Tools/make_voice.py --all    # remake every clip

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
PLAN_RUNS = [60, 90, 180, 300, 480, 600, 1200, 1500, 1680, 1800]
PLAN_WALKS = [90, 120, 150, 180, 300]

# The lengths the workout builder offers, matching `BlockOptions` in
# CustomWorkout.swift: whole run or walk blocks, and the two halves of an
# interval.
BLOCK_MINUTES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 35, 40, 45, 50, 60]
INTERVAL_SECONDS = [30, 45, 60, 90, 120, 180, 240, 300]
BUILDER = sorted({m * 60 for m in BLOCK_MINUTES} | set(INTERVAL_SECONDS))

RUNS = sorted(set(PLAN_RUNS) | set(BUILDER))
WALKS = sorted(set(PLAN_WALKS) | set(BUILDER))

# Check-ins every 5 minutes during a long run block, up to 40 minutes.
# Clip names are `mark-<seconds>`, matching `Announcer.cheer`.
MARKS = {
    300: "5 minutes. Great job!",
    600: "Nice work. That's 10 minutes.",
    900: "15 minutes. Keep it up!",
    1200: "20 minutes. You're doing great!",
    1500: "25 minutes. Strong and steady.",
    1800: "30 minutes. Amazing work!",
    2100: "35 minutes. Keep going!",
    2400: "40 minutes. You're incredible!",
}


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
    **{f"mark-{s}": text for s, text in MARKS.items()},
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
    # Keep clips that already exist, so a new cue doesn't re-roll the old
    # ones. Pass --all to remake every clip (after changing the voice, say).
    remake = "--all" in sys.argv
    made = 0
    for name, text in CUES.items():
        if not remake and (OUT / f"{name}.wav").exists():
            continue
        made += 1
        pcm = synthesize(text, key)
        with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)  # 16-bit
            w.setframerate(RATE)
            w.writeframes(pcm)
        print(f"{name}.wav  {len(pcm) / 2 / RATE:4.1f}s  {text}")
    print(f"\nWrote {made} clips to {OUT}. Now run: xcodegen generate")


if __name__ == "__main__":
    main()
