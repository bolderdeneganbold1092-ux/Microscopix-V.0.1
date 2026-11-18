"""Qt bridge: exposes XP, level, progress, selection and review actions to QML as `review`."""
from pathlib import Path

from PySide6.QtCore import (Property, QAbstractListModel, QModelIndex, QObject, Qt,
                            QUrl, Signal, Slot)

from .annotations import Annotation, ImageData, Status, bbox_of, ellipse_points
from .data_manager import DataManager
from .game_logic import XP_REWARDS, ReviewSession, level_span, xp_into_level

STATUS_TEXT = {"pending": "Pending", "accepted": "Accepted", "flagged": "Flagged",
               "corrected": "Corrected", "deleted": "Deleted"}


class AnnotationModel(QAbstractListModel):
    IdRole, LabelRole, ConfRole, StatusRole, XRole, YRole, WRole, HRole, PointsRole = \
        [Qt.UserRole + i for i in range(1, 10)]

    def __init__(self, annotations: list, parent=None):
        super().__init__(parent)
        self._a = annotations

    def set_annotations(self, annotations: list):
        self.beginResetModel()
        self._a = annotations
        self.endResetModel()

    def rowCount(self, parent=QModelIndex()):
        return len(self._a)

    def roleNames(self):
        return {self.IdRole: b"annotationId", self.LabelRole: b"label",
                self.ConfRole: b"confidence", self.StatusRole: b"status",
                self.XRole: b"boxX", self.YRole: b"boxY",
                self.WRole: b"boxW", self.HRole: b"boxH",
                self.PointsRole: b"outline"}

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        a = self._a[index.row()]
        return {self.IdRole: a.id, self.LabelRole: a.label,
                self.ConfRole: a.confidence, self.StatusRole: a.status.value,
                self.XRole: a.bbox[0], self.YRole: a.bbox[1],
                self.WRole: a.bbox[2], self.HRole: a.bbox[3],
                self.PointsRole: [[p[0], p[1]] for p in a.points] if a.points else []}.get(role)

    def refresh_row(self, row: int):
        i = self.index(row)
        self.dataChanged.emit(i, i)


class LibraryModel(QAbstractListModel):
    NameRole, CurrentRole = Qt.UserRole + 1, Qt.UserRole + 2

    def __init__(self, session, parent=None):
        super().__init__(parent)
        self._s = session

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._s.images)

    def roleNames(self):
        return {self.NameRole: b"name", self.CurrentRole: b"current"}

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()
        if role == self.NameRole:
            return self._s.images[row].file
        if role == self.CurrentRole:
            return row == self._s.image_index
        return None

    def refresh(self):
        self.beginResetModel()
        self.endResetModel()


