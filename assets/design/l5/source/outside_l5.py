from PIL import Image
import numpy as np
for src, dst in [('od.png', 'out/L5_outside_day_1104x432.png'), ('oe.png', 'out/L5_outside_evening_1104x432.png')]:
    a = np.array(Image.open(src).convert('RGBA')); o = a.copy()
    a[204:244, 34:106] = o[132:172, 34:106]     # parked truck (the animated one parks here now)
    Image.fromarray(a).save(dst)
