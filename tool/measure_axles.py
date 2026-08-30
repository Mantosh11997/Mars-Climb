#!/usr/bin/env python3
"""
Estimate wheel anchors from a chassis sprite.

The axles sit at the extremities of the machine's lower half - a bike's
swingarm tip and fork bottom, a trike's outer hubs - so scanning inward
from each side of the lower band finds them without eyeballing.

Prints Dart WheelMount lines. Always check the result with a composite
render; this gets you close, not exact.
"""

import sys

import numpy as np
from PIL import Image


def axle_at(mask, col, band_top, band_bot):
    """Vertical centre of the art in a narrow column window."""
    lo = max(col - 10, 0)
    hi = min(col + 11, mask.shape[1])
    rows = np.where(mask[band_top:band_bot, lo:hi].any(axis=1))[0]
    if len(rows) == 0:
        return (band_top + band_bot) // 2
    return band_top + int(rows.mean())


def measure(path, count, sprite_w, sprite_h, wheel_frac):
    mask = np.array(Image.open(path).convert("RGBA"))[:, :, 3] > 24
    ys, xs = np.where(mask)
    top, bot, left, right = ys.min(), ys.max(), xs.min(), xs.max()

    # Axles live in the lower half of the machine.
    band_top = top + int((bot - top) * 0.45)
    band = mask[band_top:bot + 1]

    cols = np.where(band.any(axis=0))[0]
    l, r = cols.min(), cols.max()

    if count == 2:
        picks = [l, r]
    else:
        # Spread the remaining axles evenly between the outer two.
        picks = [
            int(round(l + (r - l) * i / (count - 1))) for i in range(count)
        ]

    h, w = mask.shape
    out = []
    for c in picks:
        y = axle_at(mask, c, band_top, bot + 1)
        # Pixel -> chassis-local metres, sprite centred on the body.
        mx = (c / w - 0.5) * sprite_w
        my = (y / h - 0.5) * sprite_h
        out.append((mx, my))

    radius = wheel_frac * sprite_w * 0.92 / 2
    return out, radius


if __name__ == "__main__":
    slug, count, sw, sh, wf = (
        sys.argv[1], int(sys.argv[2]),
        float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]),
    )
    anchors, radius = measure(
        f"assets/images/{slug}_body.png", count, sw, sh, wf
    )
    print(f"  // {slug}")
    print("  wheels: [")
    for x, y in anchors:
        print(
            f"    WheelMount(anchor: Vector2({x:.2f}, {y:.2f}), "
            f"radius: {radius:.2f}),"
        )
    print("  ],")
