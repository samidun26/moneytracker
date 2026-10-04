#!/usr/bin/env python3
"""Turns the pixel-art credit-card app icon into the in-app logo, so the app bar,
lock screen and Payday boot screen show the same picture as the Home Screen icon.

Reads   ios/Duit/Assets.xcassets/AppIcon.appiconset/AppIcon.png
Writes  ios/Duit/Resources/DuitLogoData.swift   (the native logo, as coloured rectangles)
        design/prototype/Main.dc.html           (the prototype's <symbol id="duit-logo">)

How it works: make_app_icon.py draws the sprite crisp, one square block per art
pixel, so the art-pixel grid can be read straight back out of the 1024 px icon.
We read one colour per art pixel, drop the background and the soft drop shadow
(the logo sits on the app bar, which has its own colour), merge near-identical
colours (the original was a JPEG) and write each colour as a list of rectangles,
the same representation PixelIconData uses.

The black pixels on the outer edge of the sprite are kept as their own "outline"
layer so the app can paint them in the theme's ink colour: the silhouette stays
visible on the dark night-mode bar. Black pixels inside the sprite (the magnetic
stripe, the line where one card passes over the other) stay black.

Usage:   python3 ios/Tools/make_logo_sprite.py
Needs Pillow and NumPy (pip install pillow numpy).
"""
import re
from pathlib import Path

import numpy as np
from PIL import Image

import make_app_icon as icon

ROOT = Path(__file__).resolve().parents[2]
ICON = ROOT / "ios/Duit/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SWIFT_OUT = ROOT / "ios/Duit/Resources/DuitLogoData.swift"
PROTOTYPE = ROOT / "design/prototype/Main.dc.html"

# Colours closer than this (RGB distance) are the same colour; the source picture's JPEG noise.
MERGE_DISTANCE = 24
# What the outline layer is matched against (it is drawn in the theme's ink colour instead).
OUTLINE = np.array([0, 0, 0])


def fit_axis(a, axis):
    """Best (pitch, offset) of the art-pixel grid along one axis of the 1024 px icon."""
    g = np.abs(np.diff(a, axis=axis)).sum(axis=2).sum(axis=1 - axis)
    pos = np.arange(len(g))

    def score(p, o):
        ph = ((pos - o) / p) % 1.0
        near = (ph < 0.06) | (ph > 0.94)
        return g[near].mean() / (g[~near].mean() + 1e-9)

    return max((score(p, o), p, o) for p in np.arange(19.0, 22.0, 0.01) for o in np.arange(0, 22.0, 0.25))


def read_cells():
    a = np.asarray(Image.open(ICON).convert("RGB")).astype(float)
    _, px, ox = fit_axis(a, 1)
    _, py, oy = fit_axis(a, 0)
    pitch = (px + py) / 2
    ex = ox - pitch * np.ceil(ox / pitch)
    ey = oy - pitch * np.ceil(oy / pitch)
    n = int(np.ceil((a.shape[0] - min(ex, ey)) / pitch))
    print(f"art pixel pitch {pitch:.2f}px, grid {n}x{n}")
    return icon.cell_colours(a, pitch, ex, ey, n)


def logo_mask(cells):
    """Sprite cells without the background and without the grey drop shadow."""
    mask = icon.sprite_mask(cells)
    lum = cells @ np.array([0.299, 0.587, 0.114])
    spread = cells.max(axis=2) - cells.min(axis=2)
    shadow = (spread < 40) & (lum > 90) & (lum < 215)
    return mask & ~shadow


def merge_colours(cells, mask):
    """{(row, col): palette index} and the palette (most common colours first)."""
    coords = [(i, j) for i, j in zip(*np.where(mask))]
    counts = {}
    for i, j in coords:
        key = tuple(int(v) for v in cells[i, j])
        counts[key] = counts.get(key, 0) + 1
    palette = []
    for colour, _ in sorted(counts.items(), key=lambda kv: -kv[1]):
        if not any(np.linalg.norm(np.array(colour) - np.array(p)) <= MERGE_DISTANCE for p in palette):
            palette.append(colour)
    index = {}
    for i, j in coords:
        d = [np.linalg.norm(cells[i, j] - np.array(p)) for p in palette]
        index[(i, j)] = int(np.argmin(d))
    return index, palette


