# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A development environment for building and customizing SDDM login themes for KDE Plasma 6. Themes are written in pure QtQuick/QML (no KDE Plasma library dependencies) and can be previewed in a standalone window without restarting SDDM.

## Commands

### Live preview (primary development loop)

```sh
./scripts/preview.sh                  # preview the default theme
./scripts/preview.sh -theme <name>    # preview a specific theme
```

The preview requires the Python host (`preview-host.py`) — there is no standalone `qml6` launch path. The host injects mock SDDM context properties and provides hot-reload via file watching.

### Lint (static analysis + runtime type check)

```sh
./scripts/lint-qml.sh                 # lint all themes
./scripts/lint-qml.sh -theme <name>   # lint a specific theme
```

CI runs this on every push/PR. It runs `qmllint` for static analysis, then launches the preview host under `xvfb` for 3 seconds to catch runtime type errors (`Unable to assign`, `ReferenceError`, `TypeError`).

### Full-fidelity SDDM test

```sh
./scripts/test-sddm.sh                # test default theme with real SDDM greeter
./scripts/test-sddm.sh -theme <name>
```

## Architecture

### Theme structure

Themes live under `themes/<name>/`. The default theme is at `themes/default/`.

Each theme is fully self-contained:

```
themes/<name>/
  Main.qml             # SDDM entry point; root Item using SDDM context properties
  theme.conf           # all configurable values (colors, fonts, background, etc.)
  metadata.desktop     # SDDM theme registration metadata
  components/          # UI components (Clock, LoginForm, SessionSelector, PowerBar)
    Clock.qml
    LoginForm.qml
    PowerBar.qml
    SessionSelector.qml
  assets/              # background image and other static assets
    background.jpg
  faces/               # user avatar images (optional)
```

Any number of themes can coexist in `themes/` and be previewed interchangeably.

### Preview harness

The preview system is designed so themes need zero awareness of the preview environment. The real SDDM greeter and the preview host both inject the same five context properties, so `Main.qml` works identically in both.

**How it works:**

1. `preview.sh` symlinks the selected theme's `Main.qml`, `components/`, and `assets/` into `preview/` so QML relative imports resolve correctly.
2. `preview-host.py` (PyQt6) creates mock objects for all five SDDM context properties and registers them via `engine.rootContext().setContextProperty()` — the same mechanism SDDM uses.
3. `Preview.qml` is a thin window shell with a `Loader` that loads `Main.qml`. It also binds `config.screenWidth`/`config.screenHeight` to the window dimensions and provides the hot-reload overlay badge.
4. The `HotReloader` watches theme files and triggers a 3-phase reload: unload Loader -> clear component cache -> reload Loader.

**Key design principle:** No theme-specific layout logic exists outside `themes/`. The `preview/` directory contains only the generic harness. Adding a new theme requires no changes to preview infrastructure.

In preview mode, use password `test` for successful login; any other password triggers "Login Failed".

### SDDM context properties

SDDM injects five globals that themes depend on:

| Property | Type | Description |
|----------|------|-------------|
| `sddm` | QObject | Proxy with `login()`, `powerOff()`, `reboot()`, `suspend()` and capability booleans (`canPowerOff`, `canReboot`, `canSuspend`) |
| `config` | QObject | Key-value access to `theme.conf` `[General]` section (e.g., `config.primaryColor`, `config.fontPointSize`) |
| `userModel` | QAbstractListModel | List of system users with roles: `name`, `realName`, `icon`, `needsPassword`. Also has `lastUser` property. |
| `sessionModel` | QAbstractListModel | List of desktop sessions with roles: `name`, `comment`. Also has `lastIndex` property. |
| `keyboard` | QObject | Keyboard state: `capsLock`, `numLock` booleans |

Components receive these as explicit properties rather than accessing globals directly, making them portable and testable.

### Config values

All config values from `theme.conf` are strings in QML. Main.qml parses them as needed:

```qml
// Integer parsing with fallback
property int baseFontSize: config.fontPointSize ? parseInt(config.fontPointSize) : 12

// Float parsing with fallback
opacity: parseFloat(config.backgroundOverlayOpacity) || 0.3

// String comparison for booleans
visible: config.clockVisible === "true"
```

### QML style

All scripts set `QT_QUICK_CONTROLS_STYLE=Basic` to avoid Breeze/Plasma-specific errors outside a full Plasma session. Without this, ComboBox and other controls fail with `TypeError: Cannot read property 'Overlay' of undefined`.

