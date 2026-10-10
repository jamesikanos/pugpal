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
