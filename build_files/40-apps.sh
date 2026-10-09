#!/bin/bash
# Desktop apps carried over from the old Fedora install.
#
# Chrome and 1Password install into /opt. The Containerfile makes /opt a real
# directory in the image (instead of the default symlink to /var/opt), so
# their files are part of the immutable image and survive deployments.

set -euxo pipefail

dnf5 -y install \
    google-chrome-stable \
    1password \
    1password-cli \
    coolercontrol \
    coolercontrold \
    obs-studio \
    proton-vpn-gnome-desktop \
    lm_sensors

# 1Password's browser-integration helper is setgid "onepassword". The group was
# created by the RPM scriptlet during this build, but on a deployed system
# /etc/group is a three-way-merged config file and may never receive it.
# Declare it to systemd-sysusers with the *same* GID the files were chowned to,
# so the setgid bit keeps pointing at the right group.
op_gid=$(getent group onepassword | cut -d: -f3)
echo "g onepassword ${op_gid}" > /usr/lib/sysusers.d/pugpal-onepassword.conf
