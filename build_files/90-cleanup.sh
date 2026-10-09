#!/bin/bash
# Enable services, then strip the build-time repos so the image never updates
# itself through dnf.

set -euxo pipefail

systemctl enable \
    docker.service \
    coolercontrold.service \
    libvirtd.socket \
    vitals-recorder.timer \
    pugpal-groups.service \
    pugpal-prune.timer \
    me.proton.vpn.split_tunneling.service

for copr in \
    sdegler/hyprland \
    wehagy/protonplus \
    codifryed/CoolerControl \
    zeno/scrcpy; do
    dnf5 -y copr remove "$copr"
done

# Our repo files, plus any that package scriptlets dropped in (Chrome and
# 1Password both add their own).
rm -fv \
    /etc/yum.repos.d/docker-ce.repo \
    /etc/yum.repos.d/vscode.repo \
    /etc/yum.repos.d/google-chrome*.repo \
    /etc/yum.repos.d/1password.repo \
    /etc/yum.repos.d/protonvpn*.repo \
    /etc/yum.repos.d/negativo17-steam.repo

dnf5 clean all
