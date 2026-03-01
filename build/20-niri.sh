#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Niri Desktop Stack
###############################################################################
# Installs niri (scrollable-tiling Wayland compositor) alongside GNOME,
# along with:
#   - DMS (DankMaterialShell) - Material 3 shell for niri/Hyprland
#   - dms-greeter  - greetd-based greeter (replaces GDM)
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "::group:: Install niri and Wayland utilities"

dnf5 install -y \
  niri \
  xwayland-satellite

echo "niri stack installed"
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
  dms-greeter

echo "DMS installed"
echo "::endgroup::"

echo "::group:: Configure Display Manager (greetd + dms-greeter)"

# Replace GDM with greetd (disable first so the display-manager symlink is free)
systemctl disable gdm
systemctl enable greetd

# Configure greetd to launch dms-greeter with niri as the compositor
mkdir -p /etc/greetd
cat >/etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
user = "greeter"
command = "dms-greeter --command niri"
EOF

echo "greetd configured with dms-greeter"
echo "::endgroup::"

echo "::group:: Declare greeter sysuser and greetd tmpfiles (bootc lint)"

# bootc lint requires /etc/passwd entries to have matching sysusers.d declarations.
# dms-greeter creates the 'greeter' user via RPM scriptlet without a sysusers.d file.
mkdir -p /usr/lib/sysusers.d
cat >/usr/lib/sysusers.d/greeter.conf <<'EOF'
# greeter user for dms-greeter / greetd sessions
g greeter - - -
u greeter - "DMS Greeter" /var/lib/greetd /sbin/nologin
EOF

# bootc lint also requires /var content created by RPM scriptlets to be declared
# in tmpfiles.d so it is re-created correctly on updates.
mkdir -p /usr/lib/tmpfiles.d
cat >/usr/lib/tmpfiles.d/greetd-dms.conf <<'EOF'
d /var/lib/greetd/.config                    0755 greetd greetd -
d /var/lib/greetd/.config/systemd            0755 greetd greetd -
d /var/lib/greetd/.config/systemd/user       0755 greetd greetd -
L /var/lib/greetd/.config/systemd/user/xdg-desktop-portal.service - - - - /dev/null
EOF

echo "sysusers.d and tmpfiles.d entries written"
echo "::endgroup::"

echo "::group:: Enable DMS as niri shell (system-wide user service)"

# Equivalent of: systemctl --user add-wants niri.service dms.service
# Done system-wide via /usr/lib/systemd/user/ so it applies to all users
mkdir -p /usr/lib/systemd/user/niri.service.wants
ln -sf /usr/lib/systemd/user/dms.service \
  /usr/lib/systemd/user/niri.service.wants/dms.service

echo "DMS wired to niri.service"
echo "::endgroup::"

# echo "::group:: Remove GNOME Desktop"
#
# # Remove GNOME Shell and related packages
# dnf5 remove -y \
#     gnome-shell \
#     gnome-shell-extension* \
#     gnome-terminal \
#     gnome-software \
#     gnome-control-center \
#     nautilus \
#     gdm
#
# echo "GNOME desktop removed"
# echo "::endgroup::"

echo "Niri desktop stack installation complete!"
