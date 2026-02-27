#!/usr/bin/env python3
"""
preview-host.py - PyQt6 host for the SDDM theme preview with hot reload.

Injects mock SDDM context properties (sddm, config, userModel, sessionModel,
keyboard) so that the theme's Main.qml can be loaded directly — the same way
the real SDDM greeter does it.  File watching + cache clearing gives true
live-preview without restarting the window.

Usage:  preview-host.py <theme-dir>
"""

import configparser
import os
import sys
import glob

from PyQt6.QtCore import (
    QAbstractListModel,
    QFileSystemWatcher,
    QModelIndex,
    QObject,
    Qt,
    QTimer,
    QUrl,
    pyqtProperty,
    pyqtSignal,
    pyqtSlot,
)
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine


# ═══════════════════════════════════════════════════════════════════
#  Mock SDDM context objects
# ═══════════════════════════════════════════════════════════════════

class MockSddm(QObject):
    """Mimics the `sddm` context property injected by the real SDDM greeter."""

    loginFailed = pyqtSignal()
    loginSucceeded = pyqtSignal()

    @pyqtProperty(str, constant=True)
    def hostname(self):
        return "preview-host"

    @pyqtProperty(bool, constant=True)
    def canPowerOff(self):
        return True

    @pyqtProperty(bool, constant=True)
    def canReboot(self):
        return True

    @pyqtProperty(bool, constant=True)
    def canSuspend(self):
        return True

    @pyqtProperty(bool, constant=True)
    def canHibernate(self):
        return True

    @pyqtProperty(bool, constant=True)
    def canHybridSleep(self):
        return False

    @pyqtSlot(str, str, int)
    def login(self, user, password, session_index):
        print(f"[mock] sddm.login: {user} session: {session_index}")
        if password == "test":
            print("[mock] Login succeeded")
            self.loginSucceeded.emit()
        else:
            print("[mock] Login failed (use 'test' as password)")
            self.loginFailed.emit()

    @pyqtSlot()
    def powerOff(self):
        print("[mock] sddm.powerOff()")

    @pyqtSlot()
    def reboot(self):
        print("[mock] sddm.reboot()")

    @pyqtSlot()
    def suspend(self):
        print("[mock] sddm.suspend()")

    @pyqtSlot()
    def hibernate(self):
        print("[mock] sddm.hibernate()")

    @pyqtSlot()
    def hybridSleep(self):
        print("[mock] sddm.hybridSleep()")


class MockConfig(QObject):
    """Mimics the `config` context property — values read from theme.conf.

    screenWidth / screenHeight are writable so Preview.qml can bind them
    to the window dimensions, matching what SDDM does at runtime.
    """

    screenWidthChanged = pyqtSignal()
    screenHeightChanged = pyqtSignal()

    def __init__(self, theme_dir: str):
        super().__init__()
        self._screen_width = 1920
        self._screen_height = 1080

        # Ensure absolute path for reliable file:// URL generation
        theme_dir = os.path.abspath(theme_dir)

        # Read [General] section from theme.conf
        self._values: dict[str, str] = {}
        conf_path = os.path.join(theme_dir, "theme.conf")
        if os.path.isfile(conf_path):
            cp = configparser.ConfigParser()
            cp.read(conf_path)
            if cp.has_section("General"):
                self._values = dict(cp.items("General"))

        # Seed screen dimensions from theme.conf (overridden by window binding)
        sw = self._values.get("screenwidth", "")
        sh = self._values.get("screenheight", "")
        if sw:
            self._screen_width = int(sw)
        if sh:
            self._screen_height = int(sh)

        # Resolve background path to a file:// URL
        bg = self._values.get("background", "")
        if bg and not bg.startswith("file://") and not os.path.isabs(bg):
            abs_bg = os.path.join(theme_dir, bg)
            self._values["background"] = QUrl.fromLocalFile(abs_bg).toString()

    def _get(self, key: str, default: str = "") -> str:
        return self._values.get(key, default)

    # ── Dynamic screen dimensions (bound to window size by Preview.qml) ──

    def _get_screen_width(self):
        return self._screen_width

    def _set_screen_width(self, val):
        if self._screen_width != val:
            self._screen_width = val
            self.screenWidthChanged.emit()

    screenWidth = pyqtProperty(
        int, fget=_get_screen_width, fset=_set_screen_width,
        notify=screenWidthChanged,
    )

    def _get_screen_height(self):
        return self._screen_height

    def _set_screen_height(self, val):
        if self._screen_height != val:
            self._screen_height = val
            self.screenHeightChanged.emit()

    screenHeight = pyqtProperty(
        int, fget=_get_screen_height, fset=_set_screen_height,
        notify=screenHeightChanged,
    )

    # ── Static theme config values (read from theme.conf) ────────────

    # configparser lowercases keys, so "primaryColor" → "primarycolor"

    @pyqtProperty(str, constant=True)
    def background(self):
        return self._get("background")

    @pyqtProperty(str, constant=True)
    def color(self):
        return self._get("color", "#1a1a2e")

    @pyqtProperty(str, constant=True)
    def primaryColor(self):
        return self._get("primarycolor", "#ffffff")

    @pyqtProperty(str, constant=True)
    def accentColor(self):
        return self._get("accentcolor", "#4a9eff")

    @pyqtProperty(str, constant=True)
    def backgroundOverlayColor(self):
        return self._get("backgroundoverlaycolor", "#000000")

    @pyqtProperty(str, constant=True)
    def backgroundOverlayOpacity(self):
        return self._get("backgroundoverlayopacity", "0.3")

    @pyqtProperty(str, constant=True)
    def fontFamily(self):
        return self._get("fontfamily", "")

    @pyqtProperty(str, constant=True)
    def fontPointSize(self):
        return self._get("fontpointsize", "12")

    @pyqtProperty(str, constant=True)
    def clockVisible(self):
        return self._get("clockvisible", "true")

    @pyqtProperty(str, constant=True)
    def clockFormat(self):
        return self._get("clockformat", "hh:mm")

    @pyqtProperty(str, constant=True)
    def dateFormat(self):
        return self._get("dateformat", "dddd, MMMM d")


