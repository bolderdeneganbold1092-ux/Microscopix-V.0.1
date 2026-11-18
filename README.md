# Flag and Frame – MVP

Review AI-annotated vesicle images: **accept** correct predictions, **flag** wrong ones for
correction, **correct** or **delete** them, earn XP, fill the progress bars, level up and
work through blocks of images.

## Run
```bash
python -m venv .venv && source .venv/bin/activate
python -m pip install -r requirements.txt
python main.py
```
Controls: **→** accept, **←** flag for correction, **Enter** next image/block,
click a box to jump to that object. Progress and XP are saved to `data/annotations.json`
after every action (Reset clears them). Mock data can be regenerated with
`python tools/make_sample_data.py` (needs Pillow).

## XP rules (`backend/game_logic.py` → `XP_REWARDS`)
| Action | XP |
|---|---|
| Accept (confirm an annotation) | 1 |
| Flag for correction | 1 (assumed) |
| Correct an annotation | 2 |
| Delete an incorrect annotation | 1 |
| Finish an image (all objects reviewed) | +5 (assumed) |
| Finish a block (all its images done) | +10 (assumed) |

Level = 1 + XP // 20 (design doc: L2 = 20, L3 = 40, L4 = 60 XP).
A flagged object can still be corrected or deleted later (extra XP); accepted, corrected and
deleted objects are final, so nothing is rewarded twice.

## Layout
- `main.py` – starts the app, registers the backend as `review` for QML
- `backend/annotations.py` – `Annotation`, `ImageData`, `Status` (pure Python)
- `backend/data_manager.py` – load/save `data/annotations.json`
- `backend/game_logic.py` – XP, levels, progress, review actions (no Qt)
- `backend/controller.py` – Qt bridge: properties, signals and slots for QML
- `frontend/Main.qml` + `components/` – `ImageViewer`, `AnnotationInfo`, `XPDisplay`, `ReviewButtons`
- `data/` – sample images and `annotations.json`

## Tests
```bash
python tests/test_game_logic.py
```
