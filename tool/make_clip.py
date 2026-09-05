#!/usr/bin/env python3
"""Turn captured gameplay frames into an H.264 clip.

    flutter test --tags capture test/gameplay_capture_test.dart \
      --dart-define=CAPTURE_DIR=/some/dir
    python3 tool/make_clip.py /some/dir mars_climb.mp4

The frames come from `test/gameplay_capture_test.dart`, which drives the
real game and screenshots it. This only labels them and encodes.

The labels are burned into the frames here rather than drawn by the game,
because they are captions on a video and not part of the game's UI - the
capture test must go on recording exactly what a player would see.

Needs ffmpeg. `pip install imageio-ffmpeg` provides a static one if the
system has none; this script finds either.
"""

import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

FPS = 30
SHOT_SECONDS = 5

# Must match the `shots` list in test/gameplay_capture_test.dart, in order.
SHOTS = [
    ('PATHFINDER', 'Acidalia Flats', 'COURSE 1'),
    ('DUST DEVIL', 'Verdant Vale', 'COURSE 5'),
    ('GECKO', 'Frostpine Ridge', 'COURSE 6'),
    ('TRILOBITE', 'Rustworks Yard', 'COURSE 7'),
    ('WASP', 'Floodlit Coliseum', 'COURSE 9'),
    ('CINDER', 'Sunset Cay', 'COURSE 11'),
]

FONT_DIRS = [
    '/opt/flutter/bin/cache/artifacts/material_fonts',
    '/usr/share/fonts/truetype/dejavu',
]


def _font(names, size):
    for d in FONT_DIRS:
        for n in names:
            path = os.path.join(d, n)
            if os.path.exists(path):
                return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _ffmpeg():
    exe = shutil.which('ffmpeg')
    if exe:
        return exe
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        sys.exit('no ffmpeg: pip install imageio-ffmpeg')


def label(frames_dir, out_dir):
    """Caption each frame with the machine and course it is showing."""
    big = _font(['Roboto-Black.ttf', 'DejaVuSans-Bold.ttf'], 30)
    small = _font(['Roboto-Medium.ttf', 'DejaVuSans.ttf'], 15)

    os.makedirs(out_dir, exist_ok=True)
    # frame_ prefix, not just .png: a contact sheet or a stray screenshot
    # left in the capture directory would otherwise be encoded as a frame,
    # and it landed at the end where it is least likely to be noticed.
    names = sorted(
        f for f in os.listdir(frames_dir)
        if f.startswith('frame_') and f.endswith('.png')
    )
    per_shot = FPS * SHOT_SECONDS

    for i, name in enumerate(names):
        shot = min(i // per_shot, len(SHOTS) - 1)
        machine, course, number = SHOTS[shot]

        # Where we are inside this shot, for the fades.
        t = (i % per_shot) / FPS
        if t < 0.35:
            alpha = t / 0.35
        elif t > SHOT_SECONDS - 0.6:
            alpha = max(0.0, (SHOT_SECONDS - t) / 0.6)
        else:
            alpha = 1.0

        im = Image.open(os.path.join(frames_dir, name)).convert('RGB')

        if alpha > 0.01:
            # Drawn on its own layer and composited, so the caption can fade
            # without the frame under it fading too.
            layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(layer)
            a = int(255 * alpha)

            # Top left, under the HUD strip. The obvious place - bottom
            # left - is where the brake button lives, and the caption sat
            # squarely on top of it.
            x, y = 30, 94

            # A plate behind the text: these frames are screenshots of real
            # terrain, and white-on-snow is unreadable without one. Sized
            # to the longest of the three lines rather than a fixed width,
            # so a short machine name does not trail an empty box.
            width = max(
                d.textlength(machine, font=big),
                d.textlength(course, font=small),
                d.textlength(number, font=small),
            )
            d.rounded_rectangle(
                [x - 14, y - 10, x + width + 16, y + 76],
                radius=12,
                fill=(12, 9, 7, int(170 * alpha)),
            )
            d.text((x, y), machine, font=big, fill=(255, 255, 255, a))
            d.text((x, y + 38), course, font=small,
                   fill=(255, 168, 92, a))
            d.text((x, y + 56), number, font=small,
                   fill=(210, 200, 194, int(a * 0.75)))
            im = Image.alpha_composite(im.convert('RGBA'), layer).convert('RGB')

        im.save(os.path.join(out_dir, name))

    return len(names)


def encode(frames_dir, out_file):
    subprocess.run(
        [
            _ffmpeg(), '-y',
            '-framerate', str(FPS),
            '-pattern_type', 'glob',
            '-i', os.path.join(frames_dir, 'frame_*.png'),
            '-c:v', 'libx264',
            '-preset', 'slow',
            '-crf', '20',
            # Every player on earth wants 4:2:0; the default 4:4:4 from PNG
            # input will not open on most phones.
            '-pix_fmt', 'yuv420p',
            # Lets a player start without downloading the whole file.
            '-movflags', '+faststart',
            out_file,
        ],
        check=True,
        capture_output=True,
    )


def main():
    if len(sys.argv) != 3:
        sys.exit(f'usage: {sys.argv[0]} <frames-dir> <out.mp4>')
    frames_dir, out_file = sys.argv[1], sys.argv[2]

    labelled = os.path.join(frames_dir, '_labelled')
    n = label(frames_dir, labelled)
    encode(labelled, out_file)

    size = os.path.getsize(out_file)
    print(f'{out_file}: {n} frames, {n / FPS:.1f}s, {size / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
