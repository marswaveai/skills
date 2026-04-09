#!/usr/bin/env python3
"""
Sprite Sheet Spike — standalone test for the Banana-inspired v1 approach.

Takes a 1x4 horizontal sprite sheet, validates it, splits into frames,
and assembles a ping-pong GIF. Imports processing functions from
process_avatar.py (sibling module).

Exit codes: 0 = success, 1 = validation failure, 2 = processing error.
"""

import argparse
import os
import sys

# Sibling import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from process_avatar import (
    remove_background,
    fit_to_canvas,
    _save_gif,
    _resize_frames,
    add_watermark,
    OUTPUT_SIZE,
    DISPLAY_SIZE,
)

from PIL import Image

VALID_EMOTIONS = ('happy', 'sad', 'angry', 'thinking')

EMOTION_DURATIONS = {
    'happy': 120,
    'sad': 200,
    'angry': 90,
    'thinking': 220,
}

MIN_ASPECT_RATIO = 3.5
MAX_ASPECT_RATIO = 4.5
MAX_AREA_VARIATION = 1.4
MAX_CENTER_OFFSET = 0.20


def validate_aspect_ratio(img):
    """Check that image aspect ratio is roughly 4:1 (within 3.5-4.5).

    Returns (is_valid, actual_ratio).
    """
    w, h = img.size
    if h == 0:
        return False, 0.0
    ratio = w / h
    return MIN_ASPECT_RATIO <= ratio <= MAX_ASPECT_RATIO, ratio


def split_sheet(img):
    """Split a horizontal sprite sheet into 4 equal-width frames.

    Returns list of 4 RGBA PIL Images.
    """
    w, h = img.size
    frame_w = w // 4
    frames = []
    for i in range(4):
        frame = img.crop((i * frame_w, 0, (i + 1) * frame_w, h))
        frames.append(frame.copy())
    return frames


def validate_frames(frames):
    """Validate 4 sprite sheet frames for content and consistency.

    Checks:
    1. Each frame has visible content (non-transparent bbox exists)
    2. Bbox area variation across frames <= 40% (max/min <= 1.4)
    3. Bbox center X offset <= 20% of frame width

    Returns (all_passed, report_dict).
    """
    frame_w = frames[0].size[0]
    bboxes = []
    content_present = []

    for frame in frames:
        bbox = frame.split()[3].getbbox()
        bboxes.append(bbox)
        content_present.append(bbox is not None)

    report = {
        'content_present': {
            'passed': all(content_present),
            'details': content_present,
        },
        'area_variation': {'passed': True, 'ratio': 0.0, 'threshold': MAX_AREA_VARIATION, 'areas': []},
        'center_alignment': {'passed': True, 'max_offset': 0.0, 'threshold': MAX_CENTER_OFFSET, 'offsets': []},
    }

    if not all(content_present):
        report['area_variation']['passed'] = False
        report['center_alignment']['passed'] = False
        return False, report

    areas = [(bb[2] - bb[0]) * (bb[3] - bb[1]) for bb in bboxes]
    report['area_variation']['areas'] = areas
    if min(areas) > 0:
        ratio = max(areas) / min(areas)
        report['area_variation']['ratio'] = ratio
        report['area_variation']['passed'] = ratio <= MAX_AREA_VARIATION
    else:
        report['area_variation']['passed'] = False

    offsets = []
    for bb in bboxes:
        center_x = (bb[0] + bb[2]) / 2
        offset = abs(center_x - frame_w / 2) / frame_w
        offsets.append(offset)
    report['center_alignment']['offsets'] = offsets
    report['center_alignment']['max_offset'] = max(offsets)
    report['center_alignment']['passed'] = max(offsets) <= MAX_CENTER_OFFSET

    all_passed = all(report[k]['passed'] for k in report)
    return all_passed, report