class MockUserModel(QAbstractListModel):
    """Mimics SDDM's userModel — a list model with user metadata."""

    _NameRole = Qt.ItemDataRole.UserRole + 1
    _RealNameRole = Qt.ItemDataRole.UserRole + 2
    _IconRole = Qt.ItemDataRole.UserRole + 3
    _NeedsPasswordRole = Qt.ItemDataRole.UserRole + 4

    def __init__(self):
        super().__init__()
        self._users = [
            {"name": "user", "realName": "User", "icon": "", "needsPassword": True},
            {"name": "guest", "realName": "Guest User", "icon": "", "needsPassword": True},
        ]

    @pyqtProperty(str, constant=True)
    def lastUser(self):
        return "user"

    @pyqtProperty(int, constant=True)
    def lastIndex(self):
        return 0

    @pyqtProperty(int, constant=True)
    def disableAvatarsThreshold(self):
        return 7

    @pyqtProperty(bool, constant=True)
    def containsAllUsers(self):
        return True

    def rowCount(self, parent=QModelIndex()):
        return len(self._users)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or index.row() >= len(self._users):
            return None
        user = self._users[index.row()]
        role_map = {
            self._NameRole: "name",
            self._RealNameRole: "realName",
            self._IconRole: "icon",
            self._NeedsPasswordRole: "needsPassword",
        }
        return user.get(role_map.get(role))

    def roleNames(self):
        return {
            self._NameRole: b"name",
            self._RealNameRole: b"realName",
            self._IconRole: b"icon",
            self._NeedsPasswordRole: b"needsPassword",
        }


class MockSessionModel(QAbstractListModel):
    """Mimics SDDM's sessionModel — a list model of desktop sessions."""

    _NameRole = Qt.ItemDataRole.UserRole + 1
    _CommentRole = Qt.ItemDataRole.UserRole + 2

    def __init__(self):
        super().__init__()
        self._sessions = [
            {"name": "Plasma (Wayland)", "comment": ""},
            {"name": "Plasma (X11)", "comment": ""},
            {"name": "GNOME", "comment": ""},
        ]

    @pyqtProperty(int, constant=True)
    def lastIndex(self):
        return 0

    def rowCount(self, parent=QModelIndex()):
        return len(self._sessions)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or index.row() >= len(self._sessions):
            return None
        session = self._sessions[index.row()]
        role_map = {
            self._NameRole: "name",
            self._CommentRole: "comment",
        }
        return session.get(role_map.get(role))

    def roleNames(self):
        return {
            self._NameRole: b"name",
            self._CommentRole: b"comment",
        }


class MockKeyboard(QObject):
    """Mimics SDDM's keyboard context property."""

    capsLockChanged = pyqtSignal()
    numLockChanged = pyqtSignal()

    def __init__(self):
        super().__init__()
        self._capsLock = False
        self._numLock = True

    @pyqtProperty(bool, notify=capsLockChanged)
    def capsLock(self):
        return self._capsLock

    @pyqtProperty(bool, notify=numLockChanged)
    def numLock(self):
        return self._numLock


# ═══════════════════════════════════════════════════════════════════
#  Hot-reloader (unchanged logic, moved below mocks for readability)
# ═══════════════════════════════════════════════════════════════════

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


# ═══════════════════════════════════════════════════════════════════
#  Entry point
# ═══════════════════════════════════════════════════════════════════

def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    os.environ["QML_DISABLE_DISK_CACHE"] = "1"

    if len(sys.argv) < 2:
        print("Usage: preview-host.py <theme-dir>", file=sys.stderr)
        sys.exit(1)

    theme_dir = os.path.abspath(sys.argv[1])
    if not os.path.isdir(theme_dir):
        print(f"Error: theme directory not found: {theme_dir}", file=sys.stderr)
        sys.exit(1)

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    # Resolve paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    preview_dir = os.path.join(project_dir, "preview")

    # ── Mock SDDM context properties ─────────────────────────────
    # Registered with the same names SDDM injects, so Main.qml works
    # identically in both the real greeter and the preview.
    # Keep references so Python doesn't garbage-collect them while QML
    # still holds the context property pointers.
    mocks = {
        "sddm": MockSddm(),
        "config": MockConfig(theme_dir),
        "userModel": MockUserModel(),
        "sessionModel": MockSessionModel(),
        "keyboard": MockKeyboard(),
    }
    ctx = engine.rootContext()
    for name, obj in mocks.items():
        ctx.setContextProperty(name, obj)

    # ── Hot-reloader ─────────────────────────────────────────────
    watch_dirs = [
        preview_dir,
        os.path.join(preview_dir, "components"),
        os.path.join(preview_dir, "assets"),
    ]
    reloader = HotReloader(engine, watch_dirs)
    ctx.setContextProperty("hotReloader", reloader)

    # ── Load ─────────────────────────────────────────────────────
    qml_path = os.path.join(preview_dir, "Preview.qml")
    engine.load(QUrl.fromLocalFile(qml_path))

    if not engine.rootObjects():
        print("Error: failed to load Preview.qml", file=sys.stderr)
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
