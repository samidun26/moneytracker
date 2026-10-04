#!/usr/bin/env python3
"""Builds ios/Duit/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024x1024,
opaque) from the pixel-art credit-card picture.

The source is a pixel-art sprite (about 11.2 px per art pixel, on a grid that
doesn't line up with the picture's frame) over a smooth pastel background. A
plain resize would blur the pixel edges, so the background and the sprite are
handled separately:

  1. fit the art-pixel grid (pitch and offset) from where the edges fall,
     and read one colour per art pixel,
  2. work out which art pixels are sprite (outline, cards, shadow) and which
     are background: background = light, low-saturation pixels reachable from
     the picture's edge,
  3. fill the sprite area of the original with the surrounding background
     (diffusion) and resize that smoothly to 1024,
  4. paint the sprite pixels back on top, square and crisp (nearest
     neighbour), at the same scale.

Usage: python3 make_app_icon.py <source.jpg> <out.png>
Needs Pillow and NumPy (pip install pillow numpy).
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

OUT = 1024


def fit_axis(a, axis):
    """Best (pitch, offset) of the art-pixel grid along one axis."""
    g = np.abs(np.diff(a, axis=axis)).sum(axis=2).sum(axis=1 - axis)
    pos = np.arange(len(g))

    def score(p, o):
        ph = ((pos - o) / p) % 1.0
        near = (ph < 0.1) | (ph > 0.9)
        return g[near].mean() / (g[~near].mean() + 1e-9)

    return max((score(p, o), p, o) for p in np.arange(10.5, 12.0, 0.02) for o in np.arange(0, 12.0, 0.25))


def grid(a):
    size = a.shape[0]
    _, px, ox = fit_axis(a, 1)
    _, py, oy = fit_axis(a, 0)
    pitch = (px + py) / 2
    # First cell edge at or before 0, then edges every `pitch`.
    ex = ox - pitch * np.ceil(ox / pitch)
    ey = oy - pitch * np.ceil(oy / pitch)
    n = int(np.ceil((size - min(ex, ey)) / pitch))
    return pitch, ex, ey, n


def cell_colours(a, pitch, ex, ey, n):
    size = a.shape[0]
    cells = np.zeros((n, n, 3))
    for i in range(n):
        for j in range(n):
            y0, y1 = ey + (i + 0.3) * pitch, ey + (i + 0.7) * pitch
            x0, x1 = ex + (j + 0.3) * pitch, ex + (j + 0.7) * pitch
            patch = a[int(max(0, y0)):int(min(size, y1)) + 1, int(max(0, x0)):int(min(size, x1)) + 1].reshape(-1, 3)
            cells[i, j] = np.median(patch, axis=0) if len(patch) else 255
    return cells


def sprite_mask(cells):
    """True where the art pixel is part of the sprite."""
    n = cells.shape[0]
    lum = cells @ np.array([0.299, 0.587, 0.114])
    spread = cells.max(axis=2) - cells.min(axis=2)
    light = (lum > 213) & (spread < 60)
    bg = np.zeros((n, n), bool)
    stack = [(i, j) for i in range(n) for j in range(n)
             if (i in (0, n - 1) or j in (0, n - 1)) and light[i, j]]
    while stack:
        i, j = stack.pop()
        if bg[i, j]:
            continue
        bg[i, j] = True
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ni, nj = i + di, j + dj
            if 0 <= ni < n and 0 <= nj < n and light[ni, nj] and not bg[ni, nj]:
                stack.append((ni, nj))
    return ~bg


def diffuse_fill(img, known, iterations=600):
    """Fill unknown pixels by repeatedly averaging their neighbours."""
    out = img.copy()
    out[~known] = out[known].mean(axis=0)
    for _ in range(iterations):
        p = np.pad(out, ((1, 1), (1, 1), (0, 0)), mode="edge")
        avg = (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]) / 4
        out[~known] = avg[~known]
    return out


def main(src, dst):
    im = Image.open(src).convert("RGB")
    assert im.size[0] == im.size[1], "expected a square picture"
    size = im.size[0]
    a = np.asarray(im).astype(float)

    pitch, ex, ey, n = grid(a)
    print(f"art pixel pitch {pitch:.2f}px, grid {n}x{n}, offset ({ex:.2f}, {ey:.2f})")
    cells = cell_colours(a, pitch, ex, ey, n)
    mask = sprite_mask(cells)

    # Source-space edges of every art pixel.
    xs = [ex + k * pitch for k in range(n + 1)]
    ys = [ey + k * pitch for k in range(n + 1)]

    # Background: the original with the sprite (and one art pixel around it) filled in.
    grown = mask.copy()
    grown[1:] |= mask[:-1]; grown[:-1] |= mask[1:]
    grown[:, 1:] |= mask[:, :-1]; grown[:, :-1] |= mask[:, 1:]
    known = np.ones((size, size), bool)
    for i in range(n):
        for j in range(n):
            if grown[i, j]:
                known[max(0, int(ys[i])):max(0, int(ys[i + 1]) + 1), max(0, int(xs[j])):max(0, int(xs[j + 1]) + 1)] = False
    small = 141
    a_small = np.asarray(im.resize((small, small), Image.LANCZOS)).astype(float)
    k_small = np.asarray(Image.fromarray((known * 255).astype("uint8")).resize((small, small), Image.NEAREST)) > 127
    filled = diffuse_fill(a_small, k_small)
    base = Image.fromarray(np.clip(filled, 0, 255).astype("uint8")).resize((OUT, OUT), Image.BICUBIC)
    orig_up = im.resize((OUT, OUT), Image.LANCZOS)
    k_up = Image.fromarray((known * 255).astype("uint8")).resize((OUT, OUT), Image.BILINEAR).filter(ImageFilter.GaussianBlur(6))
    canvas = Image.composite(orig_up, base, k_up)

    # Sprite pixels on top, square and crisp.
    f = OUT / size
    px = np.asarray(canvas).copy()
    for i in range(n):
        for j in range(n):
            if not mask[i, j]:
                continue
            y0, y1 = round(ys[i] * f), round(ys[i + 1] * f)
            x0, x1 = round(xs[j] * f), round(xs[j + 1] * f)
            px[max(0, y0):max(0, y1), max(0, x0):max(0, x1)] = np.clip(cells[i, j], 0, 255).astype("uint8")
    Image.fromarray(px, "RGB").save(dst, optimize=True)
    print(f"wrote {dst}: {OUT}x{OUT}, sprite pixels: {int(mask.sum())}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