class ReviewController(QObject):
    statsChanged = Signal()       # 6. XP / level / progress / block state changed
    currentChanged = Signal()     # selected annotation or its status changed
    imageChanged = Signal()       # a different image is shown
    xpGained = Signal(int)
    levelUp = Signal(int)
    imageCompleted = Signal()
    blockCompleted = Signal(int)
    fixChanged = Signal()

    def __init__(self, data_manager: DataManager):
        super().__init__()
        self._dm = data_manager
        images, xp = data_manager.load()
        self._s = ReviewSession(images, xp)
        self._model = AnnotationModel(self._s.annotations, self)
        self._library = LibraryModel(self._s, self)
        self._current = self._s.next_pending()
        self._fix_total = 0
        self._fix_done = 0
        self._undo = []
        self._redo = []

    # ---- player ----
    @Property(int, notify=statsChanged)
    def xp(self): return self._s.xp

    @Property(int, notify=statsChanged)
    def level(self): return self._s.level

    @Property(int, notify=statsChanged)
    def xpIntoLevel(self): return xp_into_level(self._s.xp)

    @Property(int, notify=statsChanged)
    def xpPerLevel(self): return level_span(self._s.level)

    @Slot(str, result=int)
    def reward(self, action):                    # review.reward("accept") -> 1
        return XP_REWARDS.get(action, 0)

    # ---- progress ----
    @Property(int, notify=statsChanged)
    def reviewed(self): return self._s.reviewed

    @Property(int, notify=statsChanged)
    def total(self): return self._s.total

    @Property(str, notify=statsChanged)
    def progressText(self):
        return f"{self._s.reviewed}/{self._s.total} objects reviewed"

    @Property(int, notify=statsChanged)
    def blockDone(self): return self._s.block_done

    @Property(int, notify=statsChanged)
    def blockTotal(self): return self._s.block_total

    @Property(str, notify=statsChanged)
    def blockText(self):
        s = self._s
        return (f"Block {s.block_position}/{s.block_count}  ·  "
                f"{s.block_done}/{s.block_total} images done")

    @Property(bool, notify=statsChanged)
    def imageComplete(self): return self._s.is_complete

    @Property(bool, notify=statsChanged)
    def gameComplete(self): return self._s.game_complete

    @Property(bool, notify=statsChanged)
    def canAdvance(self):
        pending = any(a.status == Status.PENDING for a in self._s.annotations)
        return not pending and not self.fixing and not self._s.game_complete

    @Property(str, notify=statsChanged)
    def completeText(self):
        s = self._s
        if s.game_complete:
            return "All images complete!\nGreat work."
        return "Image complete!\nAll annotations reviewed."

    @Property(str, notify=statsChanged)
    def nextText(self):
        return "Next image  →"

    # ---- flagged crops, shown before the next image ----
    def _flagged(self):
        return [a for a in self._s.annotations if a.status == Status.FLAGGED]

    def _prepare_fix(self):
        n = len(self._flagged())
        if self._s.is_complete and n and self._fix_total == 0:
            self._fix_total = n
            self._fix_done = 0

    @Property(bool, notify=fixChanged)
    def fixing(self):
        self._prepare_fix()
        return self._s.is_complete and bool(self._flagged())

    @Property(str, notify=fixChanged)
    def fixLabel(self):
        flagged = self._flagged()
        return flagged[0].label if flagged else ""

    @Property(str, notify=fixChanged)
    def fixProgress(self):
        if not self.fixing or not self._fix_total:
            return ""
        return f"{self._fix_done + 1} OF {self._fix_total}"

    @Property(QUrl, notify=fixChanged)
    def cropUrl(self):
        flagged = self._flagged()
        if not self._s.is_complete or not flagged:
            return QUrl()
        return QUrl.fromLocalFile(str(self._dm.write_crop(self._s.image, flagged[0]).resolve()))

    @Slot(str)
    def renameFlagged(self, name):
        flagged = self._flagged()
        name = name.strip()
        if not flagged or not name:
            return
        self._remember()
        flagged[0].label = name
        idx = self._s.annotations.index(flagged[0])
        res = self._s.correct(idx)                 # rename -> 2 XP
        if res.ok:
            self._finish_flagged(res)

    @Slot()
    def deleteFlagged(self):
        flagged = self._flagged()
        if not flagged:
            return
        self._remember()
        idx = self._s.annotations.index(flagged[0])
        res = self._s.delete(idx)                  # delete -> 1 XP
        if res.ok:
            self._finish_flagged(res)

    def _finish_flagged(self, res):
        self._fix_done += 1
        if not self._flagged():
            self._fix_total = 0
            self._fix_done = 0
        self._dm.save(self._s.images, self._s.xp)
        self._model.set_annotations(self._s.annotations)
        self.statsChanged.emit()
        self.currentChanged.emit()
        self.fixChanged.emit()
        if res.xp_gained:
            self.xpGained.emit(res.xp_gained)
        if res.level_up:
            self.levelUp.emit(self._s.level)

    # ---- image + markers ----
    @Property(QObject, constant=True)
    def model(self): return self._model

    @Property(QObject, constant=True)
    def library(self): return self._library

    @Property(int, notify=imageChanged)
    def imageIndex(self): return self._s.image_index

    @Property(QUrl, notify=imageChanged)
    def imageUrl(self):
        return QUrl.fromLocalFile(str(self._dm.image_path(self._s.image).resolve()))

    # ---- selected annotation ----
    def _sel(self):
        return self._s.annotations[self._current] if 0 <= self._current < self._s.total else None

    @Property(int, notify=currentChanged)
    def currentIndex(self): return self._current

    @Property(str, notify=currentChanged)
    def currentId(self):
        a = self._sel(); return str(a.id) if a else ""

    @Property(str, notify=currentChanged)
    def currentLabel(self):
        a = self._sel(); return a.label if a else ""

    @Property(float, notify=currentChanged)
    def currentConfidence(self):
        a = self._sel(); return a.confidence if a else 0.0

    @Property(int, notify=currentChanged)
    def currentX(self):
        a = self._sel(); return int(a.bbox[0]) if a else 0

    @Property(int, notify=currentChanged)
    def currentY(self):
        a = self._sel(); return int(a.bbox[1]) if a else 0

    @Property(int, notify=currentChanged)
    def currentWidth(self):
        a = self._sel(); return int(a.bbox[2]) if a else 0

    @Property(int, notify=currentChanged)
    def currentHeight(self):
        a = self._sel(); return int(a.bbox[3]) if a else 0

    @Property(int, notify=currentChanged)
    def currentCount(self):
        """How many objects of the selected label are still on this image."""
        a = self._sel()
        if not a:
            return 0
        return sum(1 for ann in self._s.annotations
                   if ann.label == a.label and ann.status != Status.DELETED)

    @Property(str, notify=currentChanged)
    def currentStatusKey(self):
        a = self._sel(); return a.status.value if a else "pending"

    @Property(str, notify=currentChanged)
    def currentStatus(self): return STATUS_TEXT[self.currentStatusKey]

    @Property(bool, notify=currentChanged)
    def canReview(self):          # Accept / Flag: selected object is still pending
        return self._s.can(self._current, "accept")

    @Property(bool, notify=currentChanged)
    def canResolve(self):         # Correct / Delete: pending or flagged
        return self._s.can(self._current, "correct")

    # ---- slots called from QML ----
    @Slot()
    def accept(self): self._review("accept")

    @Slot()
    def flag(self): self._review("flag")

    @Slot()
    def correct(self): self._review("correct")

    @Slot()
    def deleteCurrent(self): self._review("delete")

    @Slot(float, float, float, float)
    def addBox(self, x, y, w, h):
        """A missed object: the player draws a new outline."""
        if self.fixing or w < 4 or h < 4:
            return
        self._remember()
        anns = self._s.annotations
        new_id = max((a.id for a in anns), default=0) + 1
        pts = ellipse_points(float(x), float(y), float(w), float(h))
        anns.append(Annotation(new_id, "unknown", 0.0, bbox_of(pts), points=pts))
        self._current = len(anns) - 1
        self._fix_total = 0
        self._fix_done = 0
        self._dm.save(self._s.images, self._s.xp)
        self._model.set_annotations(anns)
        self.statsChanged.emit()
        self.currentChanged.emit()
        self.fixChanged.emit()

    @Slot(int, "QVariant")
    def setOutline(self, row, points):
        """Move the whole outline, or one of its points, and store the new form."""
        if not (0 <= row < self._s.total):
            return
        ann = self._s.annotations[row]
        if ann.status == Status.DELETED:
            return
        try:
            raw = points.toVariant() if hasattr(points, "toVariant") else points
            pts = []
            for p in raw:
                if hasattr(p, "toVariant"):
                    p = p.toVariant()
                pts.append((float(p[0]), float(p[1])))
        except (TypeError, ValueError, IndexError):
            return
        if len(pts) < 3:
            return
        box = bbox_of(pts)
        if box[2] < 4 or box[3] < 4:
            return
        self._remember()
        ann.points = pts
        ann.bbox = box
        self._dm.save(self._s.images, self._s.xp)
        self._model.refresh_row(row)
        self.currentChanged.emit()

    @Slot(int, float, float, float, float)
    def setBox(self, row, x, y, w, h):
        if not (0 <= row < self._s.total) or w < 4 or h < 4:
            return
        ann = self._s.annotations[row]
        if ann.status == Status.DELETED:
            return
        self._remember()
        ann.bbox = (float(x), float(y), float(w), float(h))
        ann.points = None
        self._dm.save(self._s.images, self._s.xp)
        self._model.refresh_row(row)
        self.currentChanged.emit()

    @Slot(int)
    def select(self, row):
        if 0 <= row < self._s.total and self._s.annotations[row].status != Status.DELETED:
            self._current = row
            self.currentChanged.emit()

    @Slot(str)
    def addTiff(self, url):
        """Copy a TIFF into the library and open it."""
        src = Path(QUrl(url).toLocalFile() or url)
        if src.suffix.lower() not in {".tif", ".tiff"} or not src.is_file():
            return
        folder = self._dm.path.parent
        for i, img in enumerate(self._s.images):
            try:
                if (folder / img.file).resolve() == src.resolve():
                    self.openImage(i)
                    return
            except OSError:
                continue
        try:
            name = self._dm.import_tiff(src)
        except (OSError, ValueError):
            return
        self._remember()
        new_id = max((img.id for img in self._s.images), default=0) + 1
        block = self._s.block if self._s.images else 1
        self._s.images.append(ImageData(new_id, block, name, []))
        self._s.image_index = len(self._s.images) - 1
        self._dm.save(self._s.images, self._s.xp)
        self._show_current_image()

    @Slot()
    def deleteImage(self):
        """Remove the selected picture from the library."""
        images = self._s.images
        if len(images) <= 1:
            return
        self._remember()
        idx = self._s.image_index
        del images[idx]
        if idx >= len(images):
            self._s.image_index = len(images) - 1
        self._dm.save(self._s.images, self._s.xp)
        self._show_current_image()

    @Slot(int)
    def openImage(self, index):
        if not (0 <= index < len(self._s.images)) or index == self._s.image_index:
            return
        self._s.image_index = index
        self._show_current_image()

    @Slot()
    def nextImage(self):
        if self.fixing:
            return
        if self._s.advance():
            self._show_current_image()

    @Slot()
    def reset(self):
        if not any(a.status != Status.PENDING for a in self._s.annotations):
            return
        self._remember()
        self._s.reset()
        self._dm.save(self._s.images, self._s.xp)
        self._show_current_image()

    @Slot()
    def undo(self):
        if not self._undo:
            return
        self._redo.append(self._capture())
        self._restore(self._undo.pop())

    @Slot()
    def redo(self):
        if not self._redo:
            return
        self._undo.append(self._capture())
        self._restore(self._redo.pop())

    # ---- internals ----
    def _show_current_image(self):
        self._model.set_annotations(self._s.annotations)
        nxt = self._s.next_pending()
        self._current = nxt if nxt >= 0 else 0
        self._fix_total = 0
        self._fix_done = 0
        self._library.refresh()
        self.imageChanged.emit()
        self.statsChanged.emit()
        self.currentChanged.emit()
        self.fixChanged.emit()

    def _review(self, action):
        if not self._s.can(self._current, action):
            return
        self._remember()
        self._apply(action)

    def _capture(self):
        return {"images": [i.to_dict() for i in self._s.images], "xp": self._s.xp,
                "image_index": self._s.image_index, "current": self._current,
                "fix_total": self._fix_total, "fix_done": self._fix_done}

    def _remember(self):
        self._undo.append(self._capture())
        if len(self._undo) > 40:
            del self._undo[0]
        self._redo.clear()

    def _restore(self, snap):
        self._s.images = [ImageData.from_dict(d) for d in snap["images"]]
        self._s.xp = snap["xp"]
        last = max(0, len(self._s.images) - 1)
        self._s.image_index = min(max(0, snap["image_index"]), last)
        self._fix_total = snap["fix_total"]
        self._fix_done = snap["fix_done"]
        self._dm.save(self._s.images, self._s.xp)
        self._model.set_annotations(self._s.annotations)
        cur = snap["current"]
        if not (0 <= cur < self._s.total):
            cur = self._s.next_pending()
            if cur < 0:
                cur = 0
        self._current = cur
        self._library.refresh()
        self.imageChanged.emit()
        self.statsChanged.emit()
        self.currentChanged.emit()
        self.fixChanged.emit()

    def _apply(self, action):
        row = self._current
        res = self._s.act(row, action)
        if not res.ok:
            return
        self._dm.save(self._s.images, self._s.xp)          # automatic saving
        self._model.refresh_row(row)
        nxt = self._s.next_pending(row)                    # jump to the next open object
        if nxt >= 0:
            self._current = nxt
        self.statsChanged.emit()                           # 6. push XP / progress to QML
        self.currentChanged.emit()
        self.xpGained.emit(res.xp_gained)
        if res.level_up:
            self.levelUp.emit(self._s.level)
        if res.image_complete:
            self._prepare_fix()
            self.imageCompleted.emit()
        self.fixChanged.emit()
        if res.block_complete:
            self.blockCompleted.emit(self._s.block_position)
