#!/bin/bash
# Hyprland session plus the small Wayland tools a bare compositor needs.
# GNOME and GDM come from base-main and stay as the fallback session; GDM
# picks Hyprland up from its wayland-sessions .desktop file.

set -euxo pipefail

# Hyprland is pinned to the 0.56 series: upstream is moving the config format
# to Lua. Bump deliberately, after the config is migrated (see CLAUDE.md).
dnf5 -y install \
    'hyprland-0.56*' \
    hyprlock \
    hypridle \
    hyprpaper \
    hyprpicker \
    hyprpolkitagent \
    xdg-desktop-portal-hyprland \
    uwsm

dnf5 -y install \
    waybar \
    mako \
    fuzzel \
    grim \
    slurp \
    wl-clipboard \
    cliphist \
    brightnessctl \
    pavucontrol \
    network-manager-applet \
    blueman \
    qt5-qtwayland \
    qt6-qtwayland \
    kitty \
    wf-recorder \
    swappy

# GDM lists two Hyprland sessions. Only the uwsm one starts
# graphical-session.target, which xdg-desktop-portal (file pickers, screen
# sharing, dark mode) needs: on the SSD test the plain one left the portal
# dead all session. Hiding the plain one isn't possible - uwsm launches that
# same entry and refuses Hidden ones - so rename both to make the choice obvious.
sed -i 's/^Name=Hyprland$/Name=Hyprland (no uwsm - fallback)/' /usr/share/wayland-sessions/hyprland.desktop
sed -i 's/^Name=Hyprland (uwsm-managed)$/Name=Hyprland/' /usr/share/wayland-sessions/hyprland-uwsm.desktop

# Speech-to-text and voice clean-up for pugrec (the demo recorder, installed in
# the user layer): whisper-cli (Vulkan, built in the Containerfile's
# whisper-builder stage) and DeepFilterNet's static deep-filter binary, pinned
# by checksum. Neither is in Fedora. pugrec finds both on PATH; its
# Python/model files stay per user (~/.cache/pugrec).
install -m 755 /bins/whisper/whisper-cli /usr/bin/whisper-cli
install -Dm 644 /bins/whisper/LICENSE /usr/share/licenses/whisper-cpp/LICENSE
df_version=0.5.6
curl -fsSL -o /usr/bin/deep-filter \
    "https://github.com/Rikorose/DeepFilterNet/releases/download/v${df_version}/deep-filter-${df_version}-x86_64-unknown-linux-musl"
echo "70775e251eee44c0f2451a1e833326cf8bcbbe304d3e7cd12851e6fce72ef7da  /usr/bin/deep-filter" | sha256sum -c -
chmod 755 /usr/bin/deep-filter
