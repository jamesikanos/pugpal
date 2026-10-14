#!/bin/bash
# Shell and everyday CLI tools, from an audit of what James hand-installed on
# the old Fedora (dnf repoquery --userinstalled vs this image).
# zsh is James's LOGIN SHELL - without it the account can't log in after
# `bootc switch`. oh-my-zsh, .zshrc and plugins live in /home and carry over.
# git: not in the ublue base, and the dotfiles install needs it.
# NetworkManager-tui: nmtui, for Wi-Fi in the text-mode first-boot setup.
# restic: snapshot backups of the home disk (the job itself is per-machine, in
# the dotfiles' machine profile).

set -euxo pipefail

dnf5 -y install \
    zsh \
    git \
    NetworkManager-tui \
    fastfetch \
    bat \
    yq \
    dos2unix \
    plocate \
    nmap \
    nmap-ncat \
    python3-pip \
    qpdf \
    python3-img2pdf \
    tesseract \
    unoconv \
    v4l-utils \
    uvcdynctrl \
    rocminfo \
    restic
# (jq, ripgrep, tmux, htop already come with the base image.)
