#!/usr/bin/env bash
# Install PugPal onto an external USB disk with `bootc install to-disk`.
#   scripts/install-to-disk.sh [--dry-run] [--image REF]
#
# Lists USB disks only, refuses any disk that holds a mounted system path,
# and asks you to type the disk's serial before wiping it. The disk is
# addressed by its /dev/disk/by-id path, never by sdX, so a renamed device
# can't be hit by mistake. --dry-run goes through the picker and checks and
# prints the commands, but runs nothing that changes the system (no sudo).
set -euo pipefail

image="ghcr.io/jamesikanos/pugpal:latest"
dry_run=0

usage() { sed -n '2,10s/^# \{0,1\}//p' "$0"; }

while (($#)); do
    case "$1" in
        -n|--dry-run) dry_run=1 ;;
        -i|--image)   image="${2:?--image needs a value}"; shift ;;
        -h|--help)    usage; exit 0 ;;
        *)            echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

die()  { echo "error: $*" >&2; exit 1; }
info() { echo ":: $*"; }

# Field of a whole disk, trimmed (lsblk pads MODEL with spaces).
field() { lsblk -dn -o "$2" "$1" | sed 's/^ *//; s/ *$//'; }

# Mountpoints anywhere on the disk (its partitions included).
mounts_of() { lsblk -nr -o MOUNTPOINTS "$1" | tr ' ' '\n' | sed '/^$/d'; }

# A disk is off-limits if anything on it is mounted outside /run/media
# (/, /boot, /home, /var, swap...). Desktop automounts are fine to unmount.
is_system_disk() {
    local m
    while read -r m; do
        [[ -z $m || $m == /run/media/* ]] && continue
        return 0
    done < <(mounts_of "$1")
    lsblk -nr -o FSTYPE "$1" | grep -qx swap && return 0
    return 1
}

# Stable /dev/disk/by-id path for a whole disk; prefers the usb- link.
by_id_path() {
    local dev="$1" link best=""
    for link in /dev/disk/by-id/*; do
        [[ $link == *-part* ]] && continue
        [[ $(readlink -f "$link") == "$dev" ]] || continue
        [[ $link == */usb-* ]] && { echo "$link"; return; }
        [[ -z $best ]] && best="$link"
    done
    [[ -n $best ]] && echo "$best"
}

# ---- pick a disk -----------------------------------------------------------

candidates=() labels=()
while read -r dev; do
    [[ $(field "$dev" TRAN) == usb ]] || continue
    if is_system_disk "$dev"; then
        info "skipping $dev ($(field "$dev" MODEL)): holds a mounted system path"
        continue
    fi
    candidates+=("$dev")
    labels+=("$(printf '%-9s %8s  %-24s serial %s' "$dev" "$(field "$dev" SIZE)" \
        "$(field "$dev" MODEL)" "$(field "$dev" SERIAL)")")
done < <(lsblk -dnp -o NAME -e 7,11)   # skip loop, cdrom

((${#candidates[@]})) || die "no eligible USB disks found"

echo
echo "USB disks:"
PS3=$'\nInstall PugPal onto which disk? (number, or Ctrl-C to quit) '
select label in "${labels[@]}"; do
    [[ -n ${label:-} ]] && break
    echo "pick a number from the list"
done
dev="${candidates[REPLY-1]}"

target="$(by_id_path "$dev")" || true
[[ -n $target ]] || die "$dev has no /dev/disk/by-id link; refusing to use a bare device name"
serial="$(field "$dev" SERIAL)"
[[ -n $serial ]] || die "$dev reports no serial; refusing (can't confirm it safely)"

echo
echo "Selected: $label"
echo "Target:   $target"
echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$dev"
echo

# ---- confirm ---------------------------------------------------------------

if ((dry_run)); then
    info "dry run: skipping confirmation"
else
    echo "EVERYTHING on this disk will be erased."
    read -rp "Type the disk's serial ($serial) to continue: " typed
    [[ $typed == "$serial" ]] || die "serial didn't match; nothing was changed"
fi

run() {
    printf '   '; printf ' %q' "$@"; echo
    ((dry_run)) || "$@"
}

# ---- unmount desktop automounts --------------------------------------------

mapfile -t mounted < <(lsblk -nrp -o NAME,MOUNTPOINTS "$dev" | awk 'NF > 1 {print $1}')
for part in "${mounted[@]}"; do
    info "unmounting $part"
    run udisksctl unmount -b "$part"
done

# ---- install ---------------------------------------------------------------

# Re-check right before the wipe: the by-id link must still be the same disk.
[[ $(readlink -f "$target") == "$dev" && $(field "$dev" SERIAL) == "$serial" ]] \
    || die "$target no longer resolves to the selected disk; aborting"
((dry_run)) || [[ -z $(mounts_of "$dev") ]] || die "$dev still has mounted partitions"

info "installing $image (this pulls the image as root on first run)"
run sudo podman run --rm --privileged --pid=host \
    -v /dev:/dev -v /var/lib/containers:/var/lib/containers \
    --security-opt label=type:unconfined_t \
    "$image" \
    bootc install to-disk --wipe "$target"

if ((dry_run)); then
    info "dry run complete: nothing was changed"
else
    echo
    lsblk -f "$target"
    info "done: boot it from the firmware boot menu and pick the USB disk"
fi
