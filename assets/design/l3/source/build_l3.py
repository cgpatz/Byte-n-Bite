"""Builds the rearranged, enlarged Level 3 room (16x16 tiles, 256x256 art px)
from the designer's baked 16x14 room picture, plus separate sprites.

Old picture coords -> new: everything at old y >= 64 moves down 32 px (2 tiles);
the band old y 64..96 is shown twice on the left side (dining + kitchen grow),
the storage wing (x >= 176) is rebuilt 4 rows tall.
"""
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


def fill(cands, region):
    x0, y0, x1, y1 = region
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not mask[y, x]:
                continue
            for dx, dy in cands:
                sx, sy = x + dx, y + dy
                if 0 <= sx < W and 0 <= sy < H and not mask[sy, sx]:
                    img[y, x] = old[sy, sx]
                    break


# ------------------------------------------------ clean (old coordinates)
# T1 + T2 (chairs, table, top/bottom cushions), stools
for r in [(21, 32, 58, 51), (35, 21, 46, 30), (35, 48, 46, 57),
          (21, 94, 58, 116), (35, 83, 46, 92), (35, 112, 46, 121), (82, 64, 95, 127)]:
    M(*r)
M(96, 42, 112, 144)                                             # counter
M(112, 87, 176, 128); M(160, 122, 176, 144)                     # assembly, trash


def is_rug(x, y):
    return 32 <= x < 64 and 27 <= y < 133


def is_plank(x, y):
    if not (16 <= x < 112 and 16 <= y < 140) or is_rug(x, y):
        return False
    return not (16 <= x < 33 and 12 <= y < 36)    # potted plant


for y in range(16, 140):
    for x in range(16, 96):
        if not mask[y, x]:
            continue
        if is_rug(x, y):
            src = [(x, 70)] if y >= 31 else [(x + 12, y)]
        else:
            src = [(x, y + 32), (x, y - 32), (x, y + 64), (x, y - 64), (x + 16, y), (x - 16, y), (x + 32, y)]
            src = [p for p in src if is_plank(*p)]
        for sx, sy in src:
            if not mask[sy, sx]:
                img[y, x] = old[sy, sx]; break
        else:
            print('no source', x, y)
fill([(-16, 0), (-32, 0)], (96, 16, 112, 144))
fill([(0, -32), (0, -64), (0, 32), (-32, 0), (32, 0)], (112, 40, 177, 144))
mask[:] = False

CHK = old[48:80, 128:160].copy()            # clean checker, phase origin (128, 48)
def checker(x, y):
    return CHK[(y - 48) % 32, (x - 128) % 32]

# delivery room: dark floor, dashed border top + bottom, no boxes
dark = old[26, 200].copy()
img[22:48, 190:236] = dark
img[44:47, 186:239] = old[18:21, 186:239]
img[47, 184:240] = dark
# storage floor (old rows 3-4)
for y in range(48, 80):
    for x in range(176, 240):
        img[y, x] = checker(x, y)

DECK = old[172:196, 78:110].copy()          # deck boards: period 24 (v), tiled 32 (h)
def deck(x, y):
    return DECK[(y - 172) % 24, (x - 78) % 32]

keep = np.zeros((H, W), bool)
keep[144:162, 174:192] = True                # lifebuoy
keep[184:206, 224:242] = True                # deck plant
for y in range(H):
    for x in range(W):
        if keep[y, x]:
            continue
        if (16 <= x < 240 and 158 <= y < 200) or (192 <= x < 240 and 96 <= y < 200):
            img[y, x] = deck(x, y)
img[158, 16:192] = old[165, 100]             # shadow line under the front wall


