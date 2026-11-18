import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.annotations import Annotation, ImageData, Status
from backend.game_logic import ReviewSession, level_for_xp


def make(blocks=2, per_block=2, n=3):
    images, k = [], 0
    for b in range(1, blocks + 1):
        for _ in range(per_block):
            k += 1
            anns = [Annotation(i + 1, "vesicle", 0.9, (0, 0, 1, 1)) for i in range(n)]
            images.append(ImageData(k, b, f"img{k}.png", anns))
    return ReviewSession(images)


def finish_image(s):
    return [s.accept(i) for i in range(s.total)][-1]


def test_xp_per_action():                       # doc: confirm 1, correct 2, delete 1
    s = make(n=6)
    assert s.accept(0).xp_gained == 1
    assert s.flag(1).xp_gained == 2
    assert s.correct(2).xp_gained == 2
    assert s.delete(3).xp_gained == 1
    assert s.xp == 6 and s.reviewed == 4 and s.active_count == 5


def test_status_updates():
    s = make()
    s.accept(0); s.flag(1); s.correct(2)
    assert [a.status for a in s.annotations] == [Status.ACCEPTED, Status.FLAGGED, Status.CORRECTED]


def test_no_double_reward():
    s = make(); s.accept(0)
    assert not s.accept(0).ok and not s.flag(0).ok and not s.correct(0).ok and s.xp == 1


def test_flagged_can_be_resolved_once():
    s = make(n=3)
    s.flag(0)
    assert s.can(0, "correct") and not s.can(0, "accept") and not s.can(0, "flag")
    r = s.correct(0)
    assert r.ok and r.xp_gained == 2 and s.xp == 4
    assert not s.correct(0).ok and s.reviewed == 1


def test_resolving_flag_never_gives_image_bonus_twice():
    s = make(blocks=1, per_block=2, n=2)
    s.flag(0)
    last = s.accept(1)                           # image complete: flag 2 + accept 1 + 5
    assert last.image_complete and s.xp == 2 + 6
    r = s.correct(0)
    assert r.xp_gained == 2 and not r.image_complete


def test_levels():
    # level 1 takes 20, level 2 takes 40, level 3 takes 60
    assert level_for_xp(19) == 1 and level_for_xp(20) == 2
    assert level_for_xp(59) == 2 and level_for_xp(60) == 3 and level_for_xp(120) == 4
    s = make(); s.xp = 19
    assert s.accept(0).level_up


def test_image_to_image_and_block_flow():
    s = make(blocks=2, per_block=2, n=3)
    last = finish_image(s)
    assert last.image_complete and not last.block_complete and s.xp == 8
    assert s.advance() and s.image_index == 1 and s.block == 1
    last = finish_image(s)
    assert last.image_complete and last.block_complete and not last.game_complete
    assert s.xp == 8 + 18
    assert s.advance() and s.image_index == 2 and s.block == 2


def test_game_complete_and_no_advance():
    s = make(blocks=1, per_block=2, n=2)
    finish_image(s); s.advance()
    last = finish_image(s)
    assert last.game_complete and s.game_complete and not s.advance()


def test_cannot_advance_before_image_is_done():
    s = make(); s.accept(0)
    assert not s.advance() and s.image_index == 0


def test_resume_at_first_incomplete_image():
    s = make(); finish_image(s)
    assert ReviewSession(s.images, s.xp).image_index == 1


def test_next_pending_wraps():
    s = make(n=3); s.accept(0); s.accept(2)
    assert s.next_pending(2) == 1


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn(); print("ok", name)
