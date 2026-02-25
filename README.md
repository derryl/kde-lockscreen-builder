# gitpusher-login-theme

A minimal, clean SDDM login theme for KDE Plasma 6, built with pure QtQuick (no KDE/Plasma dependencies). Includes a live-preview development workflow for rapid iteration on colors, typography, layout, and background images without logging out or reinstalling.

## Project Structure

```
gitpusher-login-theme/
├── Main.qml                  # SDDM entry point (uses SDDM context properties)
├── metadata.desktop           # Theme registration (Theme-API 2.0, Qt6)
├── theme.conf                 # All configurable values: colors, fonts, background, clock
├── components/
│   ├── Clock.qml              # Date/time display
│   ├── LoginForm.qml          # Username + password fields, login button
│   ├── SessionSelector.qml    # Desktop session dropdown
│   └── PowerBar.qml           # Suspend / reboot / shutdown buttons
├── preview/
│   └── Preview.qml            # Mock harness for live development (no SDDM needed)
├── scripts/
│   ├── preview.sh             # File-watcher: auto-restarts preview on save
│   └── test-sddm.sh           # Full-fidelity SDDM greeter test
├── assets/
│   └── background.jpg         # Your background image (not tracked in git)
└── faces/
    └── .face.icon             # Default user avatar placeholder
```

## Prerequisites

- KDE Plasma 6 with SDDM
- Qt 6 (`qt6-declarative` package, provides `qml6` and `qmlscene6`)
- `entr` for file-watching (`sudo pacman -S entr` on Arch)

## Quick Start

1. Clone the repo and add your background image:

   ```sh
   cd gitpusher-login-theme
   cp /path/to/your/wallpaper.jpg assets/background.jpg
   ```

2. Launch the live preview:

   ```sh
   ./scripts/preview.sh
   ```

3. Edit any `.qml` file or `theme.conf`, save, and the preview window auto-restarts.

## Development Workflow

### Tier 1: Fast Iteration (qml6 + file watcher)

The primary development loop. `preview/Preview.qml` mocks all SDDM-provided objects (`sddm`, `userModel`, `sessionModel`, `config`, `keyboard`) so the theme renders in a standalone window without the real SDDM greeter.

```sh
./scripts/preview.sh
```

This watches all `.qml`, `.conf`, and image files using `entr`. On every file change, the preview window is killed and relaunched automatically.

You can also launch the preview manually (without file watching):

```sh
qml6 preview/Preview.qml
```

In mock mode, type the password `test` to simulate a successful login. Any other password triggers the "Login Failed" notification.

### Tier 2: Full-Fidelity SDDM Test

Periodically verify your theme against the real SDDM greeter:

```sh
./scripts/test-sddm.sh
```

This runs `sddm-greeter-qt6 --test-mode`, which shows your actual system user list, session list, and keyboard state. Login and power actions are non-functional in test mode, but layout and data binding are accurate.

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

# Screen dimensions (fallback)
screenWidth=1920
screenHeight=1080
```

Changes to `theme.conf` are picked up by the file watcher just like QML changes.

## Building

No build step is required. SDDM themes are interpreted QML — the `.qml` files, `theme.conf`, `metadata.desktop`, and assets are used directly at runtime.

## Installing

SDDM themes live in `/usr/share/sddm/themes/`. You can either symlink (recommended for development) or copy (for distribution).

### Option A: Symlink (recommended during development)

A symlink lets you keep editing files in your project directory and see changes reflected immediately (after re-running the SDDM test or on next login):

```sh
sudo ln -sf "$(pwd)" /usr/share/sddm/themes/gitpusher-login
```

### Option B: Copy (for final installation)

```sh
sudo cp -r . /usr/share/sddm/themes/gitpusher-login
```

### Activate the theme

After installing, set it as the active SDDM theme:

```sh
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=gitpusher-login
EOF
```

Or use KDE System Settings: **System Settings > Colors & Themes > Login Screen (SDDM)**.

### Verify

Run the full-fidelity test against the installed path to confirm:

```sh
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/gitpusher-login
```

## Architecture Notes

The theme is built with **pure QtQuick** — no imports from `org.kde.plasma.*`, `org.kde.breeze.components`, or `Kirigami`. This provides:

- Total control over every visual element
- No dependency on KDE Plasma libraries at the SDDM level
- Easy mocking: only 5 SDDM globals need stubs (`sddm`, `config`, `userModel`, `sessionModel`, `keyboard`)

Components receive their dependencies as explicit properties rather than relying on SDDM's context properties directly. This makes them testable in the preview harness and reusable.

## License

MIT
