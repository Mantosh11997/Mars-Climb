#!/usr/bin/env python3
"""
Split a generated machine sheet into a chassis sprite and a wheel sprite.

The image generator returns the chassis and its wheels laid out together in
one canvas, which is a nicer way to art-direct a machine - the wheel is
designed against the body it belongs to - but the game needs them apart:
the chassis is one sprite and the wheel is a separate sprite the physics
spins.

They are separate objects on the canvas, so connected components in the
alpha mask pull them apart cleanly. The largest blob is the chassis;
round blobs of similar size are its wheels, and we keep the roundest.

Usage:
  python3 tool/split_sheet.py <slug> <sheet.png> [--outdir assets/images]
"""

import argparse
import sys
from collections import deque

import numpy as np
from PIL import Image
from scipy import ndimage

# --- background removal -------------------------------------------------

# A pixel this bright in every channel, reachable from the border, is a
# white studio background.
WHITE_FLOOR = 205
# A pixel this dark in every channel, reachable from the border, is a
# black studio background. Kept low so the art's black outlines survive.
DARK_CEIL = 26

MIN_COMPONENT_PX = 4000


def _flood_from_border(mask: np.ndarray) -> np.ndarray:
    """Everything in `mask` that is reachable from the image border."""
    h, w = mask.shape
    out = np.zeros_like(mask)
    q = deque()

    for x in range(w):
        for y in (0, h - 1):
            if mask[y, x] and not out[y, x]:
                out[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if mask[y, x] and not out[y, x]:
                out[y, x] = True
                q.append((y, x))

    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return out


def _cut_from_dark(rgb: np.ndarray, close: int, bright: int, sat: int) -> np.ndarray:
    """Silhouette of the subject on a dark studio backdrop.

    Flooding the dark from the border does NOT work here: the art's own
    outlines are near-black, so the flood eats straight through them and
    shatters the machine into fragments. Instead build the silhouette from
    the bright, saturated interior and fill it - which puts the black
    outlines safely *inside* the mask.
    """
    brightest = rgb.max(axis=2)
    saturation = brightest - rgb.min(axis=2)

    # Thresholds are deliberately low: a grimy, desaturated machine (a
    # scavenger build, say) is barely brighter than the backdrop, and a
    # high threshold shatters it into fragments. The generous closing then
    # welds those fragments back into one silhouette.
    core = (brightest > bright) | (saturation > sat)
    core = ndimage.binary_closing(core, np.ones((close, close)))
    core = ndimage.binary_fill_holes(core)
    # Drop the faint bloom the renderer paints around the subject, and any
    # smear of backdrop that survived.
    core = ndimage.binary_opening(core, np.ones((max(close // 2, 3),) * 2))
    core = ndimage.binary_fill_holes(core)
    return core


def ensure_alpha(
    rgba: np.ndarray,
    close: int = 15,
    bright: int = 46,
    sat: int = 28,
) -> np.ndarray:
    """Give the sheet a real alpha channel if it arrived opaque.

    Judged on the BORDER, not the overall transparent fraction: several
    sheets arrive with some alpha but a fully painted backdrop, and those
    still need cutting out.
    """
    alpha = rgba[:, :, 3]
    border = np.concatenate(
        [alpha[0, :], alpha[-1, :], alpha[:, 0], alpha[:, -1]]
    )
    if (border < 10).mean() > 0.9:
        return rgba  # genuinely already cut out

    rgb = rgba[:, :, :3].astype(np.int32)
    corner = rgb[0, 0]

    if corner.min() >= WHITE_FLOOR:
        bg = rgb.min(axis=2) >= WHITE_FLOOR
        ramp = np.clip(255 - (rgb.min(axis=2) - WHITE_FLOOR) * 5, 0, 255)
        outside = _flood_from_border(bg)
    elif corner.max() <= 40:
        outside = ~_cut_from_dark(rgb, close, bright, sat)
        ramp = np.full(outside.shape, 255)
    else:
        # A coloured backdrop: flood what matches the corner closely.
        dist = np.abs(rgb - corner.reshape(1, 1, 3)).sum(axis=2)
        outside = _flood_from_border(dist < 90)
        ramp = np.clip(dist * 4, 0, 255)

    band = outside.copy()
    for _ in range(3):
        band |= ndimage.binary_dilation(band)

    new_alpha = np.where(band, ramp, 255)
    new_alpha = np.where(outside, 0, new_alpha)

    out = rgba.copy()
    out[:, :, 3] = new_alpha.astype(np.uint8)
    return out


# --- component analysis -------------------------------------------------


def roundness(sl) -> float:
    """1.0 for a square bounding box, lower for a long thin blob."""
    h = sl[0].stop - sl[0].start
    w = sl[1].stop - sl[1].start
    return min(h, w) / max(h, w)


def recanvas(rgba: np.ndarray, sl, aspect: float, margin: float) -> Image.Image:
    """Crop to a component and centre it on a fresh canvas of `aspect`."""
    crop = rgba[sl[0], sl[1]]
    ch, cw = crop.shape[:2]

    inner_w = cw / (1 - 2 * margin)
    inner_h = ch / (1 - 2 * margin)

    if inner_w / inner_h < aspect:
        out_h = inner_h
        out_w = out_h * aspect
    else:
        out_w = inner_w
        out_h = out_w / aspect

    out = np.zeros((int(round(out_h)), int(round(out_w)), 4), dtype=np.uint8)
    y0 = (out.shape[0] - ch) // 2
    x0 = (out.shape[1] - cw) // 2
    out[y0:y0 + ch, x0:x0 + cw] = crop
    return Image.fromarray(out, "RGBA")


def _components(rgba):
    solid = rgba[:, :, 3] > 24
    labels, count = ndimage.label(solid)
    slices = ndimage.find_objects(labels)
    areas = ndimage.sum(solid, labels, range(1, count + 1))
    parts = [
        (i + 1, areas[i], slices[i])
        for i in range(count)
        if areas[i] >= MIN_COMPONENT_PX
    ]
    parts.sort(key=lambda p: -p[1])
    return labels, slices, parts


def split(slug: str, path: str, outdir: str) -> int:
    raw = np.array(Image.open(path).convert("RGBA"))

    # There is no single cut that works for every sheet. A grimy machine on
    # black needs a low threshold and a generous closing or it shatters; a
    # machine sitting in a coloured bloom needs the opposite or the bloom
    # welds its wheels back on. So try a spread and keep the attempt that
    # actually yields a believable machine AND a believable wheel.
    best = None
    for bright, sat in ((70, 45), (46, 28), (90, 60)):
        for close in (15, 11, 9, 7, 5):
            rgba = ensure_alpha(raw, close, bright, sat)
            labels, slices, parts = _components(rgba)
            if len(parts) < 2:
                continue

            body_area = parts[0][1]
            wheels = sorted(parts[1:], key=lambda p: (-roundness(p[2]), -p[1]))
            wheel_label, wheel_area, wheel_slice = wheels[0]

            # A wheel is round, and a meaningful fraction of the machine.
            if roundness(wheel_slice) < 0.85:
                continue
            if not (0.02 * body_area < wheel_area < 0.9 * body_area):
                continue

            score = body_area + wheel_area
            if best is None or score > best[0]:
                best = (
                    score, rgba, labels, slices, parts,
                    wheel_label, wheel_slice, close, bright, sat,
                )

    if best is None:
        print(
            f"{slug}: could not separate a body and a wheel — the wheels are "
            f"probably drawn attached to the machine. Needs regenerating.",
            file=sys.stderr,
        )
        return 1

    (_, rgba, labels, slices, parts,
     wheel_label, wheel_slice, close, bright, sat) = best
    body_label = parts[0][0]

    body = rgba.copy()
    body[:, :, 3] = np.where(labels == body_label, body[:, :, 3], 0)
    body_img = recanvas(body, slices[body_label - 1], 3 / 2, 0.03)

    wheel = rgba.copy()
    wheel[:, :, 3] = np.where(labels == wheel_label, wheel[:, :, 3], 0)
    wheel_img = recanvas(wheel, wheel_slice, 1.0, 0.04)

    body_img.save(f"{outdir}/{slug}_body.png", optimize=True)
    wheel_img.save(f"{outdir}/{slug}_wheel.png", optimize=True)

    print(
        f"{slug}: body {body_img.size[0]}x{body_img.size[1]}, "
        f"wheel {wheel_img.size[0]}x{wheel_img.size[1]}, "
        f"roundness {roundness(wheel_slice):.2f} "
        f"(close={close} bright={bright} sat={sat})"
    )
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("slug")
    ap.add_argument("sheet")
    ap.add_argument("--outdir", default="assets/images")
    a = ap.parse_args()
    raise SystemExit(split(a.slug, a.sheet, a.outdir))
