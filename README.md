# PugPal

A personal Fedora Atomic desktop image: [Universal Blue](https://universal-blue.org/)
`silverblue-main` + Hyprland + Lutris/Steam gaming + Docker/VS Code dev tooling,
built with bootc and named after two pugs, Vinnie and Jesse.

PugPal is a personal project. It borrows FieldPal's colours and fonts but is
not a FieldPal product.

```bash
sudo bootc switch ghcr.io/jamesikanos/pugpal:latest
```

The look and personal config (theme, wallpapers, audio, fan curves) live in
the private [pugpal-dotfiles](https://github.com/jamesikanos/pugpal-dotfiles)
repo, applied on top with its `install.sh`.

Everything else - why it's built this way, layout, build/test commands,
gotchas, migration - is in [CLAUDE.md](CLAUDE.md).

Based on [ublue-os/image-template](https://github.com/ublue-os/image-template)
(Apache-2.0).
