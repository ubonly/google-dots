# Quickshell Dock for Hyprland (Arch Linux)

A floating dock and desktop environment layer for Hyprland built with [Quickshell](https://outfoxxed.me/quickshell/). Features include workspace indicators, app launcher, system tray, clock/calendar, quick settings, notifications, clipboard history, and a screen capture overlay.

## Installation

### 1. Dependencies

Make sure you have all required dependencies installed for the widgets to function properly.

```bash
# Core Quickshell (from AUR)
yay -S quickshell-git

# Fonts and Icons
sudo pacman -S ttf-roboto
yay -S ttf-material-symbols-variable-git   # Material Symbols icons
yay -S ttf-google-sans                     # Google Sans font (primary UI font)
yay -S ttf-inter                           # Inter font (fallback)

# System Utilities (for Quick Settings & Dock)
sudo pacman -S jq python networkmanager bluez-utils wireplumber

# Screen Capture Tools
yay -S grim hyprshot wl-screenrec wl-clipboard

# Clipboard Manager
sudo pacman -S cliphist
```

### 2. Copy the Configuration

Copy this repository to your Quickshell config directory:

```bash
git clone https://github.com/ubonly/google-dots.git ~/google-dots
cp -r ~/google-dots/quickshell ~/.config/quickshell
```

### 3. Configure Hyprland (`hyprland.conf`)

Add the following rules to your `~/.config/hypr/hyprland.conf`:

```ini
# Blur and transparency for Quickshell overlays
layerrule = blur, quickshell
layerrule = ignorealpha 0.15, quickshell
layerrule = xray 0, quickshell

# Autostart
exec-once = quickshell
```

### 4. Running Quickshell

```bash
# Start manually for testing
quickshell

# Or if your config is in a different location:
quickshell -p ~/.config/quickshell
```

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
