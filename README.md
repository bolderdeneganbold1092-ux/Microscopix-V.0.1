# Microscopix – MVP

*Review AI-annotated vesicle images: **accept** correct predictions, **flag** wrong ones for
correction, **correct** or **delete** them, earn XP, fill the progress bars, level up and
work through blocks of images.*

## Overview

**Microscopix** is a desktop application that transforms the process of reviewing AI-generated microscopy annotations into an interactive and engaging game experience.

Researchers in biological and chemical laboratories often need to review thousands of microscopy images containing tiny structures, such as vesicles, and identify or verify them individually. This process can be repetitive, time-consuming, and demanding.

Microscopix aims to make this process more convenient and engaging by combining scientific image annotation with game mechanics. Instead of reviewing large amounts of data at once, users work through smaller tasks, receive immediate visual feedback, track their progress, and earn rewards as they complete annotation reviews.

This repository contains the initial Minimum Viable Product (MVP) of Microscopix, providing a first implementation of its core features and workflow.

## 🚀 Getting Started

Follow these instructions to set up and run the project locally.

### Prerequisites

Before starting, make sure you have:

- Python installed.
- Visual Studio Code or another Python-compatible IDE.
- Git (if working with the shared repository).

The application requires PySide6.
### Run
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
