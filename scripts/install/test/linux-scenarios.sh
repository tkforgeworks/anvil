#!/usr/bin/env bash
# Runs the install-anvil.sh scenarios inside a throwaway container, as root
# (run-container-tests.sh starts it). Mounts expected:
#   /src     scripts/install (read-only)
#   /fake    the output of make-fake-release.py (read-only)
#   /legacy  the real 0.1.6 deb and rpm (read-only)
# Usage: linux-scenarios.sh deb|rpm|appimage
#   deb       apt path on a Debian/Ubuntu image, then the AppImage path
#   rpm       dnf path on a Fedora image
#   appimage  only the AppImage path (Debian/Ubuntu image)
# Every scenario runs the script piped into `bash -s --` as the non-root user
# `tester` (passwordless sudo), as the README's one-liner does. Prints one
# PASS/FAIL line per check and exits non-zero if any check failed.
set -uo pipefail

mode="${1:?usage: linux-scenarios.sh deb|rpm|appimage}"
API=http://127.0.0.1:8000/api
API_OLD=http://127.0.0.1:8000/api-old
fails=0
out=""
rc=0

pass() { printf 'PASS  %s\n' "$*"; }
fail() {
    printf 'FAIL  %s\n' "$*"
    fails=$((fails + 1))
}
check() { # check DESCRIPTION COMMAND...
    local d="$1"
    shift
    if "$@"; then pass "$d"; else fail "$d"; fi
}
contains() { [[ "$out" == *"$1"* ]]; }

# run [API] ARGS...: runs the script as tester; sets $out and $rc.
run() {
    local api="$API" a
    local -a rest=()
    for a in "$@"; do
        case "$a" in
            --api=*) api="${a#--api=}" ;;
            *) rest+=("$a") ;;
        esac
    done
    local args="${rest[*]}"
    printf '\n$ install-anvil.sh %s\n' "$args"
    rc=0
    out="$(runuser -l tester -c "ANVIL_RELEASES_API='$api' bash -s -- $args" </src/install-anvil.sh 2>&1)" || rc=$?
    printf '%s\n[exit %s]\n' "$out" "$rc"
}

no_temp_left() { ! compgen -G '/tmp/anvil-install.*' >/dev/null; }

pkg_version() {
    case "$mode" in
        rpm) rpm -q --qf '%{VERSION}' anvil 2>/dev/null || true ;;
        # Without the Debian revision nfpm adds (0.2.0-1 → 0.2.0).
        *) dpkg-query -W -f='${Version}' anvil 2>/dev/null | sed 's/-[^-]*$//' || true ;;
    esac
}

setup() {
    echo "== setup ($mode)"
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y -q python3 curl sudo util-linux xorg-x11-server-Xvfb xorg-x11-xauth \
            mesa-dri-drivers mesa-libEGL procps-ng findutils >/dev/null
    else
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq >/dev/null
        apt-get install -y -qq python3 curl sudo xvfb xauth desktop-file-utils \
            libegl-mesa0 libgl1-mesa-dri procps >/dev/null
    fi
    useradd -m -s /bin/bash tester
    echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester
    chmod 0440 /etc/sudoers.d/tester
    (cd /fake && exec python3 -m http.server 8000 --bind 127.0.0.1 >/tmp/http.log 2>&1) &
    for _ in $(seq 50); do
        curl -fs "$API/releases/latest" >/dev/null && break
        sleep 0.2
    done
    curl -fs "$API/releases/latest" >/dev/null || {
        echo "fake release server did not start"
        exit 1
    }
}

