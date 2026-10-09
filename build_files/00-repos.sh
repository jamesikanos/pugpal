#!/bin/bash
# Third-party repos and COPRs used during the build. They are all removed again
# in 90-cleanup.sh: the running system updates by pulling a new image, never by
# dnf, so leaving repos enabled would only invite drift.

set -euxo pipefail

cp -v /ctx/repos/*.repo /etc/yum.repos.d/

# sdegler/hyprland: maintained successor to solopasha's COPR; builds F44+.
# Fedora's own repos do not ship Hyprland.
for copr in \
    sdegler/hyprland \
    wehagy/protonplus \
    codifryed/CoolerControl \
    zeno/scrcpy; do
    dnf5 -y copr enable "$copr"
done
