#!/bin/bash
# Gaming: Lutris (WoW), Steam, gamescope, and the 32-bit graphics stack Wine
# needs. The RX 9070 runs on Mesa/RADV, so no proprietary driver is involved.
#
# Lutris stays an RPM, not the Flatpak: the Flatpak keeps its data under
# ~/.var/app, which would orphan the existing ~/.config/lutris,
# ~/.local/share/lutris runners and the ~/Games prefix.

set -euxo pipefail

dnf5 -y install \
    lutris \
    gamescope \
    gamemode gamemode.i686 \
    mangohud mangohud.i686 \
    mesa-dri-drivers.i686 \
    mesa-vulkan-drivers.i686 \
    vulkan-loader.i686 \
    vulkan-tools \
    protonplus

# Steam lives in RPM Fusion nonfree-steam. base-main ships RPM Fusion repo
# definitions; enable the steam one for this transaction only.
dnf5 -y install --enablerepo='rpmfusion-nonfree-steam' steam steam-devices
