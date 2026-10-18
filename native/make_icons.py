from PIL import Image, ImageDraw, ImageFilter
import os, math

S = 768
OUT = 'android/app/src/main/res'
variants = {
    'blue': ((20, 38, 110), (120, 175, 255)),
    'green': ((8, 86, 70), (95, 225, 175)),
    'purple': ((62, 26, 140), (185, 145, 250)),
    'dark': ((8, 10, 18), (88, 94, 120)),
}


def bez(p0, p1, p2, p3, n=40):
    return [((1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t * t * p2[0] + t ** 3 * p3[0],
             (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t * t * p2[1] + t ** 3 * p3[1])
            for t in [i / n for i in range(n + 1)]]


def drop_pts(w, h, sc, ox, oy):
    segs = [((.5, .05), (.5, .05), (.17, .42), (.17, .64)), ((.17, .64), (.17, .82), (.32, .95), (.5, .95)),
            ((.5, .95), (.68, .95), (.83, .82), (.83, .64)), ((.83, .64), (.83, .42), (.5, .05), (.5, .05))]
    pts = []
    for a, b, c, d in segs:
        pts += bez((a[0] * w, a[1] * h), (b[0] * w, b[1] * h), (c[0] * w, c[1] * h), (d[0] * w, d[1] * h))
    return [(ox + x * sc, oy + y * sc) for x, y in pts]


def grad(c1, c2):
    im = Image.new('RGB', (S, S))
    px = im.load()
    for y in range(S):
        for x in range(S):
            t = (x * 0.4 + y * 0.6) / S
            px[x, y] = tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))
    return im


def spark(d, cx, cy, r, fill):
    pts = []
    for a, b in [((0, -1), (1, 0)), ((1, 0), (0, 1)), ((0, 1), (-1, 0)), ((-1, 0), (0, -1))]:
        for t in [i / 12 for i in range(13)]:
            pts.append(((1 - t) ** 2 * (cx + a[0] * r) + 2 * (1 - t) * t * cx + t * t * (cx + b[0] * r),
                        (1 - t) ** 2 * (cy + a[1] * r) + 2 * (1 - t) * t * cy + t * t * (cy + b[1] * r)))
    d.polygon(pts, fill=fill)


def make(name, c1, c2):
    bg = grad(c1, c2).convert('RGBA')
    ov = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    d.ellipse((-200, -250, 520, 330), fill=(255, 255, 255, 62))
    d.ellipse((380, 560, 1000, 1050), fill=(255, 255, 255, 30))
    bg = Image.alpha_composite(bg, ov.filter(ImageFilter.GaussianBlur(16)))
    sc = S * 0.62
    ox = S * 0.19
    oy = S * 0.15
    dp = drop_pts(S, S, 0.62, ox, oy)
    sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(x + 6, y + 16) for x, y in dp], fill=(0, 0, 0, 70))
    bg = Image.alpha_composite(bg, sh.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(bg)
    d.polygon(dp, fill=(255, 255, 255, 246))
    cx = ox + 0.5 * sc
    cy = oy + 0.63 * sc
    r = 0.215 * sc
    wd = int(0.05 * S)
    col = tuple(int(v * 0.85) for v in c1) + (255,)
    d.arc((cx - r, cy - r, cx + r, cy + r), 38, 322, fill=col, width=wd)
    for ang in (38, 322):
        a = math.radians(ang)
        x = cx + (r - wd / 2) * math.cos(a)
        y = cy + (r - wd / 2) * math.sin(a)
        d.ellipse((x - wd / 2, y - wd / 2, x + wd / 2, y + wd / 2), fill=col)
    hl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse((ox + sc * 0.30, oy + sc * 0.34, ox + sc * 0.40, oy + sc * 0.50), fill=(150, 190, 255, 110))
    bg = Image.alpha_composite(bg, hl.filter(ImageFilter.GaussianBlur(5)))
    d = ImageDraw.Draw(bg)
    spark(d, S * 0.80, S * 0.22, S * 0.075, (255, 255, 255, 240))
    m = Image.new('L', (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, S - 1, S - 1), radius=int(S * 0.26), fill=255)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.paste(bg, (0, 0), m)
    for dn, sz in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        p = '%s/mipmap-%s' % (OUT, dn)
        os.makedirs(p, exist_ok=True)
        out.resize((sz, sz), Image.LANCZOS).save('%s/ic_%s.png' % (p, name))


for n, (a, b) in variants.items():
    make(n, a, b)
print('icons ok')
