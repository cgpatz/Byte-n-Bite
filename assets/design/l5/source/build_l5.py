"""Level 5 (harbour bistro): removes the baked salle/patio tables and delivery crates
from the designer's room picture (tables are bought in-game and drawn as sprites)
and cuts the table/chair sprites."""
from PIL import Image
import numpy as np, os, sys
from scipy.ndimage import binary_fill_holes

SRC = sys.argv[1] if len(sys.argv) > 1 else 'old.png'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'out'
os.makedirs(OUT, exist_ok=True)
old = np.array(Image.open(SRC).convert('RGBA')).astype(np.uint8)
H, W = old.shape[:2]
img = old.copy()
mask = np.zeros((H, W), bool)


def M(x0, y0, x1, y1):
    mask[y0:y1, x0:x1] = True


def pal(x0, y0, x1, y1):
    return {tuple(p) for p in old[y0:y1, x0:x1].reshape(-1, 4)}


def fill(region, offsets, palette, valid=lambda x, y: True):
    x0, y0, x1, y1 = region
    left = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not mask[y, x]:
                continue
            for dx, dy in offsets:
                sx, sy = x + dx, y + dy
                if 0 <= sx < W and 0 <= sy < H and not mask[sy, sx] and tuple(old[sy, sx]) in palette and valid(sx, sy):
                    img[y, x] = old[sy, sx]
                    break
            else:
                left += 1
    return left


def lattice(a, b, n=8):
    out = [(a[0] * i + b[0] * j, a[1] * i + b[1] * j) for i in range(-n, n + 1) for j in range(-n, n + 1)]
    return sorted([d for d in out if d != (0, 0)], key=lambda d: abs(d[0]) + abs(d[1]))


SMALL = [(488, 40), (440, 40), (360, 40), (312, 40), (488, 168), (440, 168), (360, 168), (312, 168)]
FAMILY = [(480, 104), (336, 104)]
PATIO = [(568, 136), (656, 128), (608, 176), (720, 168)]

# --- salle: small + family tables on the diagonal carpet
for cx, cy in SMALL:
    M(cx - 19, cy - 18, cx + 19, cy + 18)
for cx, cy in FAMILY:
    M(cx - 27, cy - 18, cx + 27, cy + 18)
carpet = pal(276, 64, 292, 90)
# the doorway between kitchen and salle is see-through in the picture: carpet it
door = (old[:, :, 3] == 0)
door[:, :250] = False; door[:, 280:] = False; door[:150] = False; door[200:] = False
mask |= door
print('salle left', fill((250, 16, 520, 208), lattice((8, 0), (4, 4)), carpet,
                         lambda x, y: 272 <= x < 520 and 24 <= y < 196 and not 378 <= x < 424))
mask[:] = False

# --- patio: parasol tables on brick; then mend the string lights
for cx, cy in PATIO:
    M(cx - 15, cy - 24, cx + 15, cy + 9)
brick = pal(560, 150, 580, 170) | pal(680, 180, 760, 196)
# the string lights: take the old wire out and hang a new one between the posts
for y in range(114, 136):
    for x in range(534, 778):
        if 734 <= x < 772 and y >= 110:
            continue                                   # fountain
        if tuple(old[y, x]) not in brick:
            mask[y, x] = True
print('patio left', fill((528, 100, 784, 200), lattice((8, 0), (0, 16)), brick))
mask[:] = False
WIRE = (40, 28, 22, 255)
anchors = [(533, 117), (612, 117), (690, 117), (734, 119), (772, 118), (779, 117)]
for (xa, ya), (xb, yb) in zip(anchors, anchors[1:]):
    if xa == 734:
        continue                                       # behind the fountain
    for x in range(xa, xb + 1):
        t = (x - xa) / max(1, xb - xa)
        y = int(round(ya + (yb - ya) * t + 6 * (1 - (2 * t - 1) ** 2)))
        img[y, x] = WIRE
        if (x - xa) % 8 == 4:
            img[y + 1, x] = (250, 225, 140, 255)
# --- delivery room crates
M(20, 184, 60, 207)
dark = pal(30, 160, 60, 180)
print('delivery left', fill((18, 180, 62, 202), [(0, -k) for k in range(8, 40, 4)], dark))
img[202:207, 18:76] = np.where(mask[202:207, 18:76, None], old[147:152, 18:76], img[202:207, 18:76])
img[8:35, 497:516] = old[8:35, 497:516]          # salle plant beside table 1
Image.fromarray(img).save(os.path.join(OUT, 'L5.png'))


def sprite(x0, y0, x1, y1, name, keep=None):
    o = old[y0:y1, x0:x1].astype(int); c = img[y0:y1, x0:x1].astype(int)
    m = binary_fill_holes(np.abs(o - c).sum(2) > 0)
    if keep is not None:
        for yy in range(m.shape[0]):
            for xx in range(m.shape[1]):
                m[yy, xx] = m[yy, xx] and keep(x0 + xx, y0 + yy)
    out = old[y0:y1, x0:x1].copy()
    out[~m] = 0
    ys, xs = np.where(out[:, :, 3] > 0)
    out = out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    Image.fromarray(out).save(os.path.join(OUT, name))
    return out.shape[1], out.shape[0]


print('table', sprite(304, 31, 321, 50, 'table.png', lambda x, y: x < 320 and y >= 34))
print('family', sprite(320, 95, 353, 114, 'family_table.png', lambda x, y: 321 <= x < 350 and y >= 98))
print('chair', sprite(295, 35, 305, 48, 'chair.png'))
def umb(x, y):
    d2 = (x - 568.5) ** 2 + (y - 123) ** 2
    if d2 > 11.8 ** 2 or y < 115:
        return False
    top = {115: (563, 569), 116: (561, 575), 117: (561, 576)}   # the hatched patio edge sits behind the top
    if y in top:
        return top[y][0] <= x < top[y][1]
    if d2 <= 9.5 ** 2:
        return True
    r, g, b = (int(v) for v in old[y, x, :3])
    return r + g + b < 90 or (r > 150 and g < 90) or r + g + b > 600
print('patio table', sprite(553, 112, 583, 145, 'patio_table.png', lambda x, y: umb(x, y) or (131 <= y < 145 and 562 <= x < 575)))
print('patio chair', sprite(556, 135, 563, 143, 'patio_chair.png'))
