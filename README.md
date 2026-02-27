# kde-lockscreen-builder

Build and customize your KDE login screen without having to actually reinstall the theme and log out just to see how it looks.

<img width="2120" height="1498" alt="image" src="https://github.com/user-attachments/assets/9dfbebbf-7c44-4c64-9577-08e9e2b2d25e" />

This project gives you a live-preview development environment for SDDM themes on KDE Plasma 6. Edit QML, tweak colors, swap backgrounds -- and see every change instantly in a standalone window. When you're happy with the result, install it as your real login screen with one command.

## Quick Start

### Prerequisites

- KDE Plasma 6 with SDDM
- Qt 6 (`qt6-declarative` package -- provides `qml6`)
- `entr` for file-watching (`sudo pacman -S entr` on Arch)

### Start from the included starter theme

The repo ships with a minimal, clean theme that works out of the box:

```sh
git clone https://github.com/derryl/kde-lockscreen-builder.git
cd kde-lockscreen-builder
cp /path/to/your/wallpaper.jpg themes/default/assets/background.jpg
./scripts/preview.sh
```

Edit any `.qml` file or `theme.conf`, save, and the preview window restarts automatically.

### Or import an existing theme

Already have a theme you want to modify? You can find community themes on the [KDE Store](https://store.kde.org/browse?cat=101&ord=rating), or copy one that's already installed on your system:

```sh
# Example: importing from an installed SDDM theme
cp -r /usr/share/sddm/themes/some-theme/* themes/default/
./scripts/preview.sh
```

If the imported theme uses KDE/Plasma-specific QML imports (e.g. `org.kde.plasma.*`), the standalone preview won't render those parts. You can still use `./scripts/test-sddm.sh` for full-fidelity testing, or incrementally replace those imports with pure QtQuick equivalents.

## Development Workflow

### Live preview

```sh
./scripts/preview.sh                  # preview the default theme
./scripts/preview.sh -theme <name>    # preview a specific theme under themes/
```

This watches all `.qml`, `.conf`, and image files. On every save, the preview window restarts automatically. In preview mode, type the password `test` to simulate a successful login.

You can also launch the preview once without file-watching:

```sh
qml6 preview/Preview.qml
```

### Full-fidelity SDDM test

Periodically verify your theme against the real SDDM greeter:

```sh
./scripts/test-sddm.sh
```

This runs `sddm-greeter-qt6 --test-mode`, which shows your actual system user list, session list, and keyboard state. Login and power actions are non-functional in test mode, but layout and data binding are real.

## Configuration

All configurable values live in `theme.conf`:

```ini
[General]
background=assets/background.jpg

# Colors (hex)
primaryColor=#ffffff
accentColor=#4a9eff
backgroundOverlayColor=#000000
backgroundOverlayOpacity=0.3

# Typography
fontFamily=
fontPointSize=12

# Layout
clockVisible=true
clockFormat=hh:mm
dateFormat=dddd, MMMM d

# Screen dimensions (fallback when not provided by SDDM)
screenWidth=1920
screenHeight=1080
```

Changes to `theme.conf` are picked up by the file watcher just like QML changes.

## Installing Your Theme

SDDM themes live in `/usr/share/sddm/themes/`.

### 1. Choose a theme name

Pick a name for your theme (e.g. `my-login-theme`). Make sure `metadata.desktop` has the matching `Theme-Id`:

```ini
Theme-Id=my-login-theme
```

### 2. Install the files

**Symlink (recommended during development)** -- lets you keep editing and see changes on next login:

```sh
sudo ln -sf "$(pwd)/themes/default" /usr/share/sddm/themes/my-login-theme
```

**Copy (for a final install):**

```sh
sudo cp -r themes/default /usr/share/sddm/themes/my-login-theme
```

### 3. Activate the theme

```sh
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=my-login-theme
EOF
```

Or use the GUI: **System Settings > Colors & Themes > Login Screen (SDDM)**.

### 4. Verify

```sh
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/my-login-theme
```

## Useful Links

- [SDDM Theming Guide](https://github.com/sddm/sddm/wiki/Theming) -- API reference for the SDDM context properties (`sddm`, `userModel`, `sessionModel`, etc.) and theme structure
- [KDE Store: SDDM Login Themes](https://store.kde.org/browse?cat=101&ord=rating) -- community-made themes to use as starting points or inspiration
- [Qt QML Documentation](https://doc.qt.io/qt-6/qtqml-index.html) -- language reference for QML
- [Qt Quick Documentation](https://doc.qt.io/qt-6/qtquick-index.html) -- the UI framework used by SDDM themes

## License

MIT
