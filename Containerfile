# v4l2loopback (virtual cameras) comes prebuilt from Universal Blue's akmods,
# which only fits one exact kernel: the Justfile passes the tag matching the
# base image's kernel. (The default floats; dnf fails loudly on a mismatch.)
ARG AKMODS_IMAGE=ghcr.io/ublue-os/akmods:main-44
FROM ${AKMODS_IMAGE} AS akmods

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

# whisper.cpp's whisper-cli with the Vulkan backend: GPU speech-to-text for
# pugrec's transcripts (AMD via RADV, no ROCm/CUDA). Not packaged in Fedora.
# Static ggml, so only the binary is carried over. GGML_NATIVE=OFF: CI's CPU is
# not ours; x86-64-v3 (AVX2/FMA) for the CPU fallback instead.
FROM ghcr.io/ublue-os/silverblue-main:44 AS whisper-builder
ARG WHISPER_VERSION=1.9.4
ARG WHISPER_SHA256=57e280cee375ab02425b806ad5146b99f6eb9357e3c2b31357c8a6af2e2e44ae
RUN --mount=type=cache,dst=/var/cache \
    dnf5 -y install --setopt=install_weak_deps=False \
        cmake gcc-c++ make vulkan-headers vulkan-loader-devel glslc spirv-headers-devel && \
    curl -fsSL -o /tmp/whisper.tar.gz \
        "https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v${WHISPER_VERSION}.tar.gz" && \
    echo "${WHISPER_SHA256}  /tmp/whisper.tar.gz" | sha256sum -c - && \
    mkdir /src && tar -xzf /tmp/whisper.tar.gz -C /src --strip-components=1 && \
    cmake -S /src -B /src/build -DCMAKE_BUILD_TYPE=Release \
        -DGGML_VULKAN=ON -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF \
        -DGGML_AVX=ON -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON \
        -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON && \
    cmake --build /src/build -j"$(nproc)" --target whisper-cli && \
    mkdir -p /out && install -m 755 /src/build/bin/whisper-cli /out/whisper-cli && \
    install -m 644 /src/LICENSE /out/LICENSE

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

# Changes to build_files/ and system_files/ reach the build only through the
# bind mount below, which podman's layer cache does NOT see - an edited script
# could silently reuse the old layer. The Justfile passes a hash of both trees
# so any change invalidates the cache from here on.
ARG CTX_HASH=unset

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=quickshell-builder,source=/out,target=/rpms/quickshell \
    --mount=type=bind,from=whisper-builder,source=/out,target=/bins/whisper \
    --mount=type=bind,from=akmods,source=/rpms,target=/rpms/akmods \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
