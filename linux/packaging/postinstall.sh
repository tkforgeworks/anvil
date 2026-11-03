#!/bin/sh
# deb postinst and rpm %posttrans for the anvil package (ANVL-168).
#
# The package ships /usr/bin/anvil as a symlink to /opt/Anvil/anvil. The
# Electron 0.1.x packages (electron-builder) did not: their postinst/%post
# registered /usr/bin/anvil through update-alternatives, and their
# postrm/%postun runs `update-alternatives --remove anvil /opt/Anvil/anvil`
# unconditionally, also on upgrade. On an upgrade from 0.1.x that removal runs
# after this package has unpacked (dpkg: old postrm before new postinst; rpm:
# old %postun before new %posttrans), so it can delete or leave dangling the
# link this package just installed. This script runs last in both orders and
# puts the link back. It also drops a leftover alternatives registration in
# case the old removal failed.
#
# The 0.1.x rpm listed its files but not its directories, so rpm leaves the
# Electron tree under /opt/Anvil/locales and /opt/Anvil/resources behind as
# empty directories (which then also keep /opt/Anvil from going away on
# uninstall). Only empty directories are removed, and only under those two
# 0.1.x-only paths, which this package never installs.
#
# On a fresh install or a 0.2.x upgrade the script changes nothing.
set -e

if command -v update-alternatives >/dev/null 2>&1 &&
    update-alternatives --display anvil >/dev/null 2>&1; then
    update-alternatives --remove anvil /opt/Anvil/anvil >/dev/null 2>&1 || true
fi

if [ "$(readlink /usr/bin/anvil 2>/dev/null || true)" != /opt/Anvil/anvil ]; then
    ln -sfn /opt/Anvil/anvil /usr/bin/anvil
fi

for dir in /opt/Anvil/locales /opt/Anvil/resources; do
    if [ -d "$dir" ]; then
        find "$dir" -depth -type d -empty -delete || true
    fi
done

exit 0
