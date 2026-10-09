# PugPal recipes (imported by ujust via 60-custom.just).

# Reclaim disk now: Docker build cache/images/stopped containers unused for 7+ days, unused Flatpak runtimes. Never Docker volumes.
pugpal-clean:
    sudo /usr/libexec/pugpal-prune
