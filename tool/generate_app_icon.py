#!/usr/bin/env python3
"""Generate Rostiq production icon assets from the Concept A artwork.

Produces, under frontend/assets/branding/:
  - rostiq_icon_master_1024.png   full-bleed square master (iOS / web / store)
  - rostiq_adaptive_fg.png        transparent monogram, Android safe-zone padded
  - rostiq_adaptive_bg.png        burgundy->oxblood gradient background
And copies the master to frontend/assets/images/logo.png for in-app use.

The gold monogram is extracted from the (landscape, white-margined) source
render via colour keying, then composited onto a freshly synthesized gradient
so the burgundy reaches every edge (OS masking rounds/crops it).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else None
HERE = Path(__file__).resolve().parent
FRONTEND = HERE.parent
BRANDING = FRONTEND / "assets" / "branding"
IMAGES = FRONTEND / "assets" / "images"

SIZE = 1024
TOP = (0x7A, 0x1F, 0x1F)   # AppColors.primary  (burgundy)
BOT = (0x4A, 0x0F, 0x0F)   # AppColors.primaryDark (oxblood)


def gradient_bg(size: int = SIZE) -> Image.Image:
    y = np.linspace(0.0, 1.0, size)[:, None]
    grad = np.zeros((size, size, 3), dtype=np.float64)
    for i in range(3):
        grad[..., i] = TOP[i] + (BOT[i] - TOP[i]) * y
    # subtle radial highlight, upper-centre, to echo the original render
    yy, xx = np.mgrid[0:size, 0:size]
    cx, cy = size * 0.5, size * 0.34
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size * 0.72)
    high = np.clip(1.0 - r, 0.0, 1.0) ** 2
    grad += (high * 24.0)[..., None]
    grad = np.clip(grad, 0, 255).astype(np.uint8)
    return Image.fromarray(grad, "RGB")


def extract_monogram(src_path: Path) -> Image.Image:
    src = Image.open(src_path).convert("RGB")
    a = np.asarray(src).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # gold: high red, mid-high green, low blue, strong yellow separation
    gold = (g > 95) & (b < 145) & (r > 150) & ((g - b) > 55)
    mask = (gold.astype(np.uint8)) * 255
    mimg = Image.fromarray(mask, "L").filter(ImageFilter.GaussianBlur(0.8))
    rgba = np.dstack([np.asarray(src), np.asarray(mimg)]).astype(np.uint8)
    mono = Image.fromarray(rgba, "RGBA")
    bbox = mono.getbbox()
    if bbox is None:
        raise SystemExit("No gold monogram detected; tune the colour key.")
    return mono.crop(bbox)


def place(base: Image.Image, fg: Image.Image, scale: float,
          dy: float = 0.0) -> Image.Image:
    bw, bh = base.size
    target = int(bw * scale)
    w, h = fg.size
    f = target / max(w, h)
    nf = fg.resize((max(1, int(w * f)), max(1, int(h * f))), Image.LANCZOS)
    x = (bw - nf.width) // 2
    y = int((bh - nf.height) // 2 + dy * bh)
    out = base.convert("RGBA").copy()
    out.alpha_composite(nf, (x, y))
    return out


def main() -> None:
    if SRC is None or not SRC.exists():
        raise SystemExit(f"Source image not found: {SRC}")
    BRANDING.mkdir(parents=True, exist_ok=True)
    IMAGES.mkdir(parents=True, exist_ok=True)

    bg = gradient_bg()
    mono = extract_monogram(SRC)

    # Master: monogram fills ~72% of the tile, centred.
    master = place(bg, mono, scale=0.72).convert("RGB")
    master.save(BRANDING / "rostiq_icon_master_1024.png")

    # Android adaptive background (gradient only).
    bg.save(BRANDING / "rostiq_adaptive_bg.png")

    # Android adaptive foreground: transparent elsewhere. flutter_launcher_icons
    # adds a further 16% inset (drawable scaled to ~0.68), so 0.82 here lands the
    # monogram at ~0.56 of the visible tile -- inside the safe zone with margin.
    transparent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fg = place(transparent, mono, scale=0.82)
    fg.save(BRANDING / "rostiq_adaptive_fg.png")

    # In-app logo (login/gateway use ClipOval -> burgundy disc + monogram).
    master.save(IMAGES / "logo.png")

    print("Wrote:")
    for p in [
        BRANDING / "rostiq_icon_master_1024.png",
        BRANDING / "rostiq_adaptive_bg.png",
        BRANDING / "rostiq_adaptive_fg.png",
        IMAGES / "logo.png",
    ]:
        print("  ", p.relative_to(FRONTEND))


if __name__ == "__main__":
    main()
