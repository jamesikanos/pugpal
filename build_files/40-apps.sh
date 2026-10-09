#!/bin/bash
# Desktop apps carried over from the old Fedora install.
#
# Chrome and 1Password install into /opt. The Containerfile makes /opt a real
# directory in the image (instead of the default symlink to /var/opt), so
# their files are part of the immutable image and survive deployments.

set -euxo pipefail

# 1Password's RPM scriptlets `groupadd` their setgid groups only if missing,
# and a plain groupadd lands in the user range (1000+), colliding with the
# first real user's own group. Pre-create them as system groups with the fixed
# GIDs declared in system_files/usr/lib/sysusers.d/pugpal.conf. rpm usually
# runs systemd-sysusers during earlier stages, which already creates them from
# that file, so only add what's missing - and fail loudly on a wrong GID.
for spec in onepassword:921 onepassword-cli:922 onepassword-mcp:923; do
    name=${spec%%:*} gid=${spec##*:}
    getent group "$name" >/dev/null || groupadd -r -g "$gid" "$name"
    [[ "$(getent group "$name" | cut -d: -f3)" == "$gid" ]]
done

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
