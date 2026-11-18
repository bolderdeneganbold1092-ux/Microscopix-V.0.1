"""Annotation, ImageData and review status (pure Python, no Qt)."""
import math
from dataclasses import dataclass
from enum import Enum

POINT_COUNT = 12


class Status(str, Enum):
    PENDING = "pending"      # not yet reviewed
    ACCEPTED = "accepted"    # swipe right: AI prediction confirmed
    FLAGGED = "flagged"      # swipe left: goes to Correction/Identification queue
    CORRECTED = "corrected"  # fixed later at the Correction Station
    DELETED = "deleted"      # incorrect annotation removed


@dataclass
class Annotation:
    id: int
    label: str
    confidence: float
    bbox: tuple              # (x, y, w, h) in image pixels
    status: Status = Status.PENDING
    points: list = None      # outline vertices in image pixels; None keeps the rectangle

    @classmethod
    def from_dict(cls, d: dict) -> "Annotation":
        raw = d.get("points")
        points = [tuple(p) for p in raw] if raw else None
        return cls(d["id"], d["label"], float(d["confidence"]), tuple(d["bbox"]),
                   Status(d.get("status", "pending")), points)

    def to_dict(self) -> dict:
        data = {"id": self.id, "label": self.label, "confidence": self.confidence,
                "bbox": list(self.bbox), "status": self.status.value}
        if self.points:
            data["points"] = [[round(p[0], 2), round(p[1], 2)] for p in self.points]
        return data


@dataclass
class ImageData:
    id: int
    block: int               # images are organised in blocks (design doc: ~40 per block)
    file: str
    annotations: list

    @property
    def is_complete(self) -> bool:
        # doc: an image is complete only once ALL its annotations are reviewed
        return bool(self.annotations) and all(a.status != Status.PENDING
                                              for a in self.annotations)

    @classmethod
    def from_dict(cls, d: dict) -> "ImageData":
        return cls(d["id"], d["block"], d["file"],
                   [Annotation.from_dict(a) for a in d["annotations"]])

    def to_dict(self) -> dict:
        return {"id": self.id, "block": self.block, "file": self.file,
                "annotations": [a.to_dict() for a in self.annotations]}


def ellipse_points(x, y, w, h, n=POINT_COUNT):
    """Points around the ellipse that fills a dragged rectangle. Index 0 is the top."""
    cx, cy = x + w / 2.0, y + h / 2.0
    rx, ry = w / 2.0, h / 2.0
    pts = []
    for i in range(n):
        angle = -math.pi / 2 + (2 * math.pi * i) / n
        pts.append((cx + rx * math.cos(angle), cy + ry * math.sin(angle)))
    return pts


def ring_points(x, y, w, h, n=POINT_COUNT):
    """The same count of points, laid on the rectangle so an old box stays square."""
    side = max(1, n // 4)
    pts = []
    for i in range(side):
        pts.append((x + w * i / side, y))
    for i in range(side):
        pts.append((x + w, y + h * i / side))
    for i in range(side):
        pts.append((x + w * (side - i) / side, y + h))
    for i in range(side):
        pts.append((x, y + h * (side - i) / side))
    return pts


def bbox_of(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    x, y = min(xs), min(ys)
    return (x, y, max(xs) - x, max(ys) - y)
