#!/bin/bash
# The PugPal shell layer: Quickshell (our own RPM, built from a pinned commit in
# the Containerfile's quickshell-builder stage) + DankMaterialShell, plus the
# brand fonts. The look itself (theme, Hyprland config, wallpapers) lives in
# the private dotfiles repo; this image only ships the tools.

set -euxo pipefail

# Our Quickshell first, so DMS's "Requires: quickshell" is already satisfied
# and dnf never swaps in the COPR's build.
dnf5 -y install /rpms/quickshell/quickshell-*.rpm

# avengemedia/danklinux: DMS's helpers (dgop, matugen, danksearch, ...).
# avengemedia/dms: DankMaterialShell itself. Never take Quickshell from them.
# Both are enabled for this stage only: danklinux also carries packages Fedora
# has (cliphist, cli11, ...), which must not leak into the other stages.
dnf5 -y copr enable avengemedia/danklinux
dnf5 -y copr enable avengemedia/dms
dnf5 -y install \
    --setopt='copr:copr.fedorainfracloud.org:avengemedia:danklinux.excludepkgs=quickshell*' \
    --setopt='copr:copr.fedorainfracloud.org:avengemedia:dms.excludepkgs=quickshell*' \
    dms \
    dms-cli \
    dgop \
    matugen \
    danksearch \
    cava \
    material-symbols-fonts
dnf5 -y copr remove avengemedia/danklinux
dnf5 -y copr remove avengemedia/dms

# Brand fonts. IBM Plex is in Fedora; Archivo (headings) isn't, so it comes
# from a pinned google/fonts commit with a checksum.
dnf5 -y install ibm-plex-sans-fonts ibm-plex-mono-fonts
archivo_url="https://raw.githubusercontent.com/google/fonts/95f4904fc8bcf26d3420fe315560c96417c6dec7/ofl/archivo"
mkdir -p /usr/share/fonts/archivo
curl -fsSL -o /usr/share/fonts/archivo/Archivo-VF.ttf "${archivo_url}/Archivo%5Bwdth,wght%5D.ttf"
curl -fsSL -o /usr/share/fonts/archivo/OFL.txt "${archivo_url}/OFL.txt"
echo "0e094a7d3c7c4c25cf1310c4b30014f1dae9332220b1c2c88f4fa996f0b05053  /usr/share/fonts/archivo/Archivo-VF.ttf" | sha256sum -c -
fc-cache -f /usr/share/fonts/archivo
