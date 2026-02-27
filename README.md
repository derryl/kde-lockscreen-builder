# kde-lockscreen-builder

Build and customize your KDE login screen without having to actually reinstall the theme and log out just to see how it looks.

<img width="2120" height="1498" alt="image" src="https://github.com/user-attachments/assets/9dfbebbf-7c44-4c64-9577-08e9e2b2d25e" />

This project gives you a live-preview development environment for SDDM themes on KDE Plasma 6. Edit QML, tweak colors, swap backgrounds -- and see every change instantly in a standalone window. When you're happy with the result, install it as your real login screen with one command.

**Who is this for?** Anyone who wants to customize their KDE/SDDM login screen -- whether you're importing an existing theme to tweak it, or building one from scratch.

## What's Inside

```
kde-lockscreen-builder/
├── Main.qml                  # SDDM entry point (the actual theme)
├── metadata.desktop           # Theme registration (Theme-API 2.0, Qt6)
├── theme.conf                 # All configurable values: colors, fonts, background, clock
├── components/
│   ├── Clock.qml              # Date/time display
│   ├── LoginForm.qml          # Username + password fields, login button
│   ├── SessionSelector.qml    # Desktop session dropdown
│   └── PowerBar.qml           # Suspend / reboot / shutdown buttons
├── preview/
│   └── Preview.qml            # Mock harness — previews your theme without SDDM
├── scripts/
│   ├── preview.sh             # File-watcher: auto-restarts preview on every save
│   └── test-sddm.sh           # Full-fidelity SDDM greeter test
├── assets/
│   └── background.jpg         # Your background image
└── faces/
    └── .face.icon             # Default user avatar placeholder
```

## Prerequisites

- KDE Plasma 6 with SDDM
- Qt 6 (`qt6-declarative` package -- provides `qml6`)
- `entr` for file-watching (`sudo pacman -S entr` on Arch)

## Quick Start

### Option A: Start From the Included Starter Theme

The repo ships with a minimal, clean theme that works out of the box. Clone and preview it immediately:

```sh
git clone https://github.com/derryl/kde-lockscreen-builder.git
cd kde-lockscreen-builder
cp /path/to/your/wallpaper.jpg assets/background.jpg
./scripts/preview.sh
```

Edit any `.qml` file or `theme.conf`, save, and the preview window restarts automatically.

### Option B: Import an Existing Theme

Already have a theme you want to modify? Copy its files into this project to get the live-preview workflow:

1. Clone this repo:

   ```sh
   git clone https://github.com/derryl/kde-lockscreen-builder.git
   cd kde-lockscreen-builder
   ```

2. Copy the theme's files over the project files. SDDM themes typically have a `Main.qml`, `metadata.desktop`, `theme.conf`, and asset directories -- replace the ones in this repo with yours:

   ```sh
   # Example: importing from an installed SDDM theme
   cp -r /usr/share/sddm/themes/some-theme/* .
   ```

3. Launch the preview:

   ```sh
   ./scripts/preview.sh
   ```

   If the imported theme uses KDE/Plasma-specific QML imports (e.g. `org.kde.plasma.*`), the standalone preview won't be able to render those parts. You can still use `./scripts/test-sddm.sh` for full-fidelity testing, or incrementally replace those imports with pure QtQuick equivalents.

## Development Workflow

### Live Preview (primary loop)

`preview/Preview.qml` mocks all SDDM-provided objects (`sddm`, `userModel`, `sessionModel`, `config`, `keyboard`) so your theme renders in a standalone window -- no real SDDM greeter needed.

```sh
./scripts/preview.sh
```

This watches all `.qml`, `.conf`, and image files using `entr`. On every save, the preview window is killed and relaunched automatically.

You can also launch the preview once without file-watching:

```sh
qml6 preview/Preview.qml
```

In preview mode, type the password `test` to simulate a successful login. Any other password triggers the "Login Failed" notification.

### Full-Fidelity SDDM Test

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

When you're satisfied with your theme, install it so SDDM uses it at your real login screen. SDDM themes live in `/usr/share/sddm/themes/`.

### 1. Choose a theme name

Pick a name for your theme (e.g. `my-login-theme`). Make sure `metadata.desktop` has the matching `Theme-Id`:

```ini
Theme-Id=my-login-theme
```

### 2. Install the files

**Symlink (recommended during development)** -- lets you keep editing and see changes on next login:

```sh
sudo ln -sf "$(pwd)" /usr/share/sddm/themes/my-login-theme
```

**Copy (for a final install):**

```sh
sudo cp -r . /usr/share/sddm/themes/my-login-theme
```

### 3. Activate the theme

Tell SDDM to use your theme:

```sh
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=my-login-theme
EOF
```

Or use the GUI: **System Settings > Colors & Themes > Login Screen (SDDM)**.

### 4. Verify

Run the full-fidelity test against the installed path to confirm everything works:

```sh
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/my-login-theme
```

## Architecture Notes

The included starter theme is built with **pure QtQuick** -- no imports from `org.kde.plasma.*`, `org.kde.breeze.components`, or `Kirigami`. This means:

- Total control over every visual element
- No dependency on KDE Plasma libraries at the SDDM level
- Easy mocking: only 5 SDDM globals need stubs (`sddm`, `config`, `userModel`, `sessionModel`, `keyboard`)

Components receive their dependencies as explicit properties rather than relying on SDDM context properties directly, making them testable in the preview harness and reusable across themes.

## License

MIT
