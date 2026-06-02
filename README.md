# Quickshell Dock for Hyprland (Arch Linux)

A floating dock and desktop environment layer for Hyprland built with [Quickshell](https://outfoxxed.me/quickshell/). Features include workspace indicators, app launcher, system tray, clock/calendar, quick settings, notifications, clipboard history, and a screen capture overlay.

## Installation

The easiest way to install the configuration, dependencies, and configure Hyprland is to use the provided setup script.

### 1. Clone the repository

```bash
git clone https://github.com/ubonly/google-dots.git ~/google-dots
cd ~/google-dots
```

### 2. Run the installer script

Make the script executable and run it. It will automatically detect your AUR helper (`yay` or `paru`), install all dependencies, copy the configuration files to `~/.config/quickshell`, and append the necessary rules to your `hyprland.conf`:

```bash
chmod +x install.sh
./install.sh
```

### 3. Manual Steps (Optional / Reference)

If you prefer to install things manually, here is what the script does:

#### Packages installed (via AUR helper):
- **Core & Fonts**: `quickshell-git`, `ttf-roboto`, `ttf-material-symbols-variable-git`, `ttf-google-sans`, `ttf-inter`
- **System Integration**: `jq`, `python`, `networkmanager`, `bluez-utils`, `wireplumber`
- **Screen Capture & Clipboard**: `grim`, `hyprshot`, `wl-screenrec`, `wl-clipboard`, `cliphist`

#### Configuration added to `~/.config/hypr/hyprland.conf`:

## File Structure

```
~/.config/quickshell/
├── shell.qml                     # Main layout and overlays
├── WorkspaceButton.qml           # Workspace indicators
├── AppLauncher.qml               # Application launcher
├── QuickSettingsPopup.qml        # Quick settings (WiFi, Bluetooth, Volume)
├── ScreenCapture.qml             # ChromeOS-style screen capture toolbar
├── ClipboardPopup.qml            # Clipboard history manager
├── NotificationsPopup.qml        # Notification toasts
├── NotificationCenterPopup.qml   # Notification history center
├── MediaPopup.qml                # MPRIS Media controls
└── ClockWidget.qml               # Clock and date widget
```

## Customization

### Pinned Apps in App Launcher
The pinned apps are automatically read from `apps.json`.
You can customize the available apps by editing `apps.json`.

### Changing the Look
To modify the appearance, open `shell.qml` or specific component files. Variables like colors, radii, and margins are usually defined at the top of the QML components.

## Shortcuts & IPC

- **Super + R**: Toggle App Launcher
- **Super + V**: Toggle Clipboard History
- **Super + Shift + S**: Region Screenshot
- **PrintScreen**: Fullscreen Screenshot

These shortcuts are registered globally via Quickshell's `GlobalShortcut` component. You can also trigger them via IPC:
```bash
qs ipc call launcher toggle
qs ipc call clipboard_ui toggle
qs ipc call screenshot region
qs ipc call screenshot fullscreen
```
