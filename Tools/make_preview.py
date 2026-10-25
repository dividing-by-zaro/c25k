"""Makes docs/voice-preview.mp4: a short captioned clip of the voice cues.

    uv run --no-project --with pillow python Tools/make_preview.py

Needs ffmpeg (`brew install ffmpeg`). Each cue from C25K/Voice is shown as
a caption on the app's green background while it plays. The clip is 16:9
at 640x360, so GitHub shows it at a natural size on desktop and scales it
down on phones.
"""

import subprocess
import tempfile
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
VOICE = ROOT / "C25K" / "Voice"
OUT = ROOT / "docs" / "voice-preview.mp4"

W, H = 640, 360
SS = 2      # captions drawn at 2x, then scaled down for smooth edges
GAP = 0.6   # seconds of quiet after each cue
FONT = "/System/Library/Fonts/SFNSRounded.ttf"

FOREST, PINE, FERN, MINT = (23, 61, 47), (46, 94, 78), (79, 138, 107), (226, 239, 230)

# (clip, label above the caption, caption): the words Gemma says, with
# line breaks placed by hand.
CUES = [
    ("warmup-300", "WARM-UP", "Let's go! Start with a brisk\nwarm-up walk. 5 minutes."),
    ("run-90", "RUN", "Start running. 90 seconds."),
    ("walk-120", "WALK", "Start walking. 2 minutes."),
    ("cooldown-300", "COOL-DOWN", "Great work! Time for your\ncool-down walk. 5 minutes."),
    ("finished", "DONE", "Workout complete. Great job!"),
]


def background() -> Image.Image:
    """Forest green at the top-left, easing to fern at the bottom-right."""
    img = Image.new("RGB", (W * SS, H * SS))
    px = img.load()
    for y in range(H * SS):
        for x in range(W * SS):
            t = (x / (W * SS) * 0.4 + y / (H * SS) * 0.6)
            a, b, u = (FOREST, PINE, t * 2) if t < 0.5 else (PINE, FERN, (t - 0.5) * 2)
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * u) for i in range(3))
    return img


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, size * SS)
    f.set_variation_by_name(weight)  # SF Rounded is a variable font
    return f


def wrap(draw, text, font, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=font) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def card(bg: Image.Image, label: str, caption: str) -> Image.Image:
    img = bg.copy()
    d = ImageDraw.Draw(img)
    small = font(15, "Semibold")
    big = font(34, "Bold")
    d.text((W * SS / 2, 70 * SS), label, font=small, fill=MINT, anchor="mm")
    lines = [l for part in caption.split("\n") for l in wrap(d, part, big, (W - 80) * SS)]
    lh = 44 * SS
    top = H * SS / 2 - (len(lines) - 1) * lh / 2 + 6 * SS
    for i, line in enumerate(lines):
        d.text((W * SS / 2, top + i * lh), line, font=big, fill="white", anchor="mm")
    d.text((W * SS / 2, (H - 36) * SS), "Couch to 5K  |  Gemma voice by Cartesia",
           font=small, fill=MINT + (180,), anchor="mm")
    return img.resize((W, H), Image.LANCZOS)


def main() -> None:
    bg = background()
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        frames, audio = [], b""
        for i, (clip, label, caption) in enumerate(CUES):
            with wave.open(str(VOICE / f"{clip}.wav")) as w:
                rate = w.getframerate()
                pcm = w.readframes(w.getnframes())
            pcm += b"\x00\x00" * int(rate * GAP)
            audio += pcm
            frame = tmp / f"{i}.png"
            card(bg, label, caption).save(frame)
            frames.append((frame, len(pcm) / 2 / rate))

        with wave.open(str(tmp / "audio.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(audio)

        # ffmpeg's concat list: each caption held for its cue's length.
        listing = "".join(f"file '{f}'\nduration {d:.3f}\n" for f, d in frames)
        listing += f"file '{frames[-1][0]}'\n"
        (tmp / "frames.txt").write_text(listing)

        OUT.parent.mkdir(exist_ok=True)
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "concat", "-safe", "0", "-i", str(tmp / "frames.txt"),
            "-i", str(tmp / "audio.wav"),
            "-vf", "fps=10,format=yuv420p", "-c:v", "libx264", "-tune", "stillimage",
            "-c:a", "aac", "-b:a", "96k", "-shortest", "-movflags", "+faststart",
            str(OUT),
        ], check=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
