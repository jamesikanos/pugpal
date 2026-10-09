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

# From the package audit of the old install. Node 22 to match it (nvm in
# /home covers other versions); Kubernetes/Azure tooling.
dnf5 -y install \
    nodejs22 \
    nodejs22-npm \
    yarnpkg \
    helm \
    kubernetes1.35-client \
    azure-cli

# minikube isn't in Fedora; the old install used the upstream RPM. Pinned,
# checksum-verified.
minikube_ver=1.38.1
curl -fsSL -o /tmp/minikube.rpm \
    "https://github.com/kubernetes/minikube/releases/download/v${minikube_ver}/minikube-${minikube_ver}-0.x86_64.rpm"
echo "546e74cf7474f1facfac5eb68a981d81dc93820211fd94980b977969730ea3e3  /tmp/minikube.rpm" | sha256sum -c -
dnf5 -y install /tmp/minikube.rpm
rm -f /tmp/minikube.rpm
