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
#   /etc/greetd/config.toml             - greetd session
#   /usr/lib/tmpfiles.d/greetd-dms.conf - greetd /var content (bootc lint)
#
# The 'greeter' user and /var/cache/dms-greeter are declared by the dms-greeter
# RPM's own sysusers.d/tmpfiles.d — do not redeclare them here.
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

# The base image lags Fedora updates (bluefin-dx is rebuilt on its own cadence),
# but the DMS COPRs build against *current* Fedora. quickshell links Qt
# private-API symbols, and qt6-qtbase 6.11.2 promoted
# QUntypedPropertyBinding(QPropertyBindingPrivate*) from @Qt_6.11_PRIVATE_API to
# the public @Qt_6 set. RPM dependencies only track whole symbol-version sets,
# so the mismatch installs cleanly and fails at runtime: quickshell exits 127,
# the greeter UI never starts, niri quits, greetd hits its restart limit, and
# the machine boots to a black screen. Keep Qt aligned with the COPRs.
dnf5 -y upgrade 'qt6-*'

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

# Gate the build on quickshell actually starting. A Qt ABI mismatch is invisible
# to dnf5 -- it resolves and installs fine, then the desktop never comes up.
if ! qs_version=$(quickshell --version 2>&1); then
  echo "ERROR: quickshell cannot start -- Qt ABI mismatch:" >&2
  echo "$qs_version" >&2
  exit 1
fi
echo "quickshell smoke test passed: $qs_version"

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
