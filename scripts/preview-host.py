#!/usr/bin/env python3
"""
preview-host.py - PyQt6 host for the SDDM theme preview with hot reload.

Replaces `qml6 preview/Preview.qml` as the QML host process. Watches all
theme files for changes and calls engine.clearComponentCache() before
triggering a reload, so edits to any QML component are picked up immediately
without restarting the window.
"""

import os
import sys
import glob

from PyQt6.QtCore import (
    QFileSystemWatcher,
    QObject,
    QTimer,
    QUrl,
    pyqtProperty,
    pyqtSignal,
)
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine


class HotReloader(QObject):
    """Exposed to QML as `hotReloader` — provides a reload generation counter.

    Reload is a 3-phase process:
      1. Signal QML to unload the Loader (destroy all component instances)
      2. After a tick, clear the now-unreferenced component cache
      3. Signal QML to reload the Loader from disk
    This ordering is required because clearComponentCache() skips
    components that still have live instances.
    """

    # Phase 1: tells QML to unload the Loader
    unloadRequested = pyqtSignal()
    # Phase 3: tells QML to reload the Loader
    reloadRequested = pyqtSignal()

    reloadGenerationChanged = pyqtSignal()

    def __init__(self, engine: QQmlApplicationEngine, watch_dirs: list[str]):
        super().__init__()
        self._engine = engine
        self._generation = 0
        self._watcher = QFileSystemWatcher()

        # Debounce rapid saves (e.g. editor write + rename)
        self._debounce = QTimer()
        self._debounce.setSingleShot(True)
        self._debounce.setInterval(150)
        self._debounce.timeout.connect(self._phase1_unload)

        # Timer for phase 2 (clear cache after unload has been processed)
        self._clear_timer = QTimer()
        self._clear_timer.setSingleShot(True)
        self._clear_timer.setInterval(50)
        self._clear_timer.timeout.connect(self._phase2_clear_and_reload)

        self._watch_dirs = watch_dirs
        self._populate_watches()

        self._watcher.fileChanged.connect(self._on_change)
        self._watcher.directoryChanged.connect(self._on_dir_change)

    @pyqtProperty(int, notify=reloadGenerationChanged)
    def reloadGeneration(self) -> int:
        return self._generation

    # ── Private ────────────────────────────────────────────────────

    def _populate_watches(self):
        """Watch all QML, conf, and image files plus their directories."""
        extensions = ("*.qml", "*.conf", "*.jpg", "*.png", "*.svg")
        for d in self._watch_dirs:
            if os.path.isdir(d):
                self._watcher.addPath(d)
            for ext in extensions:
                for path in glob.glob(os.path.join(d, "**", ext), recursive=True):
                    self._watcher.addPath(path)

    def _on_change(self, path: str):
        """A watched file changed — start/restart the debounce timer."""
        if os.path.exists(path):
            self._watcher.addPath(path)
        self._debounce.start()

    def _on_dir_change(self, path: str):
        """A watched directory changed — re-scan for new files and reload."""
        self._populate_watches()
        self._debounce.start()

    def _phase1_unload(self):
        """Phase 1: tell QML to destroy all loaded components."""
        self.unloadRequested.emit()
        # Give QML one event-loop tick to process the unload
        self._clear_timer.start()

    def _phase2_clear_and_reload(self):
        """Phase 2+3: clear the (now unreferenced) cache, then reload."""
        self._engine.clearComponentCache()
        self._generation += 1
        self.reloadGenerationChanged.emit()
        self.reloadRequested.emit()
        print(f"[hot-reload] Reloading (gen {self._generation})")


def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    os.environ["QML_DISABLE_DISK_CACHE"] = "1"

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    # Resolve the preview directory (this script lives in scripts/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    preview_dir = os.path.join(project_dir, "preview")

    # Directories to watch: the preview dir (includes symlinked components/assets)
    # and the themes dir for direct edits
    watch_dirs = [
        preview_dir,
        os.path.join(preview_dir, "components"),
        os.path.join(preview_dir, "assets"),
    ]

    reloader = HotReloader(engine, watch_dirs)
    engine.rootContext().setContextProperty("hotReloader", reloader)

    qml_path = os.path.join(preview_dir, "Preview.qml")
    engine.load(QUrl.fromLocalFile(qml_path))

    if not engine.rootObjects():
        print("Error: failed to load Preview.qml", file=sys.stderr)
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
