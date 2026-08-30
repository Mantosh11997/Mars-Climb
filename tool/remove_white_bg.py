#!/usr/bin/env python3
"""
Key out an opaque near-white background from a sprite.

Some generated wheels came back fully opaque on white instead of with an
alpha channel. A plain "delete all whitish pixels" pass would also eat the
white highlights and silver bolts *inside* the wheel, so this only touches
white that is reachable from the image border, then feathers the edge so
no white fringe survives the cut.

Usage: python3 tool/remove_white_bg.py <file> [<file> ...]
"""

import sys
from collections import deque

import numpy as np
from PIL import Image

# A pixel counts as background-white if its darkest channel is at least this.
WHITE_FLOOR = 205

# Fully opaque below this, fully transparent at 255, ramped between.
FEATHER_FROM = 205


def remove(path: str) -> None:
    rgba = np.array(Image.open(path).convert("RGBA"))
    h, w = rgba.shape[:2]
    darkest = rgba[:, :, :3].min(axis=2).astype(np.int32)

    whitish = darkest >= WHITE_FLOOR

    # Flood fill inward from every border pixel that is whitish. Anything
    # white but enclosed by the wheel (bolts, highlights) is never reached.
    outside = np.zeros((h, w), dtype=bool)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if whitish[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if whitish[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))

    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and whitish[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True
                queue.append((ny, nx))

    # Grow the region by a few pixels so the anti-aliased rim of the art -
    # which is a blend toward white and not white enough to flood into -
    # gets feathered rather than left as a bright halo.
    band = outside.copy()
    for _ in range(3):
        grown = band.copy()
        grown[1:, :] |= band[:-1, :]
        grown[:-1, :] |= band[1:, :]
        grown[:, 1:] |= band[:, :-1]
        grown[:, :-1] |= band[:, 1:]
        band = grown

    alpha = np.full((h, w), 255, dtype=np.int32)
    ramp = np.clip(
        255 - (darkest - FEATHER_FROM) * 255 // max(255 - FEATHER_FROM, 1),
        0,
        255,
    )
    alpha = np.where(band, ramp, alpha)
    alpha = np.where(outside, 0, alpha)

    out = rgba.copy()
    out[:, :, 3] = alpha.astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path, optimize=True)

    print(
        f"{path}: keyed out {(alpha == 0).mean() * 100:.1f}% "
        f"({(alpha > 0).sum()} pixels kept)"
    )


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        remove(arg)
