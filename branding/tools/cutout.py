"""Cut the pugs out of a photo with an ML background remover.

    local/venv-branding/bin/python -I branding/tools/cutout.py SRC OUT [MODEL]

Writes OUT (transparent PNG, cropped to the pugs) and OUT-ink.png (preview on
the PugPal ink colour). Models download to $U2NET_HOME - keep that under
local/ so nothing lands outside the project. The source photos are private
and live in gitignored local/branding/source/.
"""
import sys
from pathlib import Path

from PIL import Image
from rembg import new_session, remove

INK = (0x16, 0x17, 0x1A)


def main() -> None:
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    model = sys.argv[3] if len(sys.argv) > 3 else "birefnet-portrait"
    im = Image.open(src).convert("RGB")
    cut = remove(im, session=new_session(model))
    cut = cut.crop(cut.getbbox())
    cut.save(out)
    preview = Image.new("RGB", cut.size, INK)
    preview.paste(cut, (0, 0), cut)
    preview.save(out.with_name(out.stem + "-ink.png"))
    print(f"{out}: {cut.size[0]}x{cut.size[1]} ({model})")


if __name__ == "__main__":
    main()
