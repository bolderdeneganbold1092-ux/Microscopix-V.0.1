"""Loads and saves annotations.json (images, annotations, review status, player XP)."""
import json
import os
import shutil
from pathlib import Path

from PIL import Image

from .annotations import ImageData


class DataManager:
    def __init__(self, json_path: Path):
        self.path = Path(json_path)

    def load(self):
        """Returns (images, xp)."""
        with open(self.path, encoding="utf-8") as f:
            raw = json.load(f)
        images = [ImageData.from_dict(d) for d in raw["images"]]
        return images, int(raw.get("player", {}).get("xp", 0))

    def image_path(self, image: ImageData) -> Path:
        src = self.path.parent / image.file
        if src.suffix.lower() not in {".tif", ".tiff"}:
            return src
        with Image.open(src) as im:
            # 8-bit photos display as-is. 16-bit microscopy files need a preview.
            if im.mode in ("1", "L", "LA", "P", "RGB", "RGBA"):
                return src
        preview = self.path.parent / ".preview" / f"{src.stem}.png"
        if not preview.exists() or preview.stat().st_mtime < src.stat().st_mtime:
            preview.parent.mkdir(exist_ok=True)
            self._write_preview(src, preview)
        return preview

    @staticmethod
    def _write_preview(src: Path, dest: Path):
        im = Image.open(src)
        im.seek(0)
        gray = im.convert("I")
        lo, hi = (int(v) for v in gray.getextrema())
        span = max(hi - lo, 1)
        src_px = gray.load()
        out = Image.new("L", gray.size)
        out_px = out.load()
        width, height = gray.size
        for y in range(height):
            for x in range(width):
                out_px[x, y] = max(0, min(255, (src_px[x, y] - lo) * 255 // span))
        out.save(dest)

    def write_crop(self, image: ImageData, ann) -> Path:
        """Crop one object out of the picture the viewer is showing."""
        src = self.image_path(image)
        folder = self.path.parent / ".preview" / "crops"
        folder.mkdir(parents=True, exist_ok=True)
        dest = folder / f"{image.id}_{ann.id}.png"
        with Image.open(src) as im:
            rgb = im.convert("RGB")
            x, y, w, h = (int(v) for v in ann.bbox)
            x1 = max(0, min(rgb.width - 1, x))
            y1 = max(0, min(rgb.height - 1, y))
            x2 = max(x1 + 1, min(rgb.width, x + max(w, 1)))
            y2 = max(y1 + 1, min(rgb.height, y + max(h, 1)))
            rgb.crop((x1, y1, x2, y2)).save(dest)
        return dest

    def import_tiff(self, src: Path) -> str:
        """Copy a TIFF into the data folder. Returns the stored file name."""
        src = Path(src)
        if src.suffix.lower() not in {".tif", ".tiff"} or not src.is_file():
            raise ValueError("not a tiff")
        dest_dir = self.path.parent
        if src.parent.resolve() == dest_dir.resolve():
            return src.name
        dest = dest_dir / src.name
        if dest.exists():
            n = 2
            while True:
                candidate = dest_dir / f"{src.stem}-{n}{src.suffix}"
                if not candidate.exists():
                    dest = candidate
                    break
                n += 1
        shutil.copy2(src, dest)
        return dest.name

    def save(self, images, xp: int):
        """Automatic saving: write a temp file, then replace it (never half-written)."""
        raw = {"player": {"xp": xp}, "images": [i.to_dict() for i in images]}
        tmp = self.path.with_suffix(".tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(raw, f, indent=2)
        os.replace(tmp, self.path)