package_scenarios() {
    echo "== package path ($mode)"
    run --check
    check "--check, nothing installed: exit 0" test "$rc" -eq 0
    check "--check resolves v0.2.0" contains "Release:   v0.2.0 (stable)"
    check "--check says not installed" contains "Installed: not installed"
    check "--check would install" contains "would install 0.2.0"

    run
    check "default run installs: exit 0" test "$rc" -eq 0
    check "package version is 0.2.0" test "$(pkg_version)" = 0.2.0
    # shellcheck disable=SC2016 # expanded by tester's shell, not this one.
    check "anvil resolves to /opt/Anvil/anvil" test "$(runuser -l tester -c 'readlink -f "$(command -v anvil)"')" = /opt/Anvil/anvil
    check "sha256 verified" contains "sha256 verified."
    check "temp dir removed" no_temp_left

    run
    check "second run: exit 0" test "$rc" -eq 0
    check "second run is up to date" contains "already up to date"

    run --stable
    check "--stable when current: up to date" contains "already up to date"

    run --api="$API_OLD"
    check "newest is older than installed: exit 0" test "$rc" -eq 0
    check "says installed is newer, no downgrade" contains "newer than v0.2.0-rc.1; not downgrading"
    check "package still 0.2.0" test "$(pkg_version)" = 0.2.0

    run v0.2.0-rc.1
    check "explicit rc tag downgrades: exit 0" test "$rc" -eq 0
    check "downgrade message" contains "Downgrading Anvil 0.2.0 to 0.2.0-rc.1"
    check "package version is 0.2.0~rc.1" test "$(pkg_version)" = "0.2.0~rc.1"

    run --check
    check "--check with rc installed: would upgrade" contains "would upgrade 0.2.0-rc.1 to 0.2.0"

    run
    check "default run upgrades back: exit 0" test "$rc" -eq 0
    check "package version is 0.2.0 again" test "$(pkg_version)" = 0.2.0

    run v0.1.6
    check "v0.1.6: non-zero exit" test "$rc" -ne 0
    check "v0.1.6: no asset for this host" contains "has no anvil-0.1.6-linux-"

    run 0.0.9
    check "wrong digest: non-zero exit" test "$rc" -ne 0
    check "wrong digest: sha256 mismatch reported" contains "sha256 mismatch for anvil-0.0.9-linux-"
    check "wrong digest: nothing installed (still 0.2.0)" test "$(pkg_version)" = 0.2.0
    check "wrong digest: temp dir removed" no_temp_left

    run v0.3.0
    check "draft tag: non-zero exit" test "$rc" -ne 0
    check "draft tag: not installed" contains "drafts are never installed"

    run v9.9.9
    check "unknown tag: non-zero exit" test "$rc" -ne 0
    check "unknown tag: no such release" contains "no published release tagged v9.9.9"

    run --bogus
    check "unknown option: exit 2" test "$rc" -eq 2

    echo "== 0.1.6 upgrade ($mode)"
    if [[ "$mode" == rpm ]]; then
        dnf remove -y -q anvil >/dev/null
        dnf install -y -q /legacy/anvil-0.1.6.x86_64.rpm >/dev/null
    else
        apt-get purge -y -qq anvil >/dev/null
        apt-get install -y -qq /legacy/anvil_0.1.6_amd64.deb >/dev/null
    fi
    check "0.1.6 package installed" test "$(pkg_version)" = 0.1.6
    run --check
    check "--check shows installed 0.1.6" contains "Installed: 0.1.6"
    check "--check would upgrade 0.1.6" contains "would upgrade 0.1.6 to 0.2.0"
    run
    check "upgrade from 0.1.6: exit 0" test "$rc" -eq 0
    check "package version is 0.2.0 after 0.1.6" test "$(pkg_version)" = 0.2.0
    check "/usr/bin/anvil links to /opt/Anvil/anvil" test "$(readlink -f /usr/bin/anvil)" = /opt/Anvil/anvil
    local smoke=0
    runuser -l tester -c 'xvfb-run -a timeout 15 /usr/bin/anvil' >/tmp/smoke.log 2>&1 || smoke=$?
    check "/usr/bin/anvil runs under Xvfb until the timeout (exit $smoke, want 124)" test "$smoke" -eq 124
}

appimage_scenarios() {
    echo "== AppImage path"
    local home=/home/tester
    run --appimage --check
    check "AppImage --check: exit 0" test "$rc" -eq 0
    check "AppImage --check: not installed" contains "Installed: not installed"

    run --appimage
    check "AppImage install: exit 0" test "$rc" -eq 0
    check "tester's .local/bin/anvil is executable" test -x "$home/.local/bin/anvil"
    check "installed-version is v0.2.0" test "$(cat "$home/.local/share/anvil/installed-version")" = v0.2.0
    check "icon installed" test -f "$home/.local/share/icons/hicolor/512x512/apps/com.tkforgeworks.anvil.png"
    local desktop="$home/.local/share/applications/com.tkforgeworks.anvil.desktop"
    check "desktop file installed" test -f "$desktop"
    check "desktop Exec is the absolute path" grep -qx "Exec=$home/.local/bin/anvil %U" "$desktop"
    check "desktop Icon is the icon name" grep -qx "Icon=com.tkforgeworks.anvil" "$desktop"
    if command -v desktop-file-validate >/dev/null 2>&1; then
        local v
        v="$(desktop-file-validate "$desktop" 2>&1)"
        check "desktop-file-validate passes${v:+ ($v)}" test -z "$v"
    fi
    if [[ -e /usr/bin/anvil ]]; then
        check "warns that /usr/bin/anvil exists" contains "/usr/bin/anvil also exists"
    fi
    check "temp dir removed" no_temp_left
    sed -n 'p' "$desktop"

    local smoke=0
    runuser -l tester -c 'APPIMAGE_EXTRACT_AND_RUN=1 xvfb-run -a timeout 15 ~/.local/bin/anvil' >/tmp/smoke-appimage.log 2>&1 || smoke=$?
    check "AppImage runs under Xvfb until the timeout (exit $smoke, want 124)" test "$smoke" -eq 124

    run --appimage
    check "AppImage re-run is up to date" contains "already up to date"

    run --appimage v0.2.0-rc.1
    check "AppImage rc.1 (no digest): exit 0" test "$rc" -eq 0
    check "AppImage rc.1 warns about the missing digest" contains "GitHub lists no digest"
    check "installed-version is v0.2.0-rc.1" test "$(cat "$home/.local/share/anvil/installed-version")" = v0.2.0-rc.1

    run --appimage
    check "AppImage default upgrades back: exit 0" test "$rc" -eq 0
    check "installed-version is v0.2.0 again" test "$(cat "$home/.local/share/anvil/installed-version")" = v0.2.0

    run --appimage --api="$API_OLD"
    check "AppImage: newest older than installed, no downgrade" contains "not downgrading"

    run --appimage v0.0.9
    check "AppImage wrong digest: non-zero exit" test "$rc" -ne 0
    check "AppImage wrong digest: still v0.2.0" test "$(cat "$home/.local/share/anvil/installed-version")" = v0.2.0
    check "AppImage wrong digest: temp dir removed" no_temp_left
}

setup
case "$mode" in
    deb)
        package_scenarios
        appimage_scenarios
        ;;
    rpm) package_scenarios ;;
    appimage) appimage_scenarios ;;
    *)
        echo "unknown mode $mode"
        exit 2
        ;;
esac

echo
if [[ "$fails" -eq 0 ]]; then
    echo "ALL PASSED ($mode)"
else
    echo "$fails CHECK(S) FAILED ($mode)"
    exit 1
fi
