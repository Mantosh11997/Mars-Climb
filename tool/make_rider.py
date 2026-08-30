#!/usr/bin/env python3
"""Cut the bucket seat and the steering wheel out of the driver sprite.

character.png is a seated car driver: strapped into a racing bucket and
holding a steering wheel. That reads wrong on a bike or a trike, where the
rider straddles the machine and holds bars. Both offending props are
separable by hand-traced regions:

  * the seat sits behind and below the rider, so a seam traced down his
    back and under his thigh removes it without touching him;
  * the steering wheel's rim shows above, right of, and below his fists.
    Cut those three arcs and what survives between the gloves reads as a
    handlebar grip.

Run from the repo root; writes assets/images/rider.png.
"""

import numpy as np
from PIL import Image
from scipy import ndimage

SEAM = [
    (370, 226), (430, 232), (500, 245), (560, 252), (620, 278), (700, 308),
    (780, 352), (850, 398), (900, 435), (930, 485), (960, 565), (990, 650),
    (1080, 700),
]


def main():
    im = np.array(Image.open("assets/images/character.png").convert("RGBA"))
    h, w = im.shape[:2]
    Y, X = np.mgrid[0:h, 0:w]

    sy = np.array([p[0] for p in SEAM], float)
    sx = np.array([p[1] for p in SEAM], float)
    edge = np.interp(np.arange(h), sy, sx, left=sx[0], right=sx[-1])
    kill = (Y >= SEAM[0][0]) & (X < edge[:, None])

    kill |= (X > 755) & (Y > 420) & (Y < 512)        # rim above the fists
    kill |= (X > 790) & (Y > 420) & (Y < 566)        # the wedge between them
    kill |= (X > 872) & (Y > 420) & (Y < 800)        # rim beyond them
    kill |= (X > 690) & (X < 860) & (Y > 690) & (Y < 830)  # rim below

    alpha = im[:, :, 3].copy()
    alpha[kill] = 0

    # Keep only the rider; the cuts can strand crumbs of either prop.
    labels, count = ndimage.label(alpha > 24)
    if count:
        areas = ndimage.sum(alpha > 24, labels, range(1, count + 1))
        alpha = np.where(labels == int(areas.argmax()) + 1, alpha, 0)

    im[:, :, 3] = alpha
    Image.fromarray(im).save("assets/images/rider.png", optimize=True)
    print("assets/images/rider.png")


if __name__ == "__main__":
    main()
