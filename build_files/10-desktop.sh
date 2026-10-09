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
    kitty
