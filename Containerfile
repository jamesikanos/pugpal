# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Build PugPal's Quickshell RPM from a pinned upstream commit, against the same
# base (and so the same Qt) as the final image. Only the RPM is carried over.
FROM ghcr.io/ublue-os/silverblue-main:44 AS quickshell-builder
COPY build_files/quickshell/quickshell.spec /tmp/quickshell.spec
RUN --mount=type=cache,dst=/var/cache \
    dnf5 -y install rpm-build 'dnf5-command(builddep)' && \
    dnf5 -y builddep /tmp/quickshell.spec && \
    mkdir -p /rpmbuild/SOURCES && \
    rpmbuild -bb --undefine=_disable_source_fetch \
        --define "_topdir /rpmbuild" --define "_sourcedir /rpmbuild/SOURCES" \
        /tmp/quickshell.spec && \
    mkdir -p /out && cp /rpmbuild/RPMS/*/quickshell-*.rpm /out/

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
    --mount=type=bind,from=quickshell-builder,source=/out,target=/rpms/quickshell \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
