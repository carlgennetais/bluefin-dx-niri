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

### Enable system units

systemctl enable podman.socket