def rectangles(points):
    """Row runs of (row, col) cells, merged down while consecutive rows repeat a run."""
    runs = {}
    for r in sorted({p[0] for p in points}):
        cols = sorted(c for rr, c in points if rr == r)
        start = prev = cols[0]
        for c in cols[1:] + [None]:
            if c is not None and c == prev + 1:
                prev = c
                continue
            runs.setdefault((start, prev - start + 1), []).append(r)
            if c is not None:
                start = prev = c
    out = []
    for (x, w), rows in runs.items():
        rows.sort()
        y0 = prev = rows[0]
        for r in rows[1:] + [None]:
            if r is not None and r == prev + 1:
                prev = r
                continue
            out.append((x, y0, w, prev - y0 + 1))
            if r is not None:
                y0 = prev = r
    return sorted(out, key=lambda t: (t[1], t[0]))


def build():
    cells = read_cells()
    mask = logo_mask(cells)
    rows, cols = np.where(mask)
    r0, c0 = rows.min(), cols.min()
    height, width = rows.max() - r0 + 1, cols.max() - c0 + 1
    index, palette = merge_colours(cells, mask)

    layers = {}
    for (i, j), k in index.items():
        layers.setdefault(k, []).append((i - r0, j - c0))
    # The palette entry closest to black is the outline; only its outer edge is themeable.
    black_k = int(np.argmin([np.linalg.norm(np.array(p) - OUTLINE) for p in palette]))
    black = set(layers.pop(black_k))
    present = {(i - r0, j - c0) for i, j in index}
    outer = {(i, j) for i, j in black if any((i + di, j + dj) not in present for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    layers[black_k] = sorted(black - outer)  # the rest stays black, painted with the colours
    palette[black_k] = (0, 0, 0)
    result = {"outline": rectangles(sorted(outer)), "width": int(width), "height": int(height), "colours": []}
    # Painted in a stable order: biggest area first.
    for k in sorted((k for k in layers if layers[k]), key=lambda k: -len(layers[k])):
        r, g, b = palette[k]
        result["colours"].append(("%02X%02X%02X" % (r, g, b), rectangles(layers[k])))
    print(f"logo {width}x{height} art pixels, {len(result['colours'])} colours + outline")
    return result


def swift(logo):
    def rects(rs):
        return ", ".join("({},{},{},{})".format(*r) for r in rs)

    lines = [
        "// GENERATED by ios/Tools/make_logo_sprite.py from the app icon",
        "// (Assets.xcassets/AppIcon.appiconset/AppIcon.png). Do not edit by hand; re-run the script.",
        "//",
        "// The pixel-art credit cards, as filled rectangles (x, y, width, height) on a",
        f"// {logo['width']}x{logo['height']} grid, one list per colour. `outline` is the black outer edge: the",
        "// app draws it in the theme's ink colour so it still shows on the night-mode bar.",
        "// (One constant per colour, each with its type spelled out, keeps the compiler fast.)",
        "",
        "enum DuitLogoData {",
        f"    static let width = {logo['width']}",
        f"    static let height = {logo['height']}",
        f"    static let outline: PixelRects = [{rects(logo['outline'])}]",
        "",
    ]
    for hex_, rs in logo["colours"]:
        lines.append(f"    private static let colour{hex_}: PixelRects = [{rects(rs)}]")
    lines += ["", "    /// Painted in this order, over nothing but the bar behind them.", "    static let layers: [(hex: UInt32, rects: PixelRects)] = ["]
    lines += [f"        (0x{hex_}, colour{hex_})," for hex_, _ in logo["colours"]]
    lines += ["    ]", "}", ""]
    SWIFT_OUT.write_text("\n".join(lines))
    print(f"wrote {SWIFT_OUT.relative_to(ROOT)}")


def svg_symbol(logo):
    def path(rs):
        return "".join(f"M{x} {y}h{w}v{h}h-{w}z" for x, y, w, h in rs)

    parts = [f'<symbol id="duit-logo" viewBox="0 0 {logo["width"]} {logo["height"]}">']
    for hex_, rs in logo["colours"]:
        parts.append(f'<path fill="#{hex_}" d="{path(rs)}"></path>')
    parts.append(f'<path class="logo-ink" d="{path(logo["outline"])}"></path>')
    parts.append("</symbol>")
    return "".join(parts)


def prototype(logo):
    """Replace the <symbol id="duit-logo"> block in the prototype (it is added next to the app bar once)."""
    html = PROTOTYPE.read_text()
    symbol = svg_symbol(logo)
    pattern = re.compile(r'<symbol id="duit-logo".*?</symbol>', re.S)
    if not pattern.search(html):
        raise SystemExit("no <symbol id=\"duit-logo\"> placeholder in " + str(PROTOTYPE))
    PROTOTYPE.write_text(pattern.sub(lambda _: symbol, html, count=1))
    print(f"patched {PROTOTYPE.relative_to(ROOT)}")


if __name__ == "__main__":
    logo = build()
    swift(logo)
    prototype(logo)
