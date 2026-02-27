# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A development environment for building and customizing SDDM login themes for KDE Plasma 6. Themes are written in pure QtQuick/QML (no KDE Plasma library dependencies) and can be previewed in a standalone window without restarting SDDM.

## Commands

### Live preview (primary development loop)
```sh
./scripts/preview.sh                  # preview the default theme
./scripts/preview.sh -theme <name>    # preview a specific theme
qml6 preview/Preview.qml             # one-shot preview (no file watching)
```

### Lint (static analysis + runtime type check)
```sh
./scripts/lint-qml.sh                 # lint all themes
./scripts/lint-qml.sh -theme <name>   # lint a specific theme
```
CI runs this on every push/PR. It runs `qmllint` for static analysis, then launches the preview under `xvfb` for 3 seconds to catch runtime type errors (`Unable to assign`, `ReferenceError`, `TypeError`).

### Full-fidelity SDDM test
```sh
./scripts/test-sddm.sh                # test default theme with real SDDM greeter
./scripts/test-sddm.sh -theme <name>
```

## Architecture

### Theme structure
Themes live under `themes/<name>/`. The default theme is at `themes/default/`.

Each theme contains:
- `Main.qml` — SDDM entry point; root `Item` that uses SDDM-injected context properties
- `theme.conf` — all configurable values (colors, fonts, background, clock format, screen dimensions)
- `metadata.desktop` — SDDM theme registration metadata
- `components/` — UI components (Clock, LoginForm, SessionSelector, PowerBar)
- `assets/` — background image and other static assets

### Preview harness
`preview/Preview.qml` mirrors `Main.qml` layout but replaces SDDM context properties with mock objects (`mockSddm`, `mockConfig`, `mockUserModel`, `mockSessionModel`, `mockKeyboard`). The preview script symlinks the selected theme's `components/` and `assets/` into `preview/` so relative QML imports resolve correctly.

In preview mode, use password `test` for successful login; any other password triggers "Login Failed".

### SDDM context properties
SDDM injects five globals that themes depend on: `sddm`, `config`, `userModel`, `sessionModel`, `keyboard`. Components receive these as explicit properties rather than accessing globals directly, making them portable between Main.qml (real SDDM) and Preview.qml (mocks).

### QML style
All scripts set `QT_QUICK_CONTROLS_STYLE=Basic` to avoid Breeze/Plasma-specific errors outside a full Plasma session.

## Key Conventions

- Pure QtQuick only — no `org.kde.plasma.*`, `org.kde.breeze.components`, or `Kirigami` imports
- Components take dependencies as explicit props (not SDDM context property access)
- `qmllint` warnings about unresolved SDDM globals are expected and tolerated; only actual errors fail CI
- All config values come through `theme.conf` and are accessed via `config.<key>` in QML