## Key Files

### Theme files (per theme)

- `themes/<name>/Main.qml` — Root layout: background, clock, login form, power bar, footer. Wires SDDM context properties to component props.
- `themes/<name>/theme.conf` — INI-format config under `[General]`. Keys: `background`, `primaryColor`, `accentColor`, `backgroundOverlayColor`, `backgroundOverlayOpacity`, `fontFamily`, `fontPointSize`, `clockVisible`, `clockFormat`, `dateFormat`, `screenWidth`, `screenHeight`.
- `themes/<name>/components/LoginForm.qml` — Password field + login icon button in a horizontal Row. No username field; uses `defaultUsername` from `userModel.lastUser`.
- `themes/<name>/components/PowerBar.qml` — Suspend/Reboot/Shut Down buttons using unicode icons. Inline `component PowerButton` definition.
- `themes/<name>/components/Clock.qml` — Time + date display with configurable formats via Qt `timeFormat`/`dateFormat` strings.
- `themes/<name>/components/SessionSelector.qml` — ComboBox for desktop session selection, bound to `sessionModel`.

### Preview infrastructure

- `preview/Preview.qml` — Thin window shell. Loader + hot-reload wiring + overlay badge. No mock objects or theme layout logic.
- `scripts/preview-host.py` — PyQt6 host. Defines `MockSddm`, `MockConfig`, `MockUserModel`, `MockSessionModel`, `MockKeyboard`. Reads `theme.conf` for config values. Provides `HotReloader` for live preview.
- `scripts/preview.sh` — Sets up symlinks (`Main.qml`, `components/`, `assets/` into `preview/`), launches `preview-host.py` with the theme directory as argument.
- `scripts/lint-qml.sh` — Static + runtime lint. Uses `qmllint` then launches `preview-host.py` under `xvfb` to catch runtime type errors.

## QML / Qt Quick Guidelines

### Imports available

```qml
import QtQuick              // core types: Item, Rectangle, Text, Image, etc.
import QtQuick.Layouts      // RowLayout, ColumnLayout
import QtQuick.Controls     // TextField, Button, ComboBox
import Qt5Compat.GraphicalEffects  // DropShadow, InnerShadow, etc. (Qt 6 compat module)
```

**Never import:** `org.kde.plasma.*`, `org.kde.breeze.components`, `Kirigami`, `PlasmaExtras`, or any KDE-specific modules. These break outside a full Plasma session.

### Applying graphical effects (DropShadow, etc.)

Use `layer.enabled` + `layer.effect` to apply effects inline without restructuring the component tree or hiding the source:

```qml
TextField {
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 2
        radius: 12.0
        samples: 25          // recommended: 1 + radius * 2
        color: "#40000000"
        transparentBorder: true
    }
}
```

The alternative (separate `DropShadow` item with `visible: false` on the source) works but requires restructuring sibling elements.

### Inset / recessed field effect

Simulate an inset border using two nested Rectangles inside a background `Item`:

```qml
background: Item {
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "transparent"
        border.color: Qt.rgba(0, 0, 0, 0.5)  // dark outer ring = shadow edge
        border.width: 1
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 7
        color: "#1e293b"                       // dark slate fill
        border.color: Qt.rgba(255, 255, 255, 0.06)  // subtle light rim
        border.width: 1
    }
}
```

### Component.onCompleted

**Critical:** A QML component can only have ONE `Component.onCompleted` handler. If you define two, QML reports "Property value set multiple times" and the component silently fails to load. Merge all initialization into a single block:

```qml
// WRONG — will fail silently
Component.onCompleted: { doA() }
Component.onCompleted: { doB() }

// CORRECT
Component.onCompleted: {
    doA()
    doB()
}
```

### Color functions

```qml
Qt.rgba(r, g, b, a)              // 0.0–1.0 range
Qt.darker(color, factor)          // factor > 1.0 = darker
Qt.lighter(color, factor)         // factor > 1.0 = lighter
"#AARRGGBB"                       // hex with alpha prefix
```

### Focus management

```qml
Component.onCompleted: {
    passwordField.forceActiveFocus()
}

Keys.onReturnPressed: doLogin()
Keys.onEnterPressed: doLogin()     // numpad Enter — always handle both
```

### Common QML patterns in this codebase

