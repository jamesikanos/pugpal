# PugPal recipes (imported by ujust via 60-custom.just).

# Reclaim disk now: Docker build cache/images/stopped containers unused for 7+ days, unused Flatpak runtimes. Never Docker volumes.
pugpal-clean:
    sudo /usr/libexec/pugpal-prune

# Re-apply this machine's profile from ~/pugpal-dotfiles (kernel arguments, hostname, fan curves). Reboot afterwards if kernel arguments changed.
pugpal-machine:
    sudo /usr/libexec/pugpal-setup machine --dotfiles "$HOME/pugpal-dotfiles"
