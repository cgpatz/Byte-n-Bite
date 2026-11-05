from PIL import Image
import numpy as np
for src, dst in [('od.png', 'out/L4_outside_day_768x432.png'), ('oe.png', 'out/L4_outside_evening_768x432.png')]:
    a = np.array(Image.open(src).convert('RGBA')); o = a.copy()
    a[58:100, 572:644] = o[58:100, 658:730]     # parked truck (the animated one parks here)
    a[106:136, 572:666] = o[134:164, 572:666]   # crates (Level 4 crates land in the indoor delivery room)
    Image.fromarray(a).save(dst)