- `renderType: Text.NativeRendering` on all Text elements for crisp rendering at login screen resolution
- `Behavior on color { ColorAnimation { duration: 120 } }` for smooth hover transitions
- Components expose signals (e.g., `signal loginRequest(string username, string password)`) rather than calling SDDM directly
- Inline component definitions via `component Name: Item { ... }` (used in PowerBar.qml)

## PyQt6 / Preview Host Guidelines

### Object lifetime (garbage collection)

When registering Python QObjects as QML context properties, keep Python references alive for the process lifetime. Without this, Python's GC frees the objects while QML still holds pointers, causing `null` access errors:

```python
# WRONG — objects are GC'd immediately after setContextProperty returns
ctx.setContextProperty("sddm", MockSddm())

# CORRECT — dict keeps references alive
mocks = {
    "sddm": MockSddm(),
    "config": MockConfig(theme_dir),
}
for name, obj in mocks.items():
    ctx.setContextProperty(name, obj)
```

### configparser key casing

Python's `configparser` lowercases all keys by default. `primaryColor` in theme.conf becomes `primarycolor`. Map explicitly:

```python
@pyqtProperty(str, constant=True)
def primaryColor(self):             # QML accesses config.primaryColor
    return self._get("primarycolor")  # configparser stored it lowercase
```

### File paths for QML

QML `Image.source` expects either a relative path (resolved from the QML file's location) or a `file:///` URL. When providing paths from Python, always use absolute file URLs:

```python
abs_bg = os.path.join(theme_dir, bg)
self._values["background"] = QUrl.fromLocalFile(abs_bg).toString()
# produces: file:///home/.../themes/default/assets/background.jpg
```

**The `theme_dir` argument must be an absolute path** — use `os.path.abspath()` before any path joins.

### Writable properties from QML

To let QML write to a Python property (e.g., `config.screenWidth = width`), use the `fget`/`fset` form:

```python
screenWidthChanged = pyqtSignal()

def _get_screen_width(self):
    return self._screen_width

def _set_screen_width(self, val):
    if self._screen_width != val:
        self._screen_width = val
        self.screenWidthChanged.emit()

screenWidth = pyqtProperty(int, fget=_get_screen_width, fset=_set_screen_width,
                           notify=screenWidthChanged)
```

### QAbstractListModel roles

SDDM models expose data via named roles. Python mocks must define `roleNames()` returning a dict of `{role_int: b"name"}` and handle those roles in `data()`:

```python
_NameRole = Qt.ItemDataRole.UserRole + 1

def roleNames(self):
    return {self._NameRole: b"name"}

def data(self, index, role=Qt.ItemDataRole.DisplayRole):
    if role == self._NameRole:
        return self._items[index.row()]["name"]
```

## Key Conventions

- Pure QtQuick only — no KDE/Plasma imports
- Components take dependencies as explicit props (not SDDM context property access)
- `qmllint` warnings about unresolved SDDM globals are expected and tolerated; only actual errors fail CI
- All config values come through `theme.conf` and are accessed via `config.<key>` in QML
- Themes are fully self-contained — no files outside `themes/<name>/` should reference theme-specific layout
- Always handle both `Keys.onReturnPressed` and `Keys.onEnterPressed` (keyboard Enter vs numpad Enter)
- Always set `QT_QUICK_CONTROLS_STYLE=Basic` in any script that runs QML outside a Plasma session

## Documentation References (Context7)

Use Context7 to look up Qt/QML documentation. Key library IDs:

- **Qt 6 (full docs):** `/websites/doc_qt_io_qt-6_8` — covers all Qt modules, QML types, properties, and examples
  - DropShadow, InnerShadow: query `Qt5Compat.GraphicalEffects DropShadow`
  - Item layer effects: query `QML layer.enabled layer.effect`
  - TextField, ComboBox, Button: query `QtQuick.Controls <type>`
  - Image, Rectangle, Text: query `QtQuick <type> properties`
  - Loader: query `QML Loader setSource`
  - Property types and bindings: query `QML property binding`
  - Animations: query `QML Behavior ColorAnimation NumberAnimation`

### Useful external references

- SDDM theme API: the SDDM wiki on GitHub documents what context properties are injected and what roles the models expose. Search for `sddm theme api` or `sddm theme development`.
- Qt Quick Controls styling: the `Basic` style is Qt's unstyled fallback. Search `Qt Quick Controls styles Basic`.
- `eos-breeze-sddm` (GitHub: `endeavouros-team/eos-breeze-sddm`): reference SDDM theme this project draws design inspiration from.
