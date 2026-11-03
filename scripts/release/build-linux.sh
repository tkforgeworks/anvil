#!/usr/bin/env bash
# Builds the Linux release bundle and packages it as an AppImage, a deb and an
# rpm into release/ (ANVL-168).
#
# The release-flutter.yml contract (tkforgeworks/.github, build-linux input):
# run as `bash scripts/release/build-linux.sh` from the repo root on
# ubuntu-22.04 after subosito/flutter-action, with clang, cmake, ninja-build,
# pkg-config, libgtk-3-dev, liblzma-dev and libstdc++-12-dev installed. The
# packaging tools are fetched here. Leave behind, with <version> =
# X.Y.Z[-rc.N] from pubspec.yaml's X.Y.Z[-rc.N]+BUILD:
#   release/anvil-<version>-linux-x86_64.AppImage
#   release/anvil-<version>-linux-amd64.deb
#   release/anvil-<version>-linux-x86_64.rpm
# The workflow uploads release/*.AppImage, *.deb and *.rpm; any failure here
# exits non-zero. Building on 22.04 (glibc 2.35) keeps the packages' glibc
# floor, computed from the bundle below, at or under 2.35 (2.34 for 0.2.0).
#
# Steps: flutter build linux --release → fetch nfpm, appimagetool and the
# AppImage runtime at pinned versions, checked by sha256, into
# build/linux-packaging/tools/ → nfpm builds the deb and rpm from
# linux/packaging/nfpm.yaml → appimagetool builds the AppImage from an AppDir
# holding the bundle, linux/packaging/AppRun, the desktop file and the icon.
#
# Package version: X.Y.Z, or X.Y.Z~rc.N for a release candidate, so that an
# RC sorts below its stable release in dpkg and rpm. File names keep the
# pubspec form (no `~`, which GitHub mangles in asset names).
#
# Options:
#   --skip-flutter-build   reuse build/linux/x64/release/bundle; just package
set -euo pipefail

usage() { sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "$0"; }

skip_flutter_build=0
for arg in "$@"; do
    case "$arg" in
        --skip-flutter-build) skip_flutter_build=1 ;;
        -h | --help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

version="$(sed -n 's/^version:[[:space:]]*\([^[:space:]]*\).*/\1/p' pubspec.yaml | head -n 1)"
app_version="${version%%+*}"
if [[ ! "$app_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]]; then
    echo "pubspec.yaml version '$version' is not X.Y.Z[-rc.N]+BUILD" >&2
    exit 1
fi
pkg_version="${app_version/-rc./~rc.}"
echo "Anvil $version → file version $app_version, package version $pkg_version"

if [[ "$skip_flutter_build" -eq 0 ]]; then
    flutter build linux --release
fi

# BINARY_NAME in linux/CMakeLists.txt.
bundle="$root/build/linux/x64/release/bundle"
if [[ ! -x "$bundle/anvil" ]]; then
    echo "No release bundle at $bundle" >&2
    exit 1
fi

# --- Packaging tools (x86_64, pinned, sha256 checked) ---
work="$root/build/linux-packaging"
tools="$work/tools"
mkdir -p "$tools"

NFPM_VERSION=2.48.0
NFPM_SHA256=6d7f9a28b2f397934403950fcbba83f598b08d02edbe79a0815b3b4897341750
APPIMAGETOOL_VERSION=1.9.1
APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
RUNTIME_VERSION=20251108
RUNTIME_SHA256=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d

# fetch <url> <sha256> <dest>: download unless dest already has that hash.
fetch() {
    local url="$1" sha="$2" dest="$3"
    if [[ -f "$dest" ]] && echo "$sha  $dest" | sha256sum --check --status; then
        return 0
    fi
    echo "Fetching $url"
    curl -fsSL --retry 3 -o "$dest.part" "$url"
    if ! echo "$sha  $dest.part" | sha256sum --check --status; then
        echo "sha256 mismatch for $url" >&2
        rm -f "$dest.part"
        exit 1
    fi
    mv "$dest.part" "$dest"
}

fetch "https://github.com/goreleaser/nfpm/releases/download/v$NFPM_VERSION/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz" \
    "$NFPM_SHA256" "$tools/nfpm-$NFPM_VERSION.tar.gz"
fetch "https://github.com/AppImage/appimagetool/releases/download/$APPIMAGETOOL_VERSION/appimagetool-x86_64.AppImage" \
    "$APPIMAGETOOL_SHA256" "$tools/appimagetool-$APPIMAGETOOL_VERSION.AppImage"
fetch "https://github.com/AppImage/type2-runtime/releases/download/$RUNTIME_VERSION/runtime-x86_64" \
    "$RUNTIME_SHA256" "$tools/runtime-$RUNTIME_VERSION-x86_64"

nfpm_dir="$tools/nfpm-$NFPM_VERSION"
mkdir -p "$nfpm_dir"
tar -xzf "$tools/nfpm-$NFPM_VERSION.tar.gz" -C "$nfpm_dir" nfpm
nfpm="$nfpm_dir/nfpm"
appimagetool="$tools/appimagetool-$APPIMAGETOOL_VERSION.AppImage"
chmod +x "$appimagetool"
# No FUSE on the runner: the AppImage tool unpacks itself and runs.
export APPIMAGE_EXTRACT_AND_RUN=1

# --- glibc floor: the newest GLIBC_x.y symbol version the bundle needs ---
glibc_min="$(
    for f in "$bundle/anvil" "$bundle"/lib/*.so; do
        readelf --dyn-syms --wide "$f"
    done | grep -o 'GLIBC_[0-9]\+\(\.[0-9]\+\)\+' | sed 's/^GLIBC_//' | sort -V | tail -n 1
)"
if [[ -z "$glibc_min" ]]; then
    echo "Could not read the glibc symbol versions of the bundle" >&2
    exit 1
fi
echo "glibc floor $glibc_min"

release="$root/release"
mkdir -p "$release"
rm -f "$release"/anvil-*-linux-*

deb="$release/anvil-$app_version-linux-amd64.deb"
rpm="$release/anvil-$app_version-linux-x86_64.rpm"
appimage="$release/anvil-$app_version-linux-x86_64.AppImage"

# --- deb and rpm ---
export ANVIL_PKG_VERSION="$pkg_version" ANVIL_GLIBC_MIN="$glibc_min"
"$nfpm" package --config linux/packaging/nfpm.yaml --packager deb --target "$deb"
"$nfpm" package --config linux/packaging/nfpm.yaml --packager rpm --target "$rpm"

# --- AppImage ---
appdir="$work/Anvil.AppDir"
rm -rf "$appdir"
mkdir -p "$appdir/opt"
cp -a "$bundle" "$appdir/opt/anvil"
install -m 0755 linux/packaging/AppRun "$appdir/AppRun"
install -m 0644 linux/packaging/com.tkforgeworks.anvil.desktop "$appdir/com.tkforgeworks.anvil.desktop"
install -m 0644 resources/icon.png "$appdir/com.tkforgeworks.anvil.png"
ln -s com.tkforgeworks.anvil.png "$appdir/.DirIcon"

ARCH=x86_64 VERSION="$app_version" "$appimagetool" --no-appstream \
    --runtime-file "$tools/runtime-$RUNTIME_VERSION-x86_64" "$appdir" "$appimage"

ls -l "$appimage" "$deb" "$rpm"
