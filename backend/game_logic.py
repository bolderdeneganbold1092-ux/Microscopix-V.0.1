"""XP rules, levels, review progress and image/block progression. No GUI code."""
from dataclasses import dataclass

from .annotations import Status

# 1. XP rewards (from the design doc; * = our assumption)
XP_REWARDS = {
    "accept": 1,           # confirm an annotation         -> 1 XP (doc)
    "correct": 2,          # correct an annotation         -> 2 XP (doc)
    "delete": 1,           # delete incorrect annotation   -> 1 XP (doc)
    "flag": 2,             # flag an annotation              -> 2 XP
    "image_complete": 5,   # * bonus: every annotation of an image reviewed
    "block_complete": 10,  # * bonus: every image of a block finished
}

# Level 1 takes 20 XP. Each following level takes 20 more than the one before it
# (level 2 takes 40, level 3 takes 60, ...).
LEVEL_STEP = 20

# Which review status an action leads to. A FLAGGED object can still be resolved
# later (correct / delete), everything else is final -> no double rewards.
TRANSITIONS = {
    Status.PENDING: {"accept": Status.ACCEPTED, "flag": Status.FLAGGED,
                     "correct": Status.CORRECTED, "delete": Status.DELETED},
    Status.FLAGGED: {"correct": Status.CORRECTED, "delete": Status.DELETED},
}


def level_span(level: int) -> int:
    """XP required to finish this level."""
    return LEVEL_STEP * max(1, level)


def level_for_xp(xp: int) -> int:
    level = 1
    while LEVEL_STEP * level * (level + 1) // 2 <= xp:
        level += 1
    return level


def xp_into_level(xp: int) -> int:
    level = level_for_xp(xp)
    start = LEVEL_STEP * (level - 1) * level // 2
    return xp - start


@dataclass
class ReviewResult:
    ok: bool
    xp_gained: int = 0
    level_up: bool = False
    image_complete: bool = False
    block_complete: bool = False
    game_complete: bool = False


class ReviewSession:
    """All images of the project plus the player's XP. Works on the 'current' image."""

    def __init__(self, images: list, xp: int = 0):
        self.images = images
        self.xp = xp
        self.image_index = self._first_incomplete()      # resume where the player stopped

    def _first_incomplete(self) -> int:
        for i, img in enumerate(self.images):
            if not img.is_complete:
                return i
        return max(0, len(self.images) - 1)

    # ---- current image / progress (3.) ----
    @property
    def image(self):
        return self.images[self.image_index]

    @property
    def annotations(self) -> list:
        return self.image.annotations

    @property
    def total(self) -> int:
        return len(self.annotations)

    @property
    def reviewed(self) -> int:
        return sum(a.status != Status.PENDING for a in self.annotations)

    @property
    def active_count(self) -> int:                 # objects still on the image (not deleted)
        return sum(a.status != Status.DELETED for a in self.annotations)

    @property
    def is_complete(self) -> bool:
        return self.image.is_complete

    @property
    def level(self) -> int:
        return level_for_xp(self.xp)

    # ---- blocks ----
    @property
    def block(self) -> int:
        return self.image.block

    @property
    def block_numbers(self) -> list:
        return sorted({i.block for i in self.images})

    @property
    def block_position(self) -> int:               # "block 2 of 5"
        return self.block_numbers.index(self.block) + 1

    @property
    def block_count(self) -> int:
        return len(self.block_numbers)

    @property
    def block_images(self) -> list:
        return [i for i in self.images if i.block == self.block]

    @property
    def block_done(self) -> int:
        return sum(i.is_complete for i in self.block_images)

    @property
    def block_total(self) -> int:
        return len(self.block_images)

    @property
    def block_complete(self) -> bool:
        return all(i.is_complete for i in self.block_images)

    @property
    def game_complete(self) -> bool:
        return all(i.is_complete for i in self.images)

    # ---- navigation ----
    def next_pending(self, after: int = -1) -> int:
        n = self.total
        for step in range(1, n + 1):
            i = (after + step) % n
            if self.annotations[i].status == Status.PENDING:
                return i
        return -1

    def next_incomplete_index(self) -> int:
        n = len(self.images)
        for step in range(1, n + 1):
            i = (self.image_index + step) % n
            if not self.images[i].is_complete:
                return i
        return -1

    def advance(self) -> bool:
        """Go to the next unfinished image. An image with no boxes can be skipped."""
        if any(a.status == Status.PENDING for a in self.annotations):
            return False
        i = self.next_incomplete_index()
        if i < 0:
            return False
        self.image_index = i
        return True

    # ---- 4. actions ----
    def can(self, index: int, action: str) -> bool:
        return (0 <= index < self.total and
                action in TRANSITIONS.get(self.annotations[index].status, {}))

    def accept(self, index: int) -> ReviewResult:
        return self.act(index, "accept")

    def flag(self, index: int) -> ReviewResult:
        return self.act(index, "flag")

    def correct(self, index: int) -> ReviewResult:
        return self.act(index, "correct")

    def delete(self, index: int) -> ReviewResult:
        return self.act(index, "delete")

    def act(self, index: int, action: str) -> ReviewResult:
        if not self.can(index, action):                # unknown index / already final
            return ReviewResult(False)
        ann = self.annotations[index]
        was_pending = ann.status == Status.PENDING
        old_level = self.level
        ann.status = TRANSITIONS[ann.status][action]   # 5. update review status
        gained = XP_REWARDS[action]
        image_done = block_done = game_done = False
        if was_pending and self.is_complete:           # this was the last pending object
            image_done = True
            gained += XP_REWARDS["image_complete"]
            block_done = self.block_complete
            if block_done:
                gained += XP_REWARDS["block_complete"]
            game_done = self.game_complete
        self.xp += gained                              # 2. XP counter
        return ReviewResult(True, gained, self.level > old_level,
                            image_done, block_done, game_done)

    def reset(self):
        """Put this picture's objects back to not reviewed. Other pictures stay."""
        if not self.annotations or all(a.status == Status.PENDING for a in self.annotations):
            return False
        was_block = self.block_complete
        was_image = self.is_complete
        earned = {Status.ACCEPTED: XP_REWARDS["accept"], Status.FLAGGED: XP_REWARDS["flag"],
                  Status.CORRECTED: XP_REWARDS["flag"] + XP_REWARDS["correct"],
                  Status.DELETED: XP_REWARDS["flag"] + XP_REWARDS["delete"]}
        lost = sum(earned.get(a.status, 0) for a in self.annotations)
        for a in self.annotations:
            a.status = Status.PENDING
        if was_image:
            lost += XP_REWARDS["image_complete"]
        if was_block and not self.block_complete:
            lost += XP_REWARDS["block_complete"]
        self.xp = max(0, self.xp - lost)
        return True
