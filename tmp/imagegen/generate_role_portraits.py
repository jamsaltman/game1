from PIL import Image, ImageDraw, ImageFilter
from math import sin, cos, pi

W, H = 384, 512
PAPER = (239, 231, 213, 255)
INK = (28, 24, 22, 255)
INK_SOFT = (73, 64, 57, 255)
SHADOW = (0, 0, 0, 70)
BG_WASH = (198, 183, 158, 255)

ROLES = {
    "redirector": {
        "accent": (201, 163, 116, 255),
        "accent_dark": (138, 105, 70, 255),
        "secondary": (226, 203, 172, 255),
    },
    "smuggler": {
        "accent": (230, 177, 84, 255),
        "accent_dark": (150, 103, 44, 255),
        "secondary": (245, 214, 149, 255),
    },
    "rewinder": {
        "accent": (168, 186, 118, 255),
        "accent_dark": (101, 121, 64, 255),
        "secondary": (212, 223, 176, 255),
    },
}


def rgba(color, a=None):
    if a is None:
        return color
    return (color[0], color[1], color[2], a)


def blend(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3)) + (255,)


def add_stains(img, accent, seed_shift):
    d = ImageDraw.Draw(img, 'RGBA')
    for i in range(18):
        x = 30 + ((i * 97 + seed_shift * 31) % (W - 60))
        y = 30 + ((i * 67 + seed_shift * 17) % (H - 60))
        rx = 18 + ((i * 13 + seed_shift) % 36)
        ry = 12 + ((i * 19 + seed_shift) % 28)
        color = rgba(blend(accent, BG_WASH, 0.45), 26)
        d.ellipse((x - rx, y - ry, x + rx, y + ry), fill=color)


def add_scratches(img, accent, seed_shift):
    d = ImageDraw.Draw(img, 'RGBA')
    for i in range(24):
        x1 = 20 + ((i * 41 + seed_shift * 11) % (W - 40))
        y1 = 20 + ((i * 83 + seed_shift * 13) % (H - 40))
        x2 = x1 + 12 + (i % 21)
        y2 = y1 + ((i * 7) % 13) - 6
        d.line((x1, y1, x2, y2), fill=rgba(blend(accent, PAPER, 0.2), 36), width=1)


def make_background(role, palette):
    img = Image.new('RGBA', (W, H), PAPER)
    px = img.load()
    for y in range(H):
        for x in range(W):
            nx = (x - W / 2) / W
            ny = (y - H / 2) / H
            dist = (nx * nx + (ny * 1.15) ** 2) ** 0.5
            t = min(max((dist - 0.05) / 0.65, 0), 1)
            base = blend(PAPER, BG_WASH, 0.22 + 0.18 * t)
            px[x, y] = base
    add_stains(img, palette['accent'], len(role))
    add_scratches(img, palette['accent_dark'], len(role) * 3)
    overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay, 'RGBA')
    d.rectangle((0, 0, W, 120), fill=rgba(palette['accent'], 120))
    d.rectangle((0, 120, W, H), fill=rgba(palette['secondary'], 24))
    overlay = overlay.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(overlay)
    return img


def draw_vignette(img):
    overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = overlay.load()
    for y in range(H):
        for x in range(W):
            dx = (x - W / 2) / (W / 2)
            dy = (y - H / 2) / (H / 2)
            dist = min((dx * dx + dy * dy) ** 0.5, 1.0)
            alpha = int(max(0, (dist - 0.35) / 0.65) * 110)
            px[x, y] = (22, 19, 17, alpha)
    img.alpha_composite(overlay)


def draw_frame(d, palette):
    d.rectangle((16, 16, W - 16, H - 16), outline=rgba(INK, 220), width=4)
    d.rectangle((28, 28, W - 28, H - 28), outline=rgba(palette['accent_dark'], 180), width=2)
    d.rectangle((24, 24, 72, 72), fill=rgba(PAPER, 235), outline=rgba(INK, 220), width=3)


def draw_bent_arrow(d, box, color, width=8):
    x1, y1, x2, y2 = box
    mx = (x1 + x2) // 2
    my = (y1 + y2) // 2
    d.line((x1 + 12, my, mx + 10, my), fill=color, width=width)
    d.line((mx, y2 - 12, mx, my), fill=color, width=width)
    d.polygon([(x2 - 12, my), (x2 - 42, my - 20), (x2 - 42, my + 20)], fill=color)


def draw_rewind_arrow(d, box, color, width=8):
    x1, y1, x2, y2 = box
    my = (y1 + y2) // 2
    d.line((x1 + 55, my, x2 - 25, my), fill=color, width=width)
    d.line((x1 + 55, y1 + 24, x1 + 55, my), fill=color, width=width)
    d.polygon([(x1 + 12, my), (x1 + 52, my - 22), (x1 + 52, my + 22)], fill=color)


