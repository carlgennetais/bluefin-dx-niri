# bluefin-dx-niri

A custom [bootc](https://bootc-dev.github.io/bootc/) image: [Bluefin DX](https://projectbluefin.io) with a [niri](https://github.com/YaLTeR/niri) desktop stack layered on top.

Built from [ublue-os/image-template](https://github.com/ublue-os/image-template) — the base image is a published Universal Blue image, and everything in this repo is a layer on top of it.

```bash
sudo bootc switch ghcr.io/carlgennetais/bluefin-dx-niri:stable
sudo systemctl reboot
```

## What Makes this Different

Based on [Bluefin DX](https://projectbluefin.io) — the developer variant of Bluefin — with a niri desktop stack layered on top.

### Desktop Environment

- **[niri](https://github.com/niri-wm/niri)** — scrollable-tiling Wayland compositor, runs as an additional session alongside GNOME
- **[DMS (DankMaterialShell)](https://danklinux.com)** — Material 3-inspired QtQuick shell for niri, auto-starts with the niri session
- **[dms-greeter](https://danklinux.com/docs/dankgreeter/)** — replaces GDM with a greetd-based greeter matching the DMS aesthetic
- **[xwayland-satellite](https://github.com/Supreeeme/xwayland-satellite)** — rootless XWayland for running X11 apps under niri

### Applications (Build-time)

- **[Ghostty](https://ghostty.org)** — GPU-accelerated terminal emulator (`avengemedia/dms` COPR)

### CLI Tools (Homebrew, installed at runtime)

- `bat`, `eza`, `fd`, `rg` — modern replacements for cat/ls/find/grep
- `gh`, `glab` — GitHub and GitLab CLIs
- `starship`, `zoxide` — shell prompt and smarter `cd`
- `htop`, `tmux`, `neovim`

### Keyboard Layouts

- **qwerty-fr** (`us_qwerty-fr`) — registered in the XKB rules, so it is selectable by name in GNOME Settings, niri, and `localectl`
- **qwerty-lafayette** (`lafayette`) — symbol file shipped, select it explicitly

### Removed/Disabled

- `gdm` (replaced by greetd), `alacritty`

### Configuration Changes

- **Display manager**: GDM → greetd, configured to launch `dms-greeter --command niri`
- **systemd user service**: `dms.service` wired to start with `niri.service` for all users

*Last updated: 2026-09-26*

---

## Repository Layout

```
Containerfile                 # base image + the single RUN that calls build.sh
image-template.env            # image name, org, description, default tag, BIB image
Justfile                      # local build / disk image / VM recipes
build_files/
  build.sh                    # main build script (overlay, XKB rules, units)
  niri.sh                     # niri + DMS + greetd package installs
  copr-helpers.sh             # copr_install_isolated helper
system_files/                 # copied verbatim onto / during the build
  etc/greetd/config.toml
  usr/lib/sysusers.d/ , usr/lib/tmpfiles.d/
  usr/share/X11/xkb/symbols/  # custom keyboard layouts
  usr/share/flatpak/preinstall.d/default.preinstall
  usr/share/ublue-os/homebrew/*.Brewfile
  usr/share/ublue-os/just/60-custom.just
disk_config/                  # bootc-image-builder configs (qcow2 / raw / ISO)
```

### Where to add things

| What | Where |
|---|---|
| System package (baked into the image) | `dnf5 install -y pkg` in `build_files/build.sh` |
| Package from a COPR | `copr_install_isolated "owner/repo" pkg` in `build_files/niri.sh` |
| Static config file | drop it at its real path under `system_files/` |
| CLI tool (installed at runtime) | `brew "pkg"` in `system_files/usr/share/ublue-os/homebrew/default.Brewfile` |
| GUI app (installed on first boot) | `[Flatpak Preinstall app.id]` in `system_files/usr/share/flatpak/preinstall.d/default.preinstall` |
| `ujust` recipe | `system_files/usr/share/ublue-os/just/60-custom.just` |
| systemd unit enable/mask | `build_files/build.sh` |

Everything under `system_files/` is copied with `cp -avf` **after** the package installs, so shipped config wins over RPM defaults.

## Local Testing

```bash
just build              # Build the container image
just build-qcow2        # Build a VM disk image
just run-vm-qcow2       # Boot it in a browser-based VM
just check              # Check Justfile syntax
shellcheck -x build_files/*.sh
```

## CI

- `build.yml` — builds and pushes `:stable` on every push to `main`, daily at 10:05 UTC, and validates pull requests. Includes rpm-ostree rechunking for smaller update deltas.
- `build-disk.yml` — manual (`workflow_dispatch`) qcow2 / ISO builds, optionally uploaded to S3.
- `renovate.yml` — self-hosted Renovate every 6h: pins and updates the base image digest and GitHub Action SHAs.
- `validate-shellcheck.yml` — shellcheck on `build_files/` in pull requests.
- `clean.yml` — prunes GHCR images older than 90 days.

Published tags: `stable`, `stable-YYYYMMDD`, `YYYYMMDD`, plus `-<git sha>` variants.

## Image Signing

Signing is skipped automatically until `SIGNING_SECRET` is configured, so builds stay green without it.

1. Generate a key pair:

   ```bash
   cosign generate-key-pair
   ```

   This creates `cosign.key` (private — never commit it, it is in `.gitignore`) and `cosign.pub` (public — commit it).

2. Add the private key to GitHub: Settings → Secrets and variables → Actions → New repository secret, named `SIGNING_SECRET`, with the entire contents of `cosign.key`.

3. Commit the new `cosign.pub`.

The next build signs the pushed image, and `build.yml` picks it up with no further edits. Verify with:

```bash
cosign verify --key cosign.pub ghcr.io/carlgennetais/bluefin-dx-niri:stable
```

## Learn More

- [ublue-os/image-template](https://github.com/ublue-os/image-template) — the template this repo follows
- [Universal Blue Documentation](https://universal-blue.org/)
- [bootc Documentation](https://bootc-dev.github.io/bootc/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
