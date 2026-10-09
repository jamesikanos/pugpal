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
    lm_sensors

# ProtonVPN. proton-vpn-daemon's %posttrans ends with `systemctl start`, which
# can never succeed in a container build and fails the whole transaction.
# Install its dependencies normally, then the daemon alone with scriptlets off
# (that posttrans is its only scriptlet: daemon-reload/enable/start), and
# enable its split-tunneling service in 90-cleanup.sh instead.
dnf5 -y install \
    python3-bcc \
    python3-dbus-fast \
    python3-packaging \
    python3-proton-vpn-api-core \
    python3-psutil \
    python3-systemd \
    wireguard-tools
dnf5 -y install --setopt=tsflags=noscripts proton-vpn-daemon
dnf5 -y install proton-vpn-gnome-desktop

# 1Password's browser-integration helper is setgid "onepassword". The group was
# created by the RPM scriptlet during this build, but on a deployed system
# /etc/group is a three-way-merged config file and may never receive it.
# Declare it to systemd-sysusers with the *same* GID the files were chowned to,
# so the setgid bit keeps pointing at the right group.
op_gid=$(getent group onepassword | cut -d: -f3)
echo "g onepassword ${op_gid}" > /usr/lib/sysusers.d/pugpal-onepassword.conf
