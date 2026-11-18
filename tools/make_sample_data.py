"""Creates data/sample_image_XX.png and data/annotations.json (mock AI output).

BLOCKS x IMAGES_PER_BLOCK images. The design doc plans ~40 images per block;
we use fewer here so the whole block/level flow can be tried in a few minutes.
"""
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

DATA = Path(__file__).parent.parent / "data"
W, H = 800, 600
BLOCKS, IMAGES_PER_BLOCK, OBJECTS_PER_IMAGE = 2, 4, 10
LABELS = ["vesicle", "mitochondrion", "membrane", "endosome", "debris"]


def make_image(seed: int, filename: str) -> list:
    rng = random.Random(seed)
    img = Image.new("L", (W, H), 60)
    d = ImageDraw.Draw(img)
    for _ in range(4000):                                  # grainy background
        d.point((rng.randrange(W), rng.randrange(H)), fill=rng.randrange(40, 90))
    anns, placed = [], []
    while len(anns) < OBJECTS_PER_IMAGE:
        r = rng.randint(24, 46)
        x, y = rng.randint(r + 10, W - r - 10), rng.randint(r + 10, H - r - 10)
        if any((x - px) ** 2 + (y - py) ** 2 < (r + pr + 12) ** 2 for px, py, pr in placed):
            continue
        placed.append((x, y, r))
        d.ellipse((x - r, y - r, x + r, y + r), fill=150, outline=210, width=3)
        d.ellipse((x - r // 2, y - r // 2, x + r // 2, y + r // 2), fill=110)
        anns.append({"id": len(anns) + 1, "label": rng.choice(LABELS),
                     "confidence": round(rng.uniform(0.4, 0.99), 2),
                     "bbox": [x - r - 4, y - r - 4, 2 * r + 8, 2 * r + 8],
                     "status": "pending"})
    img.filter(ImageFilter.GaussianBlur(0.8)).save(DATA / filename)
    return anns


images = []
for n in range(BLOCKS * IMAGES_PER_BLOCK):
    fname = f"sample_image_{n + 1:02d}.png"
    images.append({"id": n + 1, "block": n // IMAGES_PER_BLOCK + 1, "file": fname,
                   "annotations": make_image(100 + n, fname)})

(DATA / "annotations.json").write_text(json.dumps(
    {"player": {"xp": 0}, "images": images}, indent=2))
print(f"wrote {len(images)} images in {BLOCKS} blocks to {DATA}")
