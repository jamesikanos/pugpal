#!/bin/bash
# Development: Docker CE (not podman-docker - existing compose workflows
# expect the real daemon), VS Code, libvirt/QEMU, and CLI tools.
# Distrobox and podman already ship in base-main for anything ad hoc.

set -euxo pipefail

dnf5 -y install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

dnf5 -y install \
    code \
    libvirt \
    virt-manager \
    qemu-kvm \
    neovim \
    gh \
    android-tools \
    scrcpy
