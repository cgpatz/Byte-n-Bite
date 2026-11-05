"""Level 4 (courtyard izakaya): removes the baked tables/chairs and delivery crates
from the designer's room picture (tables are bought in-game and drawn as sprites),
cuts the table/chair sprites, and fixes the see-through gaps by the right wall."""
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


def palette(x0, y0, x1, y1):
    return {tuple(p) for p in old[y0:y1, x0:x1].reshape(-1, 4)}


def fill(region, offsets, pal):
    x0, y0, x1, y1 = region
    left = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not mask[y, x]:
                continue
            for dx, dy in offsets:
                sx, sy = x + dx, y + dy
                if 0 <= sx < W and 0 <= sy < H and not mask[sy, sx] and tuple(old[sy, sx]) in pal:
                    img[y, x] = old[sy, sx]
                    break
            else:
                left += 1
    return left


# small tables: centre art (40,176) (96,176) (40,232) (96,232) left wing, right wing +224
CENTRES = [(40, 176), (96, 176), (40, 232), (96, 232), (248, 176), (304, 176), (248, 232), (304, 232)]
for cx, cy in CENTRES:
    M(cx - 18, cy - 10, cx + 18, cy + 18)
    M(cx - 5, cy - 21, cx + 6, cy - 9)
# see-through gaps beside the right wall (col 20 rows 9, 11, 13, 15)
alpha0 = old[:, :, 3] == 0
gaps = np.zeros((H, W), bool)
gaps[108:272, 300:336] = alpha0[108:272, 300:336]
mask |= gaps
white = (old[:, :, :3].astype(int).sum(2) >= 760)
mask[108:272, 300:336] |= white[108:272, 300:336]
tat = palette(16, 192, 128, 208) | palette(224, 192, 336, 208) | palette(48, 144, 80, 160)
lattice = sorted([(32 * i, 64 * j) for i in range(-6, 7) for j in range(-2, 3) if (i, j) != (0, 0)],
                 key=lambda d: abs(d[0]) + abs(d[1]))
approx = sorted([(16 + 32 * i, 16 + 32 * j) for i in range(-6, 6) for j in range(-3, 3)],
                key=lambda d: abs(d[0]) + abs(d[1]))
print('tatami left', fill((0, 100, W, 280), lattice + approx, tat))

# courtyard parasol table T9 (centre art 176, 208)
M(157, 184, 201, 224)
grav = palette(162, 172, 194, 182)
print('gravel left', fill((150, 180, 210, 230), [(0, 4 * k * s) for k in range(1, 16) for s in (-1, 1)], grav))

# delivery crates
M(290, 44, 328, 68)
dfl = palette(296, 18, 330, 44)
print('delivery left', fill((286, 40, 334, 70), [(0, -4 * k) for k in range(1, 8)] + [(dx, 0) for dx in (-40, 40)], dfl))
# the left wall's lower lantern overlaps a chair: put it back
img[234:252, 16:23] = old[234:252, 16:23]
img[242:252, 23:27] = old[242:252, 23:27]
Image.fromarray(img).save(os.path.join(OUT, 'L4.png'))


def sprite(x0, y0, x1, y1, name, keep=None):
    o = old[y0:y1, x0:x1].astype(int); c = img[y0:y1, x0:x1].astype(int)
    m = binary_fill_holes(np.abs(o - c).sum(2) > 0)
    out = old[y0:y1, x0:x1].copy()
    if keep is not None:
        for yy in range(m.shape[0]):
            for xx in range(m.shape[1]):
                m[yy, xx] = m[yy, xx] and keep(x0 + xx, y0 + yy)
    out[~m] = 0
    ys, xs = np.where(out[:, :, 3] > 0)
    out = out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    Image.fromarray(out).save(os.path.join(OUT, name))
    return out.shape[1], out.shape[0]


print('table', sprite(32, 166, 49, 183, 'table.png'))
print('chair', sprite(22, 170, 32, 188, 'chair.png'))
print('parasol', sprite(160, 184, 200, 216, 'parasol_table.png',
                        lambda x, y: (y < 200 and 163 <= x < 196) or (y >= 200 and 168 <= x < 184)))