def print_report(report):
    """Print a structured validation report to stdout."""
    print('Validation Report:')

    cp = report['content_present']
    tag = 'PASS' if cp['passed'] else 'FAIL'
    detail = ', '.join('ok' if v else 'EMPTY' for v in cp['details'])
    print(f"  Content present: {tag} [{detail}]")

    av = report['area_variation']
    tag = 'PASS' if av['passed'] else 'FAIL'
    print(f"  Area variation:  {tag} (ratio={av['ratio']:.2f}, threshold={av['threshold']:.2f})")
    if av['areas']:
        print(f"    Frame areas: {av['areas']}")

    ca = report['center_alignment']
    tag = 'PASS' if ca['passed'] else 'FAIL'
    print(f"  Center alignment: {tag} (max_offset={ca['max_offset']:.2f}, threshold={ca['threshold']:.2f})")
    if ca['offsets']:
        print(f"    Frame offsets: [{', '.join(f'{o:.3f}' for o in ca['offsets'])}]")


def assemble_ping_pong(frames):
    """Arrange 4 frames into ping-pong sequence and fit to canvas.

    Sequence: 0 → 1 → 2 → 3 → 2 → 1 (6 frames total).
    Each frame is centered on an OUTPUT_SIZE canvas via fit_to_canvas.
    """
    order = [0, 1, 2, 3, 2, 1]
    result = []
    for idx in order:
        canvas, _, _, _, _ = fit_to_canvas(frames[idx], OUTPUT_SIZE)
        result.append(canvas)
    return result


def process_sprite_sheet(sheet_path, emotion, output_dir, name=None, validate_only=False):
    """Main pipeline: open → validate → remove bg → split → validate → GIF.

    Returns exit code (0, 1, or 2).
    """
    try:
        img = Image.open(sheet_path).convert('RGBA')
    except Exception as e:
        print(f'Error: cannot open image: {e}', file=sys.stderr)
        return 2

    valid, ratio = validate_aspect_ratio(img)
    if not valid:
        print(f'Validation failed: aspect ratio {ratio:.2f} not in '
              f'[{MIN_ASPECT_RATIO}, {MAX_ASPECT_RATIO}]', file=sys.stderr)
        return 1

    print(f'Sheet: {img.size[0]}x{img.size[1]}, ratio={ratio:.2f}')

    try:
        img = remove_background(img)
    except Exception as e:
        print(f'Error: background removal failed: {e}', file=sys.stderr)
        return 2

    frames = split_sheet(img)
    valid, report = validate_frames(frames)
    print_report(report)

    if not valid:
        return 1
    if validate_only:
        print('Validation passed.')
        return 0

    try:
        ping_pong = assemble_ping_pong(frames)
        duration = EMOTION_DURATIONS[emotion]
        os.makedirs(output_dir, exist_ok=True)

        # 128px display GIF (no watermark)
        display_path = os.path.join(output_dir, f'{emotion}.gif')
        display_frames = _resize_frames(ping_pong, DISPLAY_SIZE)
        _save_gif(display_frames, display_path, duration)

        # 256px @2x GIF (with watermark if name provided)
        hires_path = os.path.join(output_dir, f'{emotion}@2x.gif')
        hires_frames = [add_watermark(f, name) for f in ping_pong] if name else ping_pong
        _save_gif(hires_frames, hires_path, duration)

        for path in [display_path, hires_path]:
            size_kb = os.path.getsize(path) // 1024
            print(f'  {os.path.basename(path)} ({size_kb}KB)')

    except Exception as e:
        print(f'Error: processing failed: {e}', file=sys.stderr)
        return 2

    return 0


def main():
    parser = argparse.ArgumentParser(
        description='Sprite Sheet Spike — validate and convert 1x4 sprite sheets to GIF')
    parser.add_argument('--sheet', required=True, help='Path to 1x4 sprite sheet PNG')
    parser.add_argument('--emotion', required=True, choices=VALID_EMOTIONS,
                        help='Emotion type')
    parser.add_argument('--output', required=True, help='Output directory')
    parser.add_argument('--name', help='Cola name (for watermark on @2x)')
    parser.add_argument('--validate-only', action='store_true',
                        help='Only validate the sheet, do not generate GIFs')
    args = parser.parse_args()

    sheet_path = os.path.expanduser(args.sheet)
    if not os.path.exists(sheet_path):
        print(f'Error: file not found: {sheet_path}', file=sys.stderr)
        sys.exit(2)

    output_dir = os.path.expanduser(args.output)
    rc = process_sprite_sheet(sheet_path, args.emotion, output_dir,
                              name=args.name, validate_only=args.validate_only)
    sys.exit(rc)


if __name__ == '__main__':
    main()
