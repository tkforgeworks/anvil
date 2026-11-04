#!/usr/bin/env bash
# Runs the install-script tests in podman containers, one job at a time
# (ANVL-143). From the repo root:
#
#   scripts/install/test/run-container-tests.sh JOB [--stable-dir DIR]
#       [--rc-dir DIR] [--legacy-dir DIR] [--work DIR]
#
# Jobs:
#   fedora      rpm path in fedora:latest
#   debian      deb path, then the AppImage path, in debian:13
#   ubuntu      deb path, then the AppImage path, in ubuntu:24.04
#   appimage    AppImage path only, in debian:13
#   lint        run shellcheck over the Linux script and the test scripts
#   pwsh        parse, -Help, the pure-function tests and PSScriptAnalyzer for
#               install-anvil.ps1 in mcr.microsoft.com/powershell:7.5-ubuntu-24.04
#
# The package jobs need:
#   --stable-dir  anvil-0.2.0-linux-{amd64.deb,x86_64.rpm,x86_64.AppImage}
#   --rc-dir      the same for 0.2.0-rc.1 (build-linux.sh with the pubspec
#                 version set to 0.2.0-rc.1+N, or --skip-flutter-build over an
#                 existing bundle)
#   --legacy-dir  the real 0.1.6 assets: gh release download v0.1.6 -R
#                 tkforgeworks/anvil -p '*.deb' -p '*.rpm' -D DIR
# The packages must run in the image: ones built on Fedora need fedora:latest,
# debian:13 or ubuntu:24.04; CI-built ones (ubuntu-22.04) run on all of them.
# The pwsh job needs only the fake JSON, so --stable-dir and --rc-dir are
# still needed there (the generator checks the files exist).
#
# --work is where the fake release is written (default: a temp dir, removed
# at the end). Containers run with --rm and SELinux labelling disabled, so the
# mounted directories are not relabelled. Network is needed for the package
# installs inside the containers.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$(cd "$here/.." && pwd)"

job="${1:-}"
[[ -n "$job" ]] || {
    sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "$0"
    exit 2
}
shift
stable_dir="" rc_dir="" legacy_dir="" work=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --stable-dir) stable_dir="$2" ;;
        --rc-dir) rc_dir="$2" ;;
        --legacy-dir) legacy_dir="$2" ;;
        --work) work="$2" ;;
        *)
            echo "unknown option $1" >&2
            exit 2
            ;;
    esac
    shift 2
done

made_work=0
cleanup() {
    if [[ "$made_work" -eq 1 ]]; then
        rm -rf "$work"
    fi
}
trap cleanup EXIT

make_fake() {
    [[ -n "$stable_dir" && -n "$rc_dir" ]] || {
        echo "--stable-dir and --rc-dir are required for $job" >&2
        exit 2
    }
    if [[ -z "$work" ]]; then
        work="$(mktemp -d)"
        made_work=1
    fi
    local -a legacy=()
    if [[ -n "$legacy_dir" ]]; then
        legacy=(--legacy-dir "$legacy_dir")
    fi
    python3 "$here/make-fake-release.py" --out "$work/fake" \
        --stable-dir "$stable_dir" --rc-dir "$rc_dir" "${legacy[@]}"
}

linux_job() { # IMAGE MODE
    make_fake
    [[ -n "$legacy_dir" ]] || {
        echo "--legacy-dir is required for $job" >&2
        exit 2
    }
    podman run --rm --security-opt label=disable \
        -v "$src:/src:ro" -v "$work/fake:/fake:ro" -v "$legacy_dir:/legacy:ro" \
        "$1" bash /src/test/linux-scenarios.sh "$2"
}

case "$job" in
    fedora) linux_job registry.fedoraproject.org/fedora:latest rpm ;;
    debian) linux_job docker.io/library/debian:13 deb ;;
    ubuntu) linux_job docker.io/library/ubuntu:24.04 deb ;;
    appimage) linux_job docker.io/library/debian:13 appimage ;;
    lint)
        podman run --rm --security-opt label=disable -v "$src:/mnt:ro" -w /mnt \
            docker.io/koalaman/shellcheck:stable \
            install-anvil.sh test/linux-scenarios.sh test/run-container-tests.sh
        echo "shellcheck: clean"
        ;;
    pwsh)
        make_fake
        podman run --rm --security-opt label=disable \
            -v "$src:/src:ro" -v "$work/fake:/fake:ro" \
            mcr.microsoft.com/powershell:7.5-ubuntu-24.04 \
            pwsh -NoProfile -NonInteractive -File /src/test/test-install-anvil.ps1 -FakeDir /fake -Analyze
        ;;
    *)
        echo "unknown job $job" >&2
        exit 2
        ;;
esac
