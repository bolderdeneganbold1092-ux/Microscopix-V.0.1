import sys
from pathlib import Path

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from backend.controller import ReviewController
from backend.data_manager import DataManager

ROOT = Path(__file__).parent

if __name__ == "__main__":
    QQuickStyle.setStyle("Fusion")
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    controller = ReviewController(DataManager(ROOT / "data" / "annotations.json"))
    engine.rootContext().setContextProperty("review", controller)   # 7. connect to UI
    engine.load(ROOT / "frontend" / "Main.qml")
    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())
