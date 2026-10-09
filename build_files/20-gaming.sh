#!/bin/bash
# Gaming: Lutris (WoW), Steam, gamescope, and the 32-bit graphics stack Wine
# needs. The RX 9070 runs on Mesa/RADV, so no proprietary driver is involved.
#
# Lutris stays an RPM, not the Flatpak: the Flatpak keeps its data under
# ~/.var/app, which would orphan the existing ~/.config/lutris,
# ~/.local/share/lutris runners and the ~/Games prefix.

set -euxo pipefail

# Lutris without weak deps: its Recommends pull in system Wine (~3 GB), which
# the old install never had - WoW runs on a GE-Proton runner from
# ~/.local/share/lutris/runners. The recommends the old install *did* have are
# listed explicitly below.
dnf5 -y install --setopt=install_weak_deps=False lutris
dnf5 -y install \
    cabextract \
    fluid-soundfont-gs \
    libFAudio libFAudio.i686 \
    libXScrnSaver.i686 \
    mesa-libGL.i686 \
    pipewire.i686 \
    xrandr

dnf5 -y install \
    gamescope \
    gamemode gamemode.i686 \
    mangohud mangohud.i686 \
    mesa-dri-drivers.i686 \
    mesa-vulkan-drivers.i686 \
    vulkan-loader.i686 \
    vulkan-tools \
    protonplus

# Steam comes from negativo17's fedora-steam repo (repos/negativo17-steam.repo).
# The ublue base already uses negativo17 for multimedia and ships no RPM
# Fusion, so this keeps a single third-party vendor for the media/gaming stack.
dnf5 -y install steam steam-devices
