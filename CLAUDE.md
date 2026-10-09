# PugPal

A personal, image-based Fedora desktop: Universal Blue `silverblue-main` +
Hyprland + gaming (Lutris/Steam) + dev tooling (Docker CE, VS Code, libvirt).
Built as an OCI image from this repo, signed, published to
`ghcr.io/jamesikanos/pugpal`, and booted with bootc. Named after two pugs,
Vinnie (black) and Jesse (fawn).

**The look and personal config live in a separate PRIVATE repo:**
[jamesikanos/pugpal-dotfiles](https://github.com/jamesikanos/pugpal-dotfiles)
(cloned here as the gitignored `dotfiles/`). Its CLAUDE.md has the install
steps. This repo = the OS image; that repo = the user layer on top.

**This repo is public.** Nothing secret or machine-specific goes in it: no keys,
no disk UUIDs, no device names, no network/VPN config. Machine specifics live
in the gitignored `local/machine.md`.

## Why it's built this way

| Decision | Why |
| --- | --- |
| `ghcr.io/ublue-os/silverblue-main:44` as base | ublue's base-main stack (codecs via negativo17, ujust, distrobox, signing policy) **plus stock GNOME/GDM**. Plain `base-main` has no desktop at all - verified by inspecting the image, not assumed. GNOME stays as the fallback session. |
| ublue `image-template` (Containerfile + shell) | Universal Blue's recommended path. No abstraction layer over plain podman/dnf; BlueBuild was considered and rejected for that reason. |
| Hyprland from COPR `sdegler/hyprland` | Fedora's repos have no Hyprland. sdegler's is the maintained successor to solopasha's (which stopped at F43) and builds F44/F45. |
| Shell: **DankMaterialShell** on **Quickshell** | One QML shell (bar, launcher, notifications, lock screen, OSDs, polkit agent) themed from one palette. DMS chosen over Caelestia/end-4: official Fedora packaging, most complete, built to be themed. (Noctalia left Quickshell in 2026.) |
| Quickshell built **from a pinned upstream commit** | James wants it bleeding-edge without waiting on a COPR. Built as our own RPM in the `quickshell-builder` stage against the image's exact Qt (it uses Qt private APIs; the daily build rebuilds it on every Qt update). Renovate proposes commit bumps. |
| Hyprland pinned to `0.56*` | Hyprland changes config format/semantics between minors (0.56 already generates `~/.config/hypr/hyprland.lua` - the Lua config is here, not upcoming). Bump only after the user config is checked against the new version. |
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
  quickshell/quickshell.spec  our Quickshell RPM (pinned commit), built in the Containerfile's builder stage
  10-desktop.sh          Hyprland + Wayland tools
  15-shell.sh            our Quickshell RPM + DankMaterialShell (avengemedia COPRs, this stage only) + brand fonts
  20-gaming.sh           Lutris, Steam, gamescope, gamemode, MangoHud, 32-bit Mesa, ProtonPlus
  30-dev.sh              Docker CE, VS Code, libvirt/QEMU, neovim, gh, adb, scrcpy
  40-apps.sh             Chrome, 1Password, CoolerControl, OBS, ProtonVPN; onepassword sysusers
  90-cleanup.sh          enable services, remove every build-time repo/COPR
system_files/            copied over / at build time
  usr/libexec/pugpal-groups + pugpal-groups.service   wheel users -> docker, libvirt
  usr/bin/vitals-record + vitals-recorder.{service,timer}  30s vitals log for freeze diagnosis
disk_config/disk.toml    image-builder blueprint for the CI test qcow2 (throwaway pug user)
branding/                palette.toml, logo SVGs, tools/ (cutout.py, wallpaper.py - run from local/venv-branding)
dotfiles/                gitignored: the separate PRIVATE pugpal-dotfiles repo (the look)
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
5. **Hyprland Lua config** - 0.56 already uses `hyprland.lua` (seen in the VM's
   autogenerated config). See the pin above.
6. **Polkit agent under Hyprland.** DMS provides one (`Services/PolkitService.qml`),
   so nothing else is needed while DMS runs. `hyprpolkitagent` is still
   installed but deliberately not enabled: its user unit is
   `WantedBy=graphical-session.target` with only a `WAYLAND_DISPLAY` condition,
   so enabling it globally would also start it in GNOME and clash with GNOME
   Shell's agent.

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
   `rpm -qa` and `flatpak list`. (Fan curves from `/etc/coolercontrol` are
   already in pugpal-dotfiles `machine/main-pc/`.)
2. Install stock Fedora Silverblue 44 onto the **root disk only**; leave the
   separate `/home` disk unselected. Create the same username (UID 1000).
3. Add the old home partition to `/etc/fstab` at `/var/home`, reboot.
4. `sudo bootc switch ghcr.io/jamesikanos/pugpal:latest`, reboot.
5. Log into the Hyprland (uwsm) session once (Hyprland writes its default
   `hyprland.lua`), then apply the user layer - see pugpal-dotfiles CLAUDE.md:
   `gh repo clone jamesikanos/pugpal-dotfiles ~/pugpal-dotfiles && ~/pugpal-dotfiles/install.sh`
6. Restore the fan curves: `~/pugpal-dotfiles/machine/main-pc/restore-coolercontrol.sh`.
7. Restore Ollama (stays in `/usr/local`, unit in `/etc/systemd/system`).
8. Check: PodMic RAW and PodMic Tuned both appear as inputs; BRIO mic absent.

## Branding and the look

The look lives in the **private** `dotfiles/` repo (gitignored here): Hyprland
`pugpal.lua` (starts DMS, keybinds) + `pugpal-look.lua` (orange active border,
6px rounding, no shadows, slight blur), the DMS custom theme `pugpal.json` (dark =
Vinnie, light = Jesse) with `cornerRadius: 6` and IBM Plex fonts, a kitty
theme (0.92 opacity), the pug-head launcher icon, the recording script, and
the wallpaper: an illustration someone drew of Vinnie and Jesse years ago,
vector-traced and recoloured (private - it's personal art). James's rule for
pug art: **smooth and cuddly** (faceted/low-poly and photo cutouts were tried
and rejected). Keybinds are listed in the dotfiles CLAUDE.md.

Pug x FieldPal. Palette from the FieldPal site tokens and the pugs themselves:
ink `#16171a` (Vinnie is `#110a09`), Jesse's cream `#f1e4d9` ~ FieldPal
off-white `#f2f0eb`, Jesse's mask `#32231f`, FieldPal orange `#E8480F` /
`#ff6b2c` (on dark). Slightly rounded (6px everywhere - pure FieldPal squares felt harsh on a desktop), no shadows. Archivo /
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

- **One-command setup "just for James"** (next up, after the end-to-end VM
  test). Flow: stock Silverblue -> `sudo bootc switch ghcr.io/jamesikanos/pugpal:latest
  && systemctl reboot` -> on first login an autostart helper (only if
  `~/pugpal-dotfiles` is missing) opens a terminal running `ujust pugpal-me`,
  which: `gh auth login` (browser, one click - the only way into the private
  repo) -> clone pugpal-dotfiles -> `install.sh` -> restore fan curves
  (sudo once) -> install Flatpaks (Spotify, Flatseal) -> restart PipeWire ->
  set hostname -> write a done-marker. Every step idempotent so a re-run
  resumes. Defaults to James's private repo; others fail at the GitHub login,
  nothing leaks. **Keep the `/var/home` fstab step manual** - a mistake there
  logs into an empty home. Test it in a fresh VM.

- **Renovate app**: `.github/renovate.json5` has a custom manager for the
  Quickshell commit pin, but Renovate only runs once the Renovate GitHub app is
  installed on the repo (James's action). Until then, bump `commit` by hand.
- **Ship a default look for new users** (`/etc/skel`, or a `ujust pugpal-look`
  recipe that applies the dotfiles). Today the look lives only in the private
  dotfiles repo and is applied by hand.
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

## Troubleshooting log

Dated entries, newest first. What broke, why, what fixed it.

- **2026-10-09** - The first Flatpak installed on a fresh system (Spotify, in
  the VM) didn't appear in the DMS launcher until DMS restarted; the second
  (Flatseal) appeared instantly. DMS watches the XDG app dirs that exist at
  startup, and `/var/lib/flatpak/exports/share/applications` only appears with
  the first install. Fixed with tmpfiles (system + user) creating the dirs at
  boot. Also: system Flatpak installs over SSH fail silently without a polkit
  prompt - use sudo or a graphical terminal.
- **2026-10-09** - **First VM boot passed** (KVM, virgl on the RX 9070 XT):
  Hyprland session up, groups service worked, `docker run hello-world` without
  sudo, 1Password GIDs 921-923 correct, all PugPal units active. Known
  failures: `mcelog` (no MCE in VMs - harmless) and `bootloader-update`
  (`bootupctl: Parsing "/sysroot/.bootc-aleph.json": invalid type: null`) -
  probably an artifact of image-builder's install path; re-check on the SSD.
  SSH is off by default (Silverblue), so the VM needs
  `sudo systemctl enable --now sshd` from its console once.
- **2026-10-09** - **`just vm-ssh` ran part of a command on the dev PC.**
  `{{ cmd }}` was spliced unquoted into the ssh line, so `a; b` sent only `a`
  to the VM and ran `b` locally. Only read-only commands were affected. Fixed
  with `{{ quote(cmd) }}`. Lesson: verify `hostname`/`id` output when a VM
  check looks suspiciously like the host.
- **2026-10-09** - CI test-disk builds failed with `mount:
  /run/osbuild/containers/storage: permission denied` on **ubuntu-26.04**
  runners, with both bootc-image-builder and image-builder-cli, and with
  AppArmor unconfined. **ubuntu-24.04 works.** `build-disk.yml` now calls
  image-builder-cli directly (bootc-image-builder-action is deprecated and
  its replacement takes no blueprint); blueprints there reject
  `customizations.filesystem` for bootc.
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
