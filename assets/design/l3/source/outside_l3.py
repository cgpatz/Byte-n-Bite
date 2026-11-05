from PIL import Image
import numpy as np, sys
for src, dst in [('od.png', 'out/L3_outside_day_960x540.png'), ('oe.png', 'out/L3_outside_evening_960x540.png')]:
    a = np.array(Image.open(src).convert('RGBA'))
    o = a.copy()
    def sand(x0, y0, x1, y1, dy=-64):
        a[y0:y1, x0:x1] = o[y0 + dy:y1 + dy, x0:x1]
    sand(656, 122, 728, 166)      # parked truck (the animated one parks here now)
    sand(636, 156, 678, 184)      # crates beside it (crates land indoors on Level 3)
    sand(598, 138, 622, 154)      # door mat at the old door height
    a[123:132, 600:620] = o[142:151, 600:620]   # door mat beside the new back door
    Image.fromarray(a).save(dst)