# ------------------------------------------------------------- sprites
def sprite(x0, y0, x1, y1, name, keepfn=None, peel=True):
    o = old[y0:y1, x0:x1].astype(int); c = img[y0:y1, x0:x1].astype(int)
    m = np.abs(o - c).sum(2) > 0
    m = binary_fill_holes(m)
    if keepfn is not None and not peel:
        m[:] = True
    if keepfn is not None:
        for yy in range(m.shape[0]):
            for xx in range(m.shape[1]):
                if m[yy, xx] and not keepfn(x0 + xx, y0 + yy):
                    m[yy, xx] = False
    out = old[y0:y1, x0:x1].copy()
    out[~m] = 0
    # peel floor-coloured pixels that touch the transparent outside
    floor = {tuple(p) for p in img[max(0, y0 - 6):y1 + 6, max(0, x0 - 6):x1 + 6].reshape(-1, 4)}
    floor.discard((20, 9, 5, 255))
    for _ in range(2 if peel else 0):
        h, w = out.shape[:2]
        drop = []
        for yy in range(h):
            for xx in range(w):
                if out[yy, xx, 3] == 0 or tuple(out[yy, xx]) not in floor or int(out[yy, xx, :3].sum()) < 260:
                    continue
                edge = yy in (0, h - 1) or xx in (0, w - 1) or any(out[yy + dy, xx + dx, 3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge:
                    drop.append((yy, xx))
        for yy, xx in drop:
            out[yy, xx] = 0
    ys, xs = np.where(out[:, :, 3] > 0)
    out = out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    Image.fromarray(out).save(os.path.join(OUT, name))
    return (out.shape[1], out.shape[0])


def umbrella_keep(cx, cy, r, t):
    inner = set()
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= (r - 3) ** 2:
                inner.add(tuple(old[y, x]))
    def k(x, y):
        d2 = (x - cx) ** 2 + (y - cy) ** 2
        if y < cy - r + 2 and abs(x - cx) > 5:
            return False
        if d2 <= (r + 0.7) ** 2:
            p = old[y, x]
            if d2 <= (r - 2) ** 2 or p[:3].sum() < 120 or tuple(p) in inner:
                return True
        if t[0] <= x < t[2] and t[1] <= y < t[3] - 4:
            return True
        legs = t[0] <= x < t[0] + 4 or t[2] - 4 <= x < t[2]
        return legs and t[3] - 4 <= y < t[3] and old[y, x, :3].sum() < 200
    return k


S = {}
S['serving_counter'] = sprite(96, 42, 112, 144, 'serving_counter.png')
S['assembly'] = sprite(112, 86, 176, 128, 'assembly.png')
S['trash'] = sprite(161, 127, 176, 142, 'trash.png')
S['prep_board'] = sprite(176, 54, 208, 81, 'prep_board.png')
S['fridge'] = sprite(209, 40, 224, 81, 'fridge.png')
S['shelves'] = sprite(225, 43, 240, 81, 'shelves.png')
S['table'] = sprite(32, 31, 48, 49, 'table.png')
S['chair'] = sprite(22, 34, 32, 50, 'chair.png')
S['stool'] = sprite(80, 62, 95, 80, 'stool.png')
S['umbrella_table'] = sprite(195, 92, 222, 130, 'umbrella_table.png', umbrella_keep(208.5, 105.5, 10, (200, 112, 216, 128)), peel=False)
S['umbrella_table_teal'] = sprite(195, 148, 222, 186, 'umbrella_table_teal.png', umbrella_keep(208.5, 161.5, 10, (200, 168, 216, 184)), peel=False)
S['family_table'] = sprite(30, 154, 66, 193, 'family_table.png', umbrella_keep(48.5, 169, 12, (32, 177, 64, 192)), peel=False)
S['family_table_teal'] = sprite(118, 154, 154, 193, 'family_table_teal.png', umbrella_keep(136.5, 169, 12, (120, 177, 152, 192)), peel=False)
print(S)
Image.fromarray(img).save(os.path.join(OUT, 'clean_old.png'))

# ------------------------------------------------------------- compose new
NH = 256
new = np.zeros((NH, W, 4), np.uint8)
L = 176
new[0:64, :L] = img[0:64, :L]
new[64:96, :L] = img[64:96, :L]
new[96:256, :L] = img[64:224, :L]
new[0:48, L:] = img[0:48, L:]
new[112:256, L:] = img[80:224, L:]
for y in range(48, 112):
    for x in range(L, 240):
        new[y, x] = checker(x, y)
new[48:64, 240:] = img[48:64, 240:]
new[64:96, 240:] = img[56:88, 240:]
new[96:112, 240:] = img[64:80, 240:]

# string lights along the house front wall and the side deck
BULBS = [(250, 210, 90), (110, 200, 205), (240, 130, 150), (255, 240, 200)]
def lights(x0, x1, ybase, span=26):
    i = 0
    for x in range(x0, x1):
        if 174 <= x < 192 and ybase > 150:
            continue
        t = ((x - x0) % span) / span
        y = ybase + int(round(3 * (1 - (2 * t - 1) ** 2)))
        new[y, x] = (40, 28, 20, 255)
        if (x - x0) % 8 == 4:
            c = BULBS[i % 4]; i += 1
            new[y + 1, x] = (*c, 255); new[y + 2, x] = (*c, 255)
lights(18, 174, 192)
lights(194, 238, 130, 22)
Image.fromarray(new).save(os.path.join(OUT, 'L3.png'))
