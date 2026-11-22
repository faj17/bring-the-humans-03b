#!/usr/bin/env python3
"""Render one centred line of styled display text to a transparent RGBA PNG.

Why PIL and not ffmpeg drawtext: ffmpeg's drawtext drops the alpha channel,
so text overlays come out opaque. PIL renders true RGBA, which the render
pipeline then fades and scales per frame.

Usage:
    mktext2.py <out.png> <font.ttf> <size> <height> [options] <text>

Options (key=value, given before the text):
    fill=RRGGBB or RRGGBBAA   text fill            (default FFFFFFFF)
    stroke=N                 px outline           (default 0)
    stroke_color=RRGGBB      outline colour       (default 191419)
    shadow_dx=N shadow_dy=N  hard offset shadow   (default 0 0)
    shadow_color=RRGGBB      shadow colour        (default 191419)
    track=N                  extra px per gap     (default 0)
    box=1                    rounded ink slab behind the text (default 0)
    box_fill=RRGGBB          slab colour          (default 191419)
    box_radius=N             slab corner radius   (default 18)
    box_pad=N                slab padding         (default 28)

The text is rendered as-is; pass the exact wording on the command line.
Canvas width is fixed at 1080 (the ad is 1080x1920); the line is centred.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

CANVAS_W = 1080
INK = (25, 20, 25, 255)   # #191419, make.fun's ink
WHITE = (255, 255, 255, 255)


def parse_rgba(spec, fallback):
    """'RRGGBB' or 'RRGGBBAA' (with or without '#') -> (r, g, b, a)."""
    s = spec.lstrip("#")
    if len(s) == 6:
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)
    if len(s) == 8:
        return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4, 6))
    return fallback


def tracked_width(draw, text, font, track):
    """Advance of the whole line, tracking included between characters."""
    total = 0
    for i, ch in enumerate(text):
        total += draw.textlength(ch, font=font)
        if i < len(text) - 1:
            total += track
    return total


def draw_tracked(draw, x, y, text, font, fill, track, stroke_w=0, stroke_fill=None):
    """Draw the line char by char so `track` spacing applies per gap."""
    for i, ch in enumerate(text):
        draw.text((x, y), ch, font=font, fill=fill,
                  stroke_width=stroke_w, stroke_fill=stroke_fill)
        x += draw.textlength(ch, font=font) + track


def parse_opts(argv):
    """Split argv into (options dict, text). Options are key=value items."""
    opts = {}
    rest = list(argv)
    while rest and "=" in rest[0]:
        key, val = rest[0].split("=", 1)
        opts[key] = val
        rest = rest[1:]
    return opts, " ".join(rest)


def render_line(out, font_path, size, height, opts, text):
    fill = parse_rgba(opts.get("fill", "FFFFFF"), WHITE)
    stroke_w = int(opts.get("stroke", 0))
    stroke_c = parse_rgba(opts.get("stroke_color", "191419"), INK)
    sdx = int(opts.get("shadow_dx", 0))
    sdy = int(opts.get("shadow_dy", 0))
    shadow_c = parse_rgba(opts.get("shadow_color", "191419"), INK)
    track = int(opts.get("track", 0))
    box = opts.get("box", "0") == "1"
    box_fill = parse_rgba(opts.get("box_fill", "191419"), INK)
    box_radius = int(opts.get("box_radius", 18))
    box_pad = int(opts.get("box_pad", 28))

    img = Image.new("RGBA", (CANVAS_W, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(font_path, size)
    bbox = draw.textbbox((0, 0), text, font=font, stroke_width=stroke_w)
    tw = tracked_width(draw, text, font, track)
    th = bbox[3] - bbox[1]
    x = (CANVAS_W - tw) // 2
    y = (height - th) // 2 - bbox[1]
    if box:
        draw.rounded_rectangle(
            [x - box_pad, y - box_pad, x + tw + box_pad, y + th + box_pad],
            radius=box_radius, fill=box_fill)
    if sdx or sdy:
        draw_tracked(draw, x + sdx, y + sdy, text, font, shadow_c, track,
                     stroke_w, stroke_c)
    draw_tracked(draw, x, y, text, font, fill, track, stroke_w, stroke_c)
    img.save(out)


def main():
    out, font_path = sys.argv[1], sys.argv[2]
    size, height = int(sys.argv[3]), int(sys.argv[4])
    opts, text = parse_opts(sys.argv[5:])
    render_line(out, font_path, size, height, opts, text)


if __name__ == "__main__":
    main()
