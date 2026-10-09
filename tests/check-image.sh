#!/usr/bin/env bash
# Smoke-test a built PugPal image without booting it.
#   tests/check-image.sh [image]      (default: localhost/pugpal:latest)
# Runs the checks inside a throwaway rootless container; prints one line per
# check and exits non-zero if any failed.
set -euo pipefail
image="${1:-localhost/pugpal:latest}"

podman run --rm -i --entrypoint /usr/bin/bash "$image" -s <<'INNER'
fail=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi; }

echo "== packages"
for p in hyprland hyprlock hypridle xdg-desktop-portal-hyprland uwsm waybar kitty \
         gnome-shell gdm \
         lutris steam gamescope gamemode mangohud vulkan-loader.i686 mesa-vulkan-drivers.i686 protonplus \
         docker-ce docker-compose-plugin docker-buildx-plugin code libvirt-daemon-kvm virt-manager neovim gh scrcpy \
         google-chrome-stable 1password 1password-cli coolercontrol coolercontrold obs-studio proton-vpn-gnome-desktop; do
    check "$p" rpm -q "$p"
done
check "no system wine (Lutris uses GE-Proton runners)" bash -c '! rpm -q wine-core'
check "hyprland pinned to 0.56" bash -c 'rpm -q --qf "%{VERSION}" hyprland | grep -q "^0\.56"'

echo "== /opt is a real directory with the /opt apps in it"
check "/opt is not a symlink"          test ! -L /opt
check "chrome binary"                  test -x /opt/google/chrome/chrome
check "1Password binary"               test -x /opt/1Password/1password
check "1Password helper is setgid"     test -g /opt/1Password/1Password-BrowserSupport
check "onepassword sysusers GID matches helper's group" bash -c '
    gid=$(stat -c %g /opt/1Password/1Password-BrowserSupport)
    grep -qx "g onepassword ${gid}" /usr/lib/sysusers.d/pugpal-onepassword.conf'

echo "== sessions"
check "Hyprland wayland session"  bash -c 'ls /usr/share/wayland-sessions/ | grep -qi hyprland'
check "GNOME wayland session"     bash -c 'ls /usr/share/wayland-sessions/ | grep -qi gnome'

echo "== services"
for u in docker.service coolercontrold.service libvirtd.socket vitals-recorder.timer pugpal-groups.service me.proton.vpn.split_tunneling.service gdm.service; do
    check "$u enabled" systemctl is-enabled "$u"
done

echo "== no build-time repos left behind"
check "no third-party repo files" bash -c '! ls /etc/yum.repos.d/ | grep -Ei "docker|vscode|chrome|1password|proton|steam|copr.*(hyprland|protonplus|coolercontrol|scrcpy)"'

exit $fail
INNER
