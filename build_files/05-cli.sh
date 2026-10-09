#!/bin/bash
# Shell and everyday CLI tools, from an audit of what James hand-installed on
# the old Fedora (dnf repoquery --userinstalled vs this image).
# zsh is James's LOGIN SHELL - without it the account can't log in after
# `bootc switch`. oh-my-zsh, .zshrc and plugins live in /home and carry over.
# git: not in the ublue base, and the dotfiles install needs it.

set -euxo pipefail

dnf5 -y install \
    zsh \
    git \
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
    rocminfo
# (jq, ripgrep, tmux, htop already come with the base image.)
