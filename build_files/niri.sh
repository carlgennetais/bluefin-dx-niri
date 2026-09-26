#!/bin/bash

set -ouex pipefail

###############################################################################
# Niri Desktop Stack
###############################################################################
# Installs niri (scrollable-tiling Wayland compositor) alongside GNOME, plus:
#   - DMS (DankMaterialShell) - Material 3 shell for niri
#   - dms-greeter            - greetd-based greeter (replaces GDM)
#
# Static configuration for these lives in system_files/ and is overlaid by
# build.sh after this script runs:
#   /etc/greetd/config.toml            - greetd session
#   /usr/lib/sysusers.d/greeter.conf   - greeter user (bootc lint)
#   /usr/lib/tmpfiles.d/greetd-dms.conf - greetd /var content (bootc lint)
###############################################################################

# shellcheck source=/dev/null
source /ctx/copr-helpers.sh

echo "::group:: Install niri and Wayland utilities"

# niri: Wayland compositor, installed from source repo for fresher version
# wl-mirror: mirror screen during presentations
# wtype: Wayland keyboard to paste from launcher
# hunspell-fr: French dictionary for electron apps like clickup
# xwayland-satellite: XWayland support
# adw-gtk3-theme: used by DMS to theme gtk system apps
copr_install_isolated "yalter/niri" niri
dnf5 install -y \
  xwayland-satellite \
  wl-mirror \
  wtype \
  hunspell-fr \
  adw-gtk3-theme

echo "niri stack installed"

# niri ships a wiki doc file with a non-ASCII hyphen (U+2010) in its name:
# Layer‐Shell-Components.md — ostree refuses to deploy it under a C locale.
find /usr/share/doc/niri -name "*" | python3 -c "
import sys, os
for f in sys.stdin:
    f = f.rstrip()
    if any(ord(c) > 127 for c in f):
        os.remove(f)
        print(f'Removed non-ASCII filename: {f!r}')
"

echo "::endgroup::"

echo "::group:: Install DMS (DankMaterialShell)"

# dms lives in avengemedia/dms but requires quickshell from avengemedia/danklinux
# (added automatically as a coprdep when enabling avengemedia/dms).
# Disable the main repo after enable; reference both sections explicitly on install.
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr disable avengemedia/dms
dnf5 -y install \
  --enablerepo=copr:copr.fedorainfracloud.org:avengemedia:dms \
  --enablerepo=coprdep:copr.fedorainfracloud.org:avengemedia:danklinux \
  dms \
  dms-greeter \
  ghostty

dnf5 remove -y alacritty

echo "DMS installed"
echo "::endgroup::"

echo "::group:: Configure Display Manager (greetd + dms-greeter)"

# Replace GDM with greetd (disable first so the display-manager symlink is free).
# greetd's session config is overlaid from system_files by build.sh.
systemctl disable gdm
systemctl enable greetd

echo "greetd enabled"
echo "::endgroup::"

echo "::group:: Enable DMS as niri shell (system-wide user service)"

# Equivalent of: systemctl --user add-wants niri.service dms.service
# Done system-wide via /usr/lib/systemd/user/ so it applies to all users
mkdir -p /usr/lib/systemd/user/niri.service.wants
ln -sf /usr/lib/systemd/user/dms.service \
  /usr/lib/systemd/user/niri.service.wants/dms.service

echo "DMS wired to niri.service"
echo "::endgroup::"

echo "Niri desktop stack installation complete!"
