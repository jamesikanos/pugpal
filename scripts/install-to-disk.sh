#!/usr/bin/env bash
# Install PugPal onto a disk with `bootc install to-disk`.
#   scripts/install-to-disk.sh [--dry-run] [--image REF]
#   scripts/install-to-disk.sh --internal PROFILE [--dry-run] [--image REF]
#
# Default: lists USB disks only (the external test SSD).
# --internal PROFILE: a machine's own disk, for migrating it. PROFILE is the
# machine.toml from the private dotfiles; only the disk whose serial is its
# [install] root_disk_serial is accepted, and never the disk holding its
# [home] uuid - if that home filesystem can't be found, it stops. Run it from
# another system (the SSD), not from the disk being replaced.
#
# Both modes refuse any disk that holds a mounted system path and ask you to
# type the disk's serial before wiping it. The disk is addressed by its
# /dev/disk/by-id path, never by sdX/nvmeXnY, so a renamed device can't be
# hit by mistake. --dry-run goes through the checks and prints the commands,
# but runs nothing that changes the system (no sudo).
set -euo pipefail

image="ghcr.io/jamesikanos/pugpal:latest"
dry_run=0
profile=""

usage() { sed -n '2,17s/^# \{0,1\}//p' "$0"; }

while (($#)); do
    case "$1" in
        -n|--dry-run) dry_run=1 ;;
        -i|--image)   image="${2:?--image needs a value}"; shift ;;
        --internal)   profile="${2:?--internal needs the machine.toml}"; shift ;;
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

# Stable /dev/disk/by-id path for a whole disk; prefers a link naming the
# serial (readable), then the usb- link.
by_id_path() {
    local dev="$1" serial link best=""
    serial="$(field "$dev" SERIAL)"
    for link in /dev/disk/by-id/*; do
        [[ $link == *-part* || $link == *_1 ]] && continue
        [[ $(readlink -f "$link") == "$dev" ]] || continue
        [[ -n $serial && $link == *"$serial" ]] && { echo "$link"; return; }
        [[ $link == */usb-* ]] && best="$link"
        [[ -z $best ]] && best="$link"
    done
    [[ -n $best ]] && echo "$best"
}

# Whole disk holding the filesystem with this UUID (empty if none).
disk_with_uuid() {
    local part
    part="$(lsblk -nrp -o NAME,UUID | awk -v u="$1" '$2 == u {print $1; exit}')"
    [[ -z $part ]] || lsblk -ndp -o PKNAME "$part" | sed 's/ //g'
}

# ---- internal mode: the profile says which disk ----------------------------

want_serial="" home_uuid="" home_disk=""
if [[ -n $profile ]]; then
    [[ -f $profile ]] || die "no such profile: $profile"
    read -r want_serial home_uuid < <(python3 -c '
import sys, tomllib
p = tomllib.load(open(sys.argv[1], "rb"))
print(p.get("install", {}).get("root_disk_serial", "-"), p.get("home", {}).get("uuid", "-"))' "$profile")
    [[ $want_serial != - ]] || die "$profile has no [install] root_disk_serial"
    [[ $home_uuid != - ]] || die "$profile has no [home] uuid; refusing (can't prove which disk is home)"
    home_disk="$(disk_with_uuid "$home_uuid")"
    [[ -n $home_disk ]] || die "home filesystem $home_uuid not found; refusing (can't prove which disk is home)"
    info "home disk (never touched): $home_disk  $(field "$home_disk" MODEL)  serial $(field "$home_disk" SERIAL)"
    [[ $(field "$home_disk" SERIAL) != "$want_serial" ]] \
        || die "the profile's root disk serial is the home disk's; fix $profile"
fi

# ---- pick a disk -----------------------------------------------------------

candidates=() labels=()
while read -r dev; do
    if [[ -n $profile ]]; then
        [[ $(field "$dev" SERIAL) == "$want_serial" ]] || continue
        [[ $dev != "$home_disk" ]] || die "$dev is the home disk; refusing"
    else
        [[ $(field "$dev" TRAN) == usb ]] || continue
    fi
    if is_system_disk "$dev"; then
        info "skipping $dev ($(field "$dev" MODEL)): holds a mounted system path"
        continue
    fi
    candidates+=("$dev")
    labels+=("$(printf '%-9s %8s  %-24s serial %s' "$dev" "$(field "$dev" SIZE)" \
        "$(field "$dev" MODEL)" "$(field "$dev" SERIAL)")")
done < <(lsblk -dnp -o NAME -e 7,11)   # skip loop, cdrom

if [[ -n $profile ]]; then
    ((${#candidates[@]} == 1)) || die "found ${#candidates[@]} usable disks with serial $want_serial (want exactly 1)"
else
    ((${#candidates[@]})) || die "no eligible USB disks found"
fi

echo
[[ -n $profile ]] && echo "The profile's root disk:" || echo "USB disks:"
if [[ -n $profile ]]; then
    label="${labels[0]}"; dev="${candidates[0]}"   # exactly one, by serial
    echo "  $label"
else
    PS3=$'\nInstall PugPal onto which disk? (number, or Ctrl-C to quit) '
    select label in "${labels[@]}"; do
        [[ -n ${label:-} ]] && break
        echo "pick a number from the list"
    done
    dev="${candidates[REPLY-1]}"
fi

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
if [[ -n $profile ]]; then
    echo "Kept, not touched (home):"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$home_disk"
    echo
fi

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
if [[ -n $profile ]]; then
    [[ $(disk_with_uuid "$home_uuid") != "$dev" ]] || die "$dev now holds the home filesystem; aborting"
fi
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
    [[ -n $profile ]] && what="this disk ($serial)" || what="the USB disk"
    info "done: reboot, and pick $what in the firmware boot menu (F11)"
fi
