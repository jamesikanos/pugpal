"""Compose PugPal wallpapers from the pug cutout.

    local/venv-branding/bin/python -I branding/tools/wallpaper.py CUTOUT OUTDIR [WxH]

Writes OUTDIR/pugpal-photo.png (the boys in colour) and
OUTDIR/pugpal-duotone.png (the boys mapped ink -> cream, for the lock
screen). FieldPal language: flat ink ground, one hard orange block, no
gradients or shadows. Fonts are read from local/fonts (Archivo, IBM Plex Mono).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

INK = "#16171a"
INK_LINE = "#2D2D2D"
CREAM = "#f1e4d9"
MUTED = "#9c978e"
ORANGE = "#E8480F"
ORANGE_BRIGHT = "#ff6b2c"
FONTS = Path("local/fonts")


def font(name: str, size: int, variation: str | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONTS / name), size)
    if variation:
        f.set_variation_by_name(variation)
    return f


def compose(cut: Image.Image, w: int, h: int) -> Image.Image:
    s = h / 1440  # layout is designed at 2560x1440 and scales with height
    canvas = Image.new("RGB", (w, h), INK)
    d = ImageDraw.Draw(canvas)

    # The pugs sit on the bottom edge, right of centre, 82% of the height tall.
    ph = int(h * 0.82)
    pw = int(cut.width * ph / cut.height)
    pugs = cut.resize((pw, ph), Image.LANCZOS)
    px = int(w * 0.93) - pw
    py = h - ph + int(40 * s)  # paws slightly cropped by the bottom edge

    # One hard orange block behind them, poster-style: the pugs overflow it.
    bx0, by0 = px + int(pw * 0.16), int(h * 0.30)
    d.rectangle([bx0, by0, px + int(pw * 0.88), h], fill=ORANGE)
    canvas.paste(pugs, (px, py), pugs)

    # Wordmark, left.
    x = int(150 * s)
    d.rectangle([x, int(560 * s), x + int(36 * s), int(596 * s)], fill=ORANGE_BRIGHT)
    d.text((x, int(610 * s)), "PUGPAL", font=font("Archivo-VF.ttf", int(150 * s), "Bold"), fill=CREAM)
    mono = font("IBMPlexMono-Medium.ttf", int(26 * s))
    d.text((x + int(6 * s), int(800 * s)), "VINNIE & JESSE  /  EST. 2012", font=mono, fill=MUTED)
    d.line([x, int(860 * s), x + int(560 * s), int(860 * s)], fill=INK_LINE, width=max(2, int(2 * s)))
    small = font("IBMPlexMono-Regular.ttf", int(20 * s))
    d.text((x + int(6 * s), int(880 * s)), "fedora atomic  ·  hyprland  ·  bootc", font=small, fill=MUTED)
    return canvas


def duotone(cut: Image.Image) -> Image.Image:
    alpha = cut.getchannel("A")
    grey = ImageOps.autocontrast(cut.convert("L"), cutoff=1)
    tone = ImageOps.colorize(grey, black="#110a09", white=CREAM, mid="#9c978e")
    tone.putalpha(alpha)
    return tone


def main() -> None:
    cut = Image.open(sys.argv[1]).convert("RGBA")
    out = Path(sys.argv[2])
    w, h = map(int, (sys.argv[3] if len(sys.argv) > 3 else "2560x1440").split("x"))
    out.mkdir(parents=True, exist_ok=True)
    compose(cut, w, h).save(out / "pugpal-photo.png", optimize=True)
    compose(duotone(cut), w, h).save(out / "pugpal-duotone.png", optimize=True)
    print(f"wrote {out}/pugpal-photo.png and pugpal-duotone.png at {w}x{h}")


if __name__ == "__main__":
    main()
