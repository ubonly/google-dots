#!/usr/bin/env bash

# Exit on error
set -e

echo "=== Quickshell Dock Setup Script ==="

# 1. Detect AUR Helper
AUR_HELPER=""
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
else
    echo "Error: Neither 'yay' nor 'paru' was found. Please install an AUR helper first."
    exit 1
fi

echo "Using AUR helper: $AUR_HELPER"

# 2. Install dependencies
PACKAGES=(
    # Core & Fonts
    "quickshell-git"
    "ttf-roboto"
    "ttf-material-symbols-variable-git"
    "ttf-google-sans"
    "ttf-inter"
    
    # System Integration
    "jq"
    "python"
    "networkmanager"
    "bluez-utils"
    "wireplumber"
    
    # Screen Capture & Clipboard
    "grim"
    "hyprshot"
    "wl-screenrec"
    "wl-clipboard"
    "cliphist"
)

echo "Installing dependencies..."
$AUR_HELPER -S --needed --noconfirm "${PACKAGES[@]}"

# 3. Configure Hyprland
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HYPR_CONF" ]; then
    echo "Configuring Hyprland..."
    
    # Check if config already exists
    if grep -q "layerrule = blur, quickshell" "$HYPR_CONF"; then
        echo "Hyprland rules for Quickshell already exist in $HYPR_CONF"
    else
        echo "Appending Quickshell rules to $HYPR_CONF..."
        cat << 'EOF' >> "$HYPR_CONF"

# Blur and transparency for quickshell
layerrule = blur, quickshell
layerrule = ignorealpha 0.15, quickshell
layerrule = xray 0, quickshell

# Autostart quickshell
exec-once = quickshell
EOF
        echo "Hyprland configuration updated successfully."
    fi
else
    echo "Warning: Hyprland configuration not found at $HYPR_CONF. Skipping Hyprland configuration."
fi

# 4. Copy configuration files to ~/.config/quickshell
CONFIG_DIR="$HOME/.config/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$CONFIG_DIR" ]; then
    echo "Configuration directory $CONFIG_DIR already exists."
    read -p "Do you want to backup and overwrite it with the repository version? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_DIR="${CONFIG_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Backing up existing config to $BACKUP_DIR..."
        mv "$CONFIG_DIR" "$BACKUP_DIR"
        echo "Copying configuration..."
        cp -r "$SCRIPT_DIR/quickshell" "$CONFIG_DIR"
    fi
else
    echo "Copying configuration to $CONFIG_DIR..."
    mkdir -p "$HOME/.config"
    cp -r "$SCRIPT_DIR/quickshell" "$CONFIG_DIR"
fi

echo "=== Setup Complete! ==="
echo "You can start Quickshell now by running 'quickshell' or logging back into Hyprland."
