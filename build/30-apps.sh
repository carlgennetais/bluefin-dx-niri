#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Desktop Applications
###############################################################################
# Installs build-time desktop applications:
#   - Ghostty   - GPU-accelerated terminal emulator
#   - Vicinae   - Fast native desktop launcher
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "::group:: Install Ghostty"

copr_install_isolated "scottames/ghostty" \
  ghostty

echo "Ghostty installed"
echo "::endgroup::"

echo "::group:: Install Vicinae"

# vicinae requires cmark-gfm from a coprdep repo  (quadratech188/cmark-gfm)
dnf5 -y copr enable quadratech188/vicinae
dnf5 -y copr disable quadratech188/vicinae
dnf5 -y install \
  --enablerepo=copr:copr.fedorainfracloud.org:quadratech188:vicinae \
  --enablerepo=coprdep:copr.fedorainfracloud.org:quadratech188:cmark-gfm \
  vicinae

echo "Vicinae installed"
echo "::endgroup::"

echo "Desktop applications installation complete!"