def draw_person_base(d, palette, hood=False, long_coat=False, scarf=False, satchel=False, scout=False):
    shadow = [(94, 430), (288, 430), (262, 466), (122, 466)]
    d.polygon(shadow, fill=rgba(SHADOW, 90))
    coat = [(110, 170), (274, 170), (302, 410), (82, 410)]
    d.polygon(coat, fill=INK)
    inner = [(126, 182), (258, 182), (280, 396), (104, 396)]
    d.polygon(inner, fill=palette['accent_dark'])
    if long_coat:
        d.rectangle((150, 290, 234, 410), fill=rgba(INK, 255))
    d.ellipse((146, 96, 238, 188), fill=(233, 221, 199, 255), outline=rgba(INK, 255), width=3)
    if hood:
        d.pieslice((118, 68, 266, 214), 200, 340, fill=rgba(INK, 255))
        d.arc((118, 68, 266, 214), 202, 338, fill=rgba(PAPER, 110), width=2)
    if scarf:
        d.rectangle((132, 192, 252, 216), fill=(126, 40, 34, 255))
        d.rectangle((204, 210, 226, 294), fill=(126, 40, 34, 255))
    if satchel:
        d.rounded_rectangle((82, 244, 130, 346), radius=8, fill=INK_SOFT)
        d.line((116, 168, 92, 260), fill=rgba(PAPER, 180), width=6)
        d.line((134, 168, 104, 262), fill=rgba(INK, 255), width=3)
    if scout:
        d.rounded_rectangle((236, 196, 282, 238), radius=6, fill=rgba(PAPER, 235), outline=rgba(INK, 210), width=3)
        d.line((238, 236, 290, 272), fill=rgba(INK, 220), width=5)


def draw_redirector(img, palette):
    d = ImageDraw.Draw(img, 'RGBA')
    draw_frame(d, palette)
    draw_person_base(d, palette, scout=True)
    d.polygon([(158, 168), (192, 144), (226, 168), (192, 176)], fill=rgba(PAPER, 70))
    d.line((192, 176, 192, 210), fill=rgba(INK, 190), width=3)
    draw_bent_arrow(d, (84, 286, 302, 382), rgba(palette['accent'], 245), width=10)
    d.arc((76, 276, 176, 376), 300, 88, fill=rgba(palette['secondary'], 180), width=5)
    d.ellipse((278, 118, 320, 160), outline=rgba(INK, 190), width=3)
    d.line((296, 158, 320, 180), fill=rgba(INK, 190), width=4)
    draw_bent_arrow(d, (34, 34, 62, 62), rgba(INK, 255), width=4)


def draw_smuggler(img, palette):
    d = ImageDraw.Draw(img, 'RGBA')
    draw_frame(d, palette)
    draw_person_base(d, palette, satchel=True, long_coat=True)
    crate = (210, 282, 298, 348)
    d.rounded_rectangle(crate, radius=10, fill=rgba(palette['accent'], 225), outline=rgba(INK, 230), width=4)
    d.line((210, 315, 298, 315), fill=rgba(INK, 160), width=3)
    d.line((254, 282, 254, 348), fill=rgba(INK, 160), width=3)
    d.rectangle((222, 296, 286, 334), outline=rgba(PAPER, 120), width=2)
    d.line((192, 214, 250, 286), fill=rgba(INK, 240), width=6)
    d.line((194, 214, 246, 286), fill=rgba(PAPER, 120), width=2)
    d.line((92, 340, 144, 300), fill=rgba(palette['secondary'], 190), width=5)
    d.line((144, 300, 182, 318), fill=rgba(palette['secondary'], 190), width=5)
    d.rectangle((36, 36, 60, 60), outline=rgba(INK, 255), width=4)
    d.rectangle((42, 44, 54, 52), fill=rgba(INK, 255))


def draw_rewinder(img, palette):
    d = ImageDraw.Draw(img, 'RGBA')
    draw_frame(d, palette)
    draw_person_base(d, palette, hood=True)
    d.line((250, 190, 284, 286), fill=rgba(INK, 240), width=6)
    d.line((248, 190, 282, 286), fill=rgba(PAPER, 120), width=2)
    watch = (228, 270, 314, 356)
    d.ellipse(watch, fill=rgba(palette['secondary'], 240), outline=rgba(INK, 240), width=4)
    d.ellipse((242, 284, 300, 342), outline=rgba(palette['accent_dark'], 220), width=3)
    cx, cy = 271, 313
    d.line((cx, cy, cx, cy - 20), fill=rgba(INK, 220), width=3)
    d.line((cx, cy, cx + 16, cy + 10), fill=rgba(INK, 220), width=3)
    d.arc((150, 248, 306, 404), 20, 320, fill=rgba(palette['accent'], 230), width=8)
    d.polygon([(190, 372), (168, 344), (204, 344)], fill=rgba(palette['accent'], 230))
    draw_rewind_arrow(d, (84, 286, 220, 360), rgba(palette['accent'], 240), width=8)
    draw_rewind_arrow(d, (34, 34, 62, 62), rgba(INK, 255), width=4)


def save_role(role, fn):
    palette = ROLES[role]
    img = make_background(role, palette)
    fn(img, palette)
    draw_vignette(img)
    img.save(f'assets/portraits/individual/{role}.png')


save_role('redirector', draw_redirector)
save_role('smuggler', draw_smuggler)
save_role('rewinder', draw_rewinder)
