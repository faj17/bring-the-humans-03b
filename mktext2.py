#!/usr/bin/env python3
"""Render one centred line of styled display text to a transparent RGBA PNG.
Usage: mktext2.py <out.png> <font.ttf> <size> <height> [options] <text>
Options (key=value, before the text):
  fill=RRGGBB or RRGGBBAA   (default FFFFFFFF)
  stroke=N                 (px outline, default 0)
  stroke_color=RRGGBB      (default 191419)
  shadow_dx=N shadow_dy=N  (hard offset shadow, default 0 0)
  shadow_color=RRGGBB      (default 191419)
  track=N                  (extra px between chars, default 0)
  box=1                    (rounded ink slab behind the text, default 0)
  box_fill=RRGGBB          (default 191419)
  box_radius=N             (default 18)
  box_pad=N                (default 28)
All text is uppercase-ready; pass the exact wording on the command line.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

W = 1080


def parse_color(s, default):
    s = s.lstrip("#")
    if len(s) == 6:
        r, g, b = int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)
        return (r, g, b, 255)
    if len(s) == 8:
        return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4, 6))
    return default


def text_width(d, text, font, track):
    w = 0
    for i, ch in enumerate(text):
        w += d.textlength(ch, font=font)
        if i < len(text) - 1:
            w += track
    return w


def draw_tracked(d, xy, text, font, fill, track, stroke_w=0, stroke_fill=None):
    x, y = xy
    for i, ch in enumerate(text):
        d.text((x, y), ch, font=font, fill=fill,
               stroke_width=stroke_w, stroke_fill=stroke_fill)
        x += d.textlength(ch, font=font) + track


def main():
    out, font_path, size, height = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    opts = {}
    args = sys.argv[5:]
    while args and "=" in args[0]:
        k, v = args[0].split("=", 1)
        opts[k] = v
        args = args[1:]
    text = " ".join(args)

    fill = parse_color(opts.get("fill", "FFFFFF"), (255, 255, 255, 255))
    stroke_w = int(opts.get("stroke", 0))
    stroke_c = parse_color(opts.get("stroke_color", "191419"), (25, 20, 25, 255))
    sdx, sdy = int(opts.get("shadow_dx", 0)), int(opts.get("shadow_dy", 0))
    shadow_c = parse_color(opts.get("shadow_color", "191419"), (25, 20, 25, 255))
    track = int(opts.get("track", 0))
    box = opts.get("box", "0") == "1"
    box_fill = parse_color(opts.get("box_fill", "191419"), (25, 20, 25, 255))
    box_radius = int(opts.get("box_radius", 18))
    box_pad = int(opts.get("box_pad", 28))

    img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(font_path, size)
    bbox = d.textbbox((0, 0), text, font=f, stroke_width=stroke_w)
    tw = text_width(d, text, f, track)
    th = bbox[3] - bbox[1]
    x = (W - tw) // 2
    y = (height - th) // 2 - bbox[1]
    if box:
        d.rounded_rectangle(
            [x - box_pad, y - box_pad, x + tw + box_pad, y + th + box_pad],
            radius=box_radius, fill=box_fill)
    if sdx or sdy:
        draw_tracked(d, (x + sdx, y + sdy), text, f, shadow_c, track, stroke_w, stroke_c)
    draw_tracked(d, (x, y), text, f, fill, track, stroke_w, stroke_c)
    img.save(out)


if __name__ == "__main__":
    main()
