# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Universal Blue silverblue-main: base-main (Fedora Atomic + codecs + ublue
# tooling) plus stock GNOME/GDM, which is PugPal's fallback session next to
# Hyprland. Plain base-main has no desktop at all. Pinned to the Fedora major;
# bump it on purpose.
FROM ghcr.io/ublue-os/silverblue-main:44

### IMMUTABLE /opt
## Fedora atomic symlinks /opt -> /var/opt, so anything an RPM writes there at
## build time is lost on deployment. Chrome and 1Password install to /opt, so
## make it a real directory that ships as part of the image.
RUN rm /opt && mkdir /opt

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
