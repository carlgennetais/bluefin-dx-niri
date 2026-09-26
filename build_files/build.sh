#!/bin/bash

set -ouex pipefail

### Install packages

# The niri desktop stack lives in its own script to keep this one readable.
# It runs before the system_files overlay below so that the static config we
# ship wins over anything the RPMs drop in place (e.g. greetd's own
# /etc/greetd/config.toml).
/ctx/niri.sh

### Copy the contents of system_files/ of the git repo to /

# rsync -K (--keep-dirlinks) instead of cp: some directories in the base image
# are symlinks to elsewhere (e.g. /usr/share/X11/xkb -> ../xkeyboard-config-2)
# and cp refuses to overwrite a symlink with a directory.
rsync -rvK "/ctx/system_files"/ /

### Register the custom XKB layouts

# The symbol files ship in system_files; these rule files belong to the base
# image and have to be patched in place so the layout is discoverable by name
# (GNOME Settings, libxkbcommon, niri xkb config, localectl).
# evdev and base rules are identical separate files — patch both.
for lst in /usr/share/X11/xkb/rules/evdev.lst /usr/share/X11/xkb/rules/base.lst; do
  sed -i '/^! layout$/a\  us_qwerty-fr              English (US, qwerty-fr)' "$lst"
done
for xml in /usr/share/X11/xkb/rules/evdev.xml /usr/share/X11/xkb/rules/base.xml; do
  sed -i 's|  </layoutList>|    <layout>\n      <configItem>\n        <name>us_qwerty-fr</name>\n        <shortDescription>en</shortDescription>\n        <description>English (US, qwerty-fr)</description>\n      </configItem>\n    </layout>\n  </layoutList>|' "$xml"
done

### Enable system units

systemctl enable podman.socket
