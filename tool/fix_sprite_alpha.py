#!/usr/bin/env python3
"""
Prepare sprite PNGs for GPU texture filtering.

These sprites are already cleanly cut out (alpha is effectively binary),
but the RGB *stored underneath* the transparent pixels is near-black.
That matters: the GPU's bilinear filter interpolates RGB and alpha
independently, so at the sprite's edge it mixes the art colour with that
hidden black, producing a dark fringe. The same hidden black also bleeds
inward when mipmaps are generated at small on-screen sizes.

The fix is "alpha bleed" (a.k.a. edge padding / dilation): flood the art's
own colour outward into the transparent margin, leaving alpha untouched.
Nothing visible changes - the padded pixels are still fully transparent -
but there is no longer any black for the filter to find.

Also normalises near-opaque alpha (>= 250) to a true 255, so solid
interiors don't blend at all. car_body.png topped out at 254.

Usage:  python3 tool/fix_sprite_alpha.py [--check]
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ASSETS = Path(__file__).resolve().parent.parent / "assets" / "images"
# Every sprite in the folder. A hand-maintained list would silently skip
# newly added machines, and a machine with a black fringe is exactly the
# kind of thing nobody notices until it ships.
SPRITES = sorted(p.name for p in ASSETS.glob("*.png"))

# How far to push the art colour into the transparent margin, in pixels.
# 16 is comfortably more than bilinear (1px) or a few mip levels need.
BLEED_RADIUS = 16

# Alpha at or above this is snapped to fully opaque.
OPAQUE_THRESHOLD = 250

# Alpha at or below this counts as background to be filled.
TRANSPARENT_THRESHOLD = 5


def alpha_bleed(rgba: np.ndarray, radius: int) -> np.ndarray:
    """Dilate RGB outward from visible pixels. Alpha is never modified."""
    rgb = rgba[:, :, :3].astype(np.float32)
    alpha = rgba[:, :, 3]

    filled = alpha > TRANSPARENT_THRESHOLD

    for _ in range(radius):
        if filled.all():
            break

        # Sum the RGB of filled 4-neighbours, and count how many there were.
        total = np.zeros_like(rgb)
        count = np.zeros(filled.shape, dtype=np.float32)

        for shift_axis, shift in ((0, 1), (0, -1), (1, 1), (1, -1)):
            src_rgb = np.roll(rgb, shift, axis=shift_axis)
            src_filled = np.roll(filled, shift, axis=shift_axis)
            # np.roll wraps around; blank the wrapped-in edge row/column.
            idx = 0 if shift > 0 else -1
            if shift_axis == 0:
                src_filled[idx, :] = False
            else:
                src_filled[:, idx] = False

            total += src_rgb * src_filled[:, :, None]
            count += src_filled

        frontier = (~filled) & (count > 0)
        if not frontier.any():
            break

        rgb[frontier] = total[frontier] / count[frontier][:, None]
        filled |= frontier

    out = rgba.copy()
    out[:, :, :3] = np.clip(np.rint(rgb), 0, 255).astype(np.uint8)
    return out


def normalise_alpha(rgba: np.ndarray) -> np.ndarray:
    out = rgba.copy()
    out[:, :, 3] = np.where(out[:, :, 3] >= OPAQUE_THRESHOLD, 255, out[:, :, 3])
    return out


def hidden_rgb_mean(rgba: np.ndarray) -> tuple:
    """Mean RGB of transparent pixels within 2px of visible art."""
    alpha = rgba[:, :, 3]
    visible = alpha > TRANSPARENT_THRESHOLD
    near = visible.copy()
    for _ in range(2):
        grown = near.copy()
        grown[1:, :] |= near[:-1, :]
        grown[:-1, :] |= near[1:, :]
        grown[:, 1:] |= near[:, :-1]
        grown[:, :-1] |= near[:, 1:]
        near = grown
    band = near & ~visible
    if not band.any():
        return (0.0, 0.0, 0.0)
    px = rgba[band][:, :3].astype(np.float32)
    return tuple(round(float(px[:, i].mean()), 1) for i in range(3))


def main() -> int:
    check_only = "--check" in sys.argv
    failed = False

    for name in SPRITES:
        path = ASSETS / name
        original = np.array(Image.open(path).convert("RGBA"))

        before_hidden = hidden_rgb_mean(original)
        before_alpha_max = int(original[:, :, 3].max())

        fixed = normalise_alpha(alpha_bleed(original, BLEED_RADIUS))
        after_hidden = hidden_rgb_mean(fixed)

        # The visible image must be bit-identical: same alpha everywhere,
        # and same RGB anywhere alpha is non-zero.
        assert np.array_equal(
            fixed[:, :, 3] > 0, original[:, :, 3] > 0
        ), f"{name}: alpha coverage changed"
        visible = original[:, :, 3] > TRANSPARENT_THRESHOLD
        assert np.array_equal(
            fixed[:, :, :3][visible], original[:, :, :3][visible]
        ), f"{name}: visible pixels changed"

        clean = after_hidden == before_hidden and before_alpha_max == 255
        status = "ok" if clean else ("NEEDS FIX" if check_only else "fixed")
        if check_only and not clean:
            failed = True

        print(f"{name}: {status}")
        print(f"    alpha max        {before_alpha_max} -> {int(fixed[:, :, 3].max())}")
        print(f"    hidden edge RGB  {before_hidden} -> {after_hidden}")

        if not check_only:
            Image.fromarray(fixed, "RGBA").save(path, optimize=True)

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
