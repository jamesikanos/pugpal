# PugPal

A personal, image-based Fedora desktop: Universal Blue `silverblue-main` +
Hyprland + gaming (Lutris/Steam) + dev tooling (Docker CE, VS Code, libvirt).
Built as an OCI image from this repo, signed, published to
`ghcr.io/jamesikanos/pugpal`, and booted with bootc. Named after two pugs,
Vinnie (black) and Jesse (fawn).

**This repo is public.** Nothing secret or machine-specific goes in it: no keys,
no disk UUIDs, no device names, no network/VPN config. Machine specifics live
in the gitignored `local/machine.md`.

## Why it's built this way

| Decision | Why |
| --- | --- |
| `ghcr.io/ublue-os/silverblue-main:44` as base | ublue's base-main stack (codecs via negativo17, ujust, distrobox, signing policy) **plus stock GNOME/GDM**. Plain `base-main` has no desktop at all - verified by inspecting the image, not assumed. GNOME stays as the fallback session. |
| ublue `image-template` (Containerfile + shell) | Universal Blue's recommended path. No abstraction layer over plain podman/dnf; BlueBuild was considered and rejected for that reason. |
| Hyprland from COPR `sdegler/hyprland` | Fedora's repos have no Hyprland. sdegler's is the maintained successor to solopasha's (which stopped at F43) and builds F44/F45. |
| Hyprland pinned to `0.56*` | Upstream is moving the config to Lua. Bump only after migrating the config. |
| Lutris as an **RPM**, not Flatpak | The Flatpak keeps data under `~/.var/app`; the RPM keeps the existing `~/.config/lutris`, `~/.local/share/lutris/runners` (GE-Proton) and the WoW prefix in `~/Games` working untouched. |
| Steam from negativo17 `fedora-steam` | The base ships negativo17 multimedia and **no RPM Fusion** (the template's comment claiming otherwise is stale). One vendor, no codec-stack mixing. |
| Docker CE, not podman-docker | Existing compose workflows expect the real daemon. Podman is still there. |
| Immutable `/opt` (`rm /opt && mkdir /opt`) | Fedora atomic symlinks `/opt -> /var/opt`; files an RPM writes there at build time are lost on deploy. Chrome and 1Password install to `/opt`. Side effect: `/opt` is read-only at runtime - put user-installed stuff in `~/.local` or `/usr/local` (= `/var/usrlocal`, writable). |

## Layout

```
Containerfile            FROM silverblue-main:44, immutable /opt, runs build.sh, bootc lint
image-template.env       IMAGE_NAME=pugpal, REPO_ORGANIZATION=jamesikanos
Justfile                 upstream template recipes (build, rechunk, qcow2, vm)
build_files/
  build.sh               overlays system_files/, runs NN-*.sh in order
  repos/*.repo           third-party repo definitions (copied in, removed at the end)
  00-repos.sh            installs repo files, enables COPRs
  10-desktop.sh          Hyprland + Wayland tools
  20-gaming.sh           Lutris, Steam, gamescope, gamemode, MangoHud, 32-bit Mesa, ProtonPlus
  30-dev.sh              Docker CE, VS Code, libvirt/QEMU, neovim, gh, adb, scrcpy
  40-apps.sh             Chrome, 1Password, CoolerControl, OBS, ProtonVPN; onepassword sysusers
  90-cleanup.sh          enable services, remove every build-time repo/COPR
system_files/            copied over / at build time
  usr/libexec/pugpal-groups + pugpal-groups.service   wheel users -> docker, libvirt
  usr/bin/vitals-record + vitals-recorder.{service,timer}  30s vitals log for freeze diagnosis
disk_config/disk.toml    bootc-image-builder config for the test qcow2
.githooks/pre-commit     gitleaks secret scan (enable: git config core.hooksPath .githooks)
.tools/                  gitignored: just, cosign, gitleaks binaries
local/                   gitignored: machine-specific notes
```

**Rule:** a new package goes in the stage that owns its area. A new third-party
repo gets a file in `build_files/repos/` **and** a removal line in `90-cleanup.sh`;
a new COPR goes in both COPR lists (`00-repos.sh` and `90-cleanup.sh`).

## Hard rule: the dev PC is hands-off

Development happens on James's daily-driver Fedora. Nothing may change it:

- No `sudo`, no `dnf`/`rpm` installs, no `/etc` edits, no system services, no
  libvirt definitions. If something seems to need one, **stop and ask**.
- Tools run from `.tools/` (`.tools/just`, `.tools/cosign`, `.tools/gitleaks`).
- Image builds are **rootless** (`.tools/just build`).
- Bootable disk images need rootful bootc-image-builder, so **they are built in
  CI** (`build-disk.yml`) and downloaded into `output/` - never `just build-qcow2`
  locally (it calls sudo).
- The test VM runs as a plain user QEMU process (`just vm`), user-mode networking.
- The single exception, later: writing the image to an external test SSD needs one
  explicit `sudo bootc install to-disk`, only with James's go-ahead after the
  device is confirmed with `lsblk` (transport `usb`, model, size).

## Build, test, release

```bash
.tools/just build                    # rootless local build -> localhost/pugpal:latest
podman run --rm -it localhost/pugpal:latest bash   # poke around inside
.tools/just test                     # smoke-test the built image (tests/check-image.sh)
.tools/just check                    # Justfile syntax
.tools/just fetch-disk               # download the newest CI test qcow2 into output/
.tools/just vm                       # boot it (GL window); `just vm none` = headless
.tools/just vm-ssh                   # ssh in as the throwaway pug user (password pugpal)
.tools/just vm-reset                 # discard the VM's changes
```

CI (`.github/workflows/build.yml`) builds on every push to `main` and daily
(10:05 UTC, picks up Fedora updates), runs `tests/check-image.sh`, rechunks, pushes to `ghcr.io/jamesikanos/pugpal`, and signs with cosign
(`SIGNING_SECRET` repo secret = `cosign.key`; `cosign.pub` is committed).

`build-disk.yml` (manual) turns the published image into a qcow2 artifact for
the VM.

On an installed machine:

```bash
sudo bootc switch ghcr.io/jamesikanos/pugpal:latest   # first time
sudo bootc upgrade && systemctl reboot                # updates
sudo bootc rollback                                   # previous deployment
bootc status
```

## Atomic gotchas (and what we did)

1. **`/opt`** - made immutable in the Containerfile (see table above).
2. **Groups.** Groups that RPM scriptlets create at build time can end up only in
   `/usr/lib/group` (read via nss-altfiles); `usermod -aG` edits `/etc/group` and
   fails for them. `pugpal-groups.service` copies the `docker`/`libvirt` lines
   into `/etc/group` and adds wheel users, every boot, idempotently.
3. **Setgid groups (1Password) and sysusers.** 1Password ships three setgid
   binaries (`1Password-BrowserSupport`, `/usr/bin/op`, `1password-mcp`) whose
   scriptlets run a plain `groupadd` - which allocated GIDs **1000-1002**, the
   user range, colliding with the real user's own group (GID 1000). `40-apps.sh`
   now pre-creates them as system groups with **fixed GIDs 921/922/923**, and
   `system_files/usr/lib/sysusers.d/pugpal.conf` declares the same GIDs (plus
   `docker`) so deployed systems recreate them even though `/etc/group` is
   three-way-merged on upgrade. Never change those numbers on an installed
   system. `bootc container lint` flags any new group missing from sysusers.d.
4. **No dnf at runtime.** All repos are removed in `90-cleanup.sh`. The system
   updates by pulling new images. For one-offs: Distrobox, or (sparingly)
   `rpm-ostree install`.
5. **Hyprland Lua config** - see the pin above.

## Version bumps

- **Fedora:** change the `FROM ...:44` tag, check every COPR/third-party repo
  has the new release (`$releasever` in repo files), build, test in the VM.
- **Hyprland:** change `'hyprland-0.56*'` in `10-desktop.sh` after the user
  config is migrated; test in the VM first.

## WoW / Lutris constraints

WoW (Anniversary + Classic Era) runs through plain Lutris with a GE-Proton
runner. Everything that matters lives in `/home`, which is preserved across the
migration: the prefix (`~/Games/battlenet`), runners
(`~/.local/share/lutris/runners/wine/`), and Lutris config (`~/.config/lutris`).
The image only needs to provide Lutris, the 32-bit Mesa/Vulkan stack,
gamemode, MangoHud and gamescope. Addon tooling is documented in
`~/Games/CLAUDE.md`.

## Testing ladder

1. Rootless container build + inspection (no system impact).
2. VM: CI qcow2 + `just vm` (QEMU, virtio-gpu-gl so Hyprland renders on the
   host GPU). Covers boot, sessions, services, apps, theming. Not WoW/GPU perf -
   the host has one GPU and no iGPU, so no passthrough.
3. Bare metal from an external USB SSD (`bootc install to-disk`), real `/home`
   **not** mounted read-write - copy the WoW prefix instead.
4. Migration of the real machine.

## Migration runbook (generic; specifics in `local/machine.md`)

1. Back up from the root disk into `/home`: custom units in
   `/etc/systemd/system`, `/usr/local/bin`, NetworkManager connections,
   `rpm -qa` and `flatpak list`.
2. Install stock Fedora Silverblue 44 onto the **root disk only**; leave the
   separate `/home` disk unselected. Create the same username (UID 1000).
3. Add the old home partition to `/etc/fstab` at `/var/home`, reboot.
4. `sudo bootc switch ghcr.io/jamesikanos/pugpal:latest`, reboot.
5. Restore Ollama (stays in `/usr/local`, unit in `/etc/systemd/system`).
6. Pick the Hyprland (uwsm) session in GDM.

## Branding (phase 2)

Pug x FieldPal. Palette from the FieldPal site tokens and the pugs themselves:
ink `#16171a` (Vinnie is `#110a09`), Jesse's cream `#f1e4d9` ~ FieldPal
off-white `#f2f0eb`, Jesse's mask `#32231f`, FieldPal orange `#E8480F` /
`#ff6b2c` (on dark). Hard rectangles, `rounding = 0`, no shadows. Archivo /
IBM Plex Sans / IBM Plex Mono. The theme itself lives in a separate, private
dotfiles repo; this image ships only the tools and fonts.
PugPal is a personal project, not a FieldPal product.

## Git conventions

- `main` for now; feature branches + PRs later.
- Small commits, one logical change each, so `git revert` undoes exactly one
  thing. Conventional Commits style (`feat(gaming): ...`, `fix: ...`), with a
  body that says **why**.
- Commit email is the GitHub noreply address (repo-local config).
- Commit 1 is the unmodified upstream template, so `git diff <that> -- <file>`
  shows exactly what PugPal changed.

## Backlog (future work, not started)

- **Quickshell as the shell layer** (instead of Waybar + mako + fuzzel +
  hyprlock styled separately). One QML shell = bar, launcher, notifications,
  lock screen, OSDs, all driven by `branding/palette.toml`. Plan: fork an
  existing Quickshell shell James likes (Caelestia / Noctalia /
  DankMaterialShell / end-4 illogical-impulse) into the private dotfiles repo
  and restyle it; don't write one from scratch. Packaging: Fedora 44 has an old
  snapshot (0.2.1); COPR `errornointernet/quickshell` has 0.3.2 with F44
  builds - pin it like Hyprland. Check the chosen shell's Hyprland version
  requirements against the 0.56 pin. The updates-behind indicator below would
  be a Quickshell widget.

- **"Updates behind" indicator on the desktop.** James wants a visible alert
  showing how many updates the running system is behind. Ideas:
  - A Waybar custom module (plus a GNOME equivalent for the fallback session)
    that compares the booted image digest/version (`bootc status --json`) with
    the newest `ghcr.io/jamesikanos/pugpal` tag, e.g. "3 builds behind", or
    "update staged - reboot to apply" when `rpm-ostreed-automatic` has already
    staged one.
  - Include Flatpak updates (`flatpak remote-ls --updates`) in the count.
  - A mako notification when an update is staged, so a reboot isn't forgotten.
    Matters because image apps (e.g. Chrome) only update on reboot.
  - Must not poll ghcr.io aggressively; something like hourly via a user
    systemd timer that writes a small state file the bar reads.
- **Chrome: image vs Flatpak** - undecided. Image Chrome updates only on reboot
  but keeps 1Password desktop integration; Flatpak updates live but 1Password
  doesn't officially support sandboxed browsers. Leaning image + regular reboots.
- **Better pug cutouts** for wallpapers: the flood-fill cutout keeps the
  off-white studio floor (too close to Jesse's coat colour). Use an ML
  background remover (e.g. rembg in a venv under `local/`).

## Troubleshooting log

Dated entries, newest first. What broke, why, what fixed it.

- **2026-10-09** - CI qcow2 build failed: `cannot build manifest: failed to
  initialize bootc distro: missing required info: DefaultRootFs`. The image
  never declared an install filesystem (the template's local recipe hides this
  with `--rootfs=btrfs`). Fixed with
  `system_files/usr/lib/bootc/install/20-pugpal.toml` (btrfs).
- **2026-10-09** - 1Password's scriptlets created `onepassword`,
  `onepassword-cli`, `onepassword-mcp` at **GIDs 1000-1002** - the user range -
  so `/usr/bin/op` would have been setgid to the real user's own group. Now
  fixed system GIDs 921-923 via sysusers.d (see gotcha 3). Note: rpm runs
  systemd-sysusers mid-build, so sysusers.d entries shipped in `system_files`
  take effect *before* later stages' packages install.
- **2026-10-09** - The dev PC had **SVM disabled in the BIOS** (`SVM disabled
  (by BIOS) in MSR_VM_CR`), so there was no `/dev/kvm` and `just vm` fell back
  to unusably slow TCG. James enabled SVM Mode in the BIOS the same day;
  `/dev/kvm` now exists. If it ever disappears (BIOS reset/update), that's
  the first thing to check.
- **2026-10-09** - First build failed: `proton-vpn-daemon`'s `%posttrans` runs
  `systemctl start`, impossible in a container build, and dnf fails the whole
  transaction. Fix: deps normally, the daemon alone with `tsflags=noscripts`,
  enable its unit in `90-cleanup.sh`. Any other package whose scriptlets poke a
  running systemd will need the same treatment.
- **2026-10-09** - Lutris's weak deps pulled ~3 GB of system Wine the old
  install never had. Lutris is now installed with weak deps off, plus an
  explicit list of the recommends the old install did have.
- **2026-10-09** - `base-main:44` has no GNOME/GDM and no RPM Fusion; the plan
  assumed both. Switched to `silverblue-main:44` and negativo17 Steam.
