"""Puts each simulator screenshot inside a drawn iPhone frame for the README.

    uv run --no-project --with pillow python Tools/frame_screenshots.py

Reads screenshots/*.png and writes screenshots/framed/*.png: a black bezel,
a thin titanium edge, side buttons and a soft shadow, on a transparent
background. The Dynamic Island is already part of the screenshot.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "screenshots"
OUT = SRC / "framed"

SS = 4  # drawn at 4x and downsampled, so curves stay smooth

EDGE = (58, 58, 62)       # titanium rim
BEZEL = (12, 12, 12)
BUTTON = (44, 44, 48)


def rounded(size, box, radius, fill):
    """An antialiased rounded rectangle on a transparent layer."""
    big = Image.new("RGBA", (size[0] * SS, size[1] * SS), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle(
        [v * SS for v in box], radius=radius * SS, fill=fill)
    return big.resize(size, Image.LANCZOS)


def frame(shot: Image.Image) -> Image.Image:
    w, h = shot.size
    bezel = round(w * 0.045)
    rim = max(2, round(w * 0.008))
    screen_r = round(w * 0.135)          # iPhone screen corners ≈ 13.5% of width
    pad = round(w * 0.09)                # room for buttons and shadow
    body_w, body_h = w + 2 * bezel, h + 2 * bezel
    size = (body_w + 2 * pad, body_h + 2 * pad)
    x0, y0 = pad, pad
    body = [x0, y0, x0 + body_w, y0 + body_h]
    body_r = screen_r + bezel

    canvas = Image.new("RGBA", size, (0, 0, 0, 0))

    # Soft drop shadow under the phone.
    shadow = rounded(size, [x0, y0 + w * 0.03, x0 + body_w, y0 + body_h + w * 0.03],
                     body_r, (0, 0, 0, 70))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(w * 0.03)))

    # Side buttons, poking out past the rim: action + volume left, power right.
    bw = round(w * 0.012)
    for side, top, bottom in [("l", 0.165, 0.205), ("l", 0.255, 0.325),
                              ("l", 0.35, 0.42), ("r", 0.28, 0.40)]:
        bx = x0 - bw if side == "l" else x0 + body_w - 1
        canvas.alpha_composite(rounded(size, [bx, y0 + body_h * top, bx + bw + 1,
                                              y0 + body_h * bottom], bw, BUTTON + (255,)))

    canvas.alpha_composite(rounded(size, body, body_r, EDGE + (255,)))
    canvas.alpha_composite(rounded(size, [body[0] + rim, body[1] + rim, body[2] - rim,
                                          body[3] - rim], body_r - rim, BEZEL + (255,)))

    # The screenshot itself, clipped to the screen's rounded corners.
    mask = rounded(size, [x0 + bezel, y0 + bezel, x0 + bezel + w, y0 + bezel + h],
                   screen_r, (255, 255, 255, 255)).getchannel("A")
    screen = Image.new("RGBA", size, (0, 0, 0, 0))
    screen.paste(shot.convert("RGBA"), (x0 + bezel, y0 + bezel))
    screen.putalpha(mask)
    canvas.alpha_composite(screen)
    return canvas


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for path in sorted(SRC.glob("*.png")):
        frame(Image.open(path)).save(OUT / path.name, optimize=True)
        print(f"framed {path.name}")


if __name__ == "__main__":
    main()
