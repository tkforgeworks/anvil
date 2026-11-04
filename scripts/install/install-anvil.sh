#!/usr/bin/env bash
# install-anvil.sh: install or update Anvil (0.2.0 and later) on Linux from a
# GitHub release of tkforgeworks/anvil (ANVL-143).
#
# Resolves a release through GitHub's public REST API (no token, no gh),
# downloads the asset for this host, checks it against the sha256 digest
# GitHub publishes for it, and installs it in place:
#   deb hosts (apt + dpkg):  anvil-<ver>-linux-amd64.deb with apt-get
#   rpm hosts (dnf + rpm):   anvil-<ver>-linux-x86_64.rpm with dnf
#   any other host, or --appimage: anvil-<ver>-linux-x86_64.AppImage as
#     ~/.local/bin/anvil, with its desktop entry and icon under ~/.local/share
# Run it again to update. The packages replace an Anvil 0.1.x package, which
# counts as older. 0.1.x releases themselves (Electron builds) have no asset
# this script installs.
#
# Usage: install-anvil.sh [--stable] [--check] [--appimage] [TAG]
#   (no option)  newest release, release candidates included
#   --stable     newest stable release
#   TAG          that release, e.g. v0.2.0 or v0.2.0-rc.1; may downgrade
#   --check      print the resolved release and the installed version, and
#                exit without changing anything
#   --appimage   install the AppImage for the current user, also on a deb or
#                rpm host
#   -h, --help   show this help
#
# Without a TAG it never downgrades: when the installed Anvil is newer than
# the resolved release it says so and exits 0. The deb and rpm paths ask for
# sudo once up front and keep it alive until the script ends.
#
# Environment:
#   ANVIL_RELEASES_API  base URL of the releases API, default
#                       https://api.github.com/repos/tkforgeworks/anvil.
#                       A testing aid: point it at a fake release served
#                       locally (see scripts/install/test/).
#
# Needs bash, curl, sha256sum and python3 (to read the API's JSON), plus
# apt-get or dnf and sudo for the package paths.
#
# Piped use: curl -fsSL <raw URL of this file> | bash -s -- --stable
set -euo pipefail

readonly APP_ID=com.tkforgeworks.anvil
readonly DEFAULT_API=https://api.github.com/repos/tkforgeworks/anvil

tmp=""
keepalive_pid=""

say() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
install-anvil.sh: install or update Anvil (0.2.0 and later) from a GitHub release.

Usage: install-anvil.sh [--stable] [--check] [--appimage] [TAG]

  (no option)  newest release, release candidates included
  --stable     newest stable release
  TAG          that release, e.g. v0.2.0 or v0.2.0-rc.1; may downgrade
  --check      print the resolved release and the installed version, change nothing
  --appimage   install the AppImage for the current user, also on a deb or rpm host
  -h, --help   show this help

Installs the deb with apt-get on deb hosts, the rpm with dnf on rpm hosts, and
otherwise the AppImage as ~/.local/bin/anvil with a desktop entry and icon.
Every download is checked against the sha256 digest GitHub publishes. Without
a TAG it never downgrades. Run it again to update.

Environment:
  ANVIL_RELEASES_API  releases API base URL (testing aid), default
                      https://api.github.com/repos/tkforgeworks/anvil

Piped: curl -fsSL https://raw.githubusercontent.com/tkforgeworks/anvil/main/scripts/install/install-anvil.sh | bash -s -- --stable
EOF
}

cleanup() {
    if [[ -n "$keepalive_pid" ]]; then
        kill "$keepalive_pid" 2>/dev/null || true
    fi
    if [[ -n "$tmp" ]]; then
        rm -rf "$tmp"
    fi
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed ($2)."
}

as_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Prints deb, rpm or appimage. A host counts as deb or rpm only when that
# package database owns its own package manager, so a Fedora with dpkg
# installed, or a Debian with rpm, is not mistaken for the other.
detect_method() {
    if command -v apt-get >/dev/null 2>&1 && command -v dpkg-query >/dev/null 2>&1; then
        # shellcheck disable=SC2016 # ${Status} is dpkg-query's format, not a shell variable.
        if [[ "$(dpkg-query -W -f='${Status}' dpkg 2>/dev/null || true)" == "install ok installed" ]]; then
            echo deb
            return
        fi
    fi
    if command -v dnf >/dev/null 2>&1 && command -v rpm >/dev/null 2>&1 && rpm -q rpm >/dev/null 2>&1; then
        echo rpm
        return
    fi
    echo appimage
}

# api_get URL DEST: 0 on HTTP 200, 4 on 404, dies on anything else.
api_get() {
    local code
    code="$(curl -sSL --retry 3 -H 'Accept: application/vnd.github+json' \
        -o "$2" -w '%{http_code}' "$1")" || die "Could not reach $1"
    case "$code" in
        200) return 0 ;;
        404) return 4 ;;
        403 | 429) die "The GitHub API refused the request (HTTP $code). Without a token it allows 60 requests an hour; try again later." ;;
        *) die "The releases API returned HTTP $code for $1" ;;
    esac
}

# Reads the API's JSON (a release list or one release), picks the release
# and the host asset, and prints one value per line:
#   none                       when no release qualifies, or
#   error, <message>           when the JSON cannot be read, or
#   release, tag, prerelease|stable, asset name, asset URL, digest
# (URL and digest empty when the release has no such asset).
# Drafts are never picked.
read -r -d '' SELECT_PY <<'PY' || true
import json
import sys

path, mode, want, suffix = sys.argv[1:5]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:  # noqa: BLE001
    print("error")
    print(str(e).replace("\n", " "))
    sys.exit(0)

releases = data if isinstance(data, list) else [data]
chosen = None
for r in releases:
    if not isinstance(r, dict) or r.get("draft"):
        continue
    if mode == "stable" and r.get("prerelease"):
        continue
    if mode == "tag" and r.get("tag_name") != want:
        continue
    chosen = r
    break

if chosen is None:
    print("none")
    sys.exit(0)

tag = chosen.get("tag_name") or ""
version = tag[1:] if tag.startswith("v") else tag
name = "anvil-%s-%s" % (version, suffix)
asset = None
for a in chosen.get("assets") or []:
    if isinstance(a, dict) and a.get("name") == name:
        asset = a
        break
print("release")
print(tag)
print("prerelease" if chosen.get("prerelease") else "stable")
print(name)
print((asset or {}).get("browser_download_url") or "")
print((asset or {}).get("digest") or "")
PY

# semver_parts X.Y.Z[-rc.N]: prints "X Y Z N", N = 999999999 for a stable
# release so it sorts above every rc of the same X.Y.Z; fails otherwise.
semver_parts() {
    [[ "$1" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-rc\.([0-9]+))?$ ]] || return 1
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[5]:-999999999}"
}

# semver_cmp A B: prints -1, 0 or 1. An A that is not X.Y.Z[-rc.N] counts as
# older.
semver_cmp() {
    local pa pb i
    if ! pa="$(semver_parts "$1")"; then
        echo -1
        return
    fi
    pb="$(semver_parts "$2")" || die "Not a release version: $2"
    local -a a b
    read -r -a a <<<"$pa"
    read -r -a b <<<"$pb"
    for i in 0 1 2 3; do
        if ((10#${a[i]} < 10#${b[i]})); then
            echo -1
            return
        elif ((10#${a[i]} > 10#${b[i]})); then
            echo 1
            return
        fi
    done
    echo 0
}

# rpm_cmp A B: rpm's own ordering, -1, 0 or 1.
rpm_cmp() {
    local r
    [[ "$1$2" =~ ^[0-9A-Za-z.~^+_-]+$ ]] || die "Unexpected rpm version '$1' or '$2'"
    r="$(rpm --eval "%{lua: print(rpm.vercmp('$1', '$2'))}" 2>/dev/null || true)"
    case "$r" in
        -1 | 0 | 1) echo "$r" ;;
        *)
            if command -v rpmdev-vercmp >/dev/null 2>&1; then
                local rc=0
                rpmdev-vercmp "$1" "$2" >/dev/null 2>&1 || rc=$?
                case "$rc" in
                    0) echo 0 ;;
                    11) echo 1 ;;
                    12) echo -1 ;;
                    *) die "rpmdev-vercmp failed on '$1' '$2'" ;;
                esac
            else
                die "Cannot compare rpm versions: rpm has no lua rpm.vercmp and rpmdev-vercmp is not installed."
            fi
            ;;
    esac
}

# deb_cmp A B: dpkg's own ordering, -1, 0 or 1.
deb_cmp() {
    if dpkg --compare-versions "$1" lt "$2"; then
        echo -1
    elif dpkg --compare-versions "$1" eq "$2"; then
        echo 0
    else
        echo 1
    fi
}

# Prints the installed version in the method's own form (the deb's upstream
# version without its revision, the rpm's VERSION without its RELEASE, or the
# recorded AppImage tag without its v), "unknown" for an
# AppImage with no recorded version, or nothing when not installed.
installed_version() {
    local s v
    case "$method" in
        deb)
            # shellcheck disable=SC2016 # dpkg-query format fields.
            s="$(dpkg-query -W -f='${Status}|${Version}' anvil 2>/dev/null || true)"
            if [[ "$s" == "install ok installed|"* ]]; then
                # Drop the Debian revision: nfpm writes Version as
                # X.Y.Z[~rc.N]-1 (its release field), 0.1.x had none.
                v="${s#*|}"
                if [[ "$v" == *-* ]]; then
                    v="${v%-*}"
                fi
                echo "$v"
            fi
            ;;
        rpm)
            if v="$(rpm -q --qf '%{VERSION}\n' anvil 2>/dev/null)"; then
                echo "${v%%$'\n'*}"
            fi
            ;;
        appimage)
            if [[ -f "$state_file" ]]; then
                v="$(head -n 1 "$state_file")"
                echo "${v#v}"
            elif [[ -e "$bin_dir/anvil" ]]; then
                echo unknown
            fi
            ;;
    esac
}

version_cmp() {
    case "$method" in
        deb) deb_cmp "$1" "$2" ;;
        rpm) rpm_cmp "$1" "$2" ;;
        appimage) semver_cmp "$1" "$2" ;;
    esac
}

verify_digest() {
    local file="$1" name="$2" digest="$3" got want
    if [[ -z "$digest" ]]; then
        warn "GitHub lists no digest for $name, so the download cannot be verified."
        return 0
    fi
    if [[ "$digest" != sha256:* ]]; then
        warn "GitHub lists a digest this script cannot check ($digest) for $name; the download is not verified."
        return 0
    fi
    want="${digest#sha256:}"
    got="$(sha256sum "$file")"
    got="${got%% *}"
    if [[ "${got,,}" != "${want,,}" ]]; then
        die "sha256 mismatch for $name: GitHub lists $want, the download is $got. Nothing was installed."
    fi
    say "sha256 verified."
}

start_sudo() {
    if [[ "$EUID" -eq 0 ]]; then
        return 0
    fi
    need sudo "the package install runs as root"
    say "Installing the package needs root; sudo may ask for your password."
    sudo -v || die "sudo failed; nothing was installed."
    # Keep the sudo timestamp fresh while this script runs; stops with it.
    (while kill -0 "$$" 2>/dev/null && sudo -n true 2>/dev/null; do sleep 50; done) </dev/null >/dev/null 2>&1 &
    keepalive_pid=$!
}

install_deb() {
    local file="$1"
    # apt's _apt sandbox user must be able to read the file.
    chmod 0755 "$tmp"
    chmod 0644 "$file"
    as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq </dev/null ||
        warn "apt-get update failed; installing with the package lists as they are."
    local -a opts=(-y)
    if [[ "$action" == downgrade ]]; then
        opts+=(--allow-downgrades)
    fi
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install "${opts[@]}" "$file" </dev/null
}

install_rpm() {
    local file="$1"
    if [[ "$action" == downgrade ]]; then
        as_root dnf downgrade -y "$file" </dev/null
    else
        as_root dnf install -y "$file" </dev/null
    fi
}

# Exec= value for the desktop entry: the path as is when it is plain, else
# quoted with the Desktop Entry spec's escapes: \" \` \$ for those
# characters, and four backslashes for one, because the string escape is
# applied before the quoting rule.
desktop_exec_path() {
    local p="$1"
    if [[ "$p" =~ ^[A-Za-z0-9/._+-]+$ ]]; then
        printf '%s' "$p"
        return
    fi
    p="${p//\\/\\\\\\\\}"
    p="${p//\"/\\\"}"
    p="${p//\`/\\\`}"
    p="${p//\$/\\\$}"
    printf '"%s"' "$p"
}

install_appimage() {
    local file="$1" extracted="$tmp/squashfs-root"
    chmod 0755 "$file"
    (cd "$tmp" &&
        "$file" --appimage-extract "$APP_ID.desktop" >/dev/null &&
        "$file" --appimage-extract "$APP_ID.png" >/dev/null) </dev/null ||
        die "Could not unpack the desktop file and icon from the AppImage."
    [[ -f "$extracted/$APP_ID.desktop" && -f "$extracted/$APP_ID.png" ]] ||
        die "The AppImage holds no $APP_ID.desktop or $APP_ID.png."

    local apps_dir="$data_home/applications"
    local icon_dir="$data_home/icons/hicolor/512x512/apps"
    mkdir -p "$bin_dir" "$apps_dir" "$icon_dir" "$(dirname "$state_file")"

    # Replace by rename so a running Anvil keeps its old file.
    install -m 0755 "$file" "$bin_dir/.anvil.new"
    mv -f "$bin_dir/.anvil.new" "$bin_dir/anvil"
    install -m 0644 "$extracted/$APP_ID.png" "$icon_dir/$APP_ID.png"

    local exec_path line value rest
    exec_path="$(desktop_exec_path "$bin_dir/anvil")"
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            Exec=*)
                value="${line#Exec=}"
                rest=""
                if [[ "$value" == *" "* ]]; then
                    rest=" ${value#* }"
                fi
                printf 'Exec=%s%s\n' "$exec_path" "$rest"
                ;;
            TryExec=*) ;;
            Icon=*) printf 'Icon=%s\n' "$APP_ID" ;;
            *) printf '%s\n' "$line" ;;
        esac
    done <"$extracted/$APP_ID.desktop" >"$apps_dir/.$APP_ID.desktop.new"
    mv -f "$apps_dir/.$APP_ID.desktop.new" "$apps_dir/$APP_ID.desktop"

    printf '%s\n' "$tag" >"$state_file"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
    fi
    say "Installed $bin_dir/anvil, $apps_dir/$APP_ID.desktop and $icon_dir/$APP_ID.png."
    if [[ -e /usr/bin/anvil ]]; then
        warn "/usr/bin/anvil also exists (a system Anvil package). The 'anvil' command runs whichever comes first on PATH, and the menu may list Anvil twice."
    fi
    case ":$PATH:" in
        *":$bin_dir:"*) ;;
        *) warn "$bin_dir is not on PATH; start Anvil from the menu or add it to PATH." ;;
    esac
    if ! command -v fusermount3 >/dev/null 2>&1 && ! command -v fusermount >/dev/null 2>&1; then
        warn "FUSE (fusermount) was not found; the AppImage needs it to start, or run it with APPIMAGE_EXTRACT_AND_RUN=1."
    fi
}

main() {
    local stable=0 check=0 force_appimage=0
    tag=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stable) stable=1 ;;
            --check) check=1 ;;
            --appimage) force_appimage=1 ;;
            -h | --help)
                usage
                exit 0
                ;;
            -*)
                printf 'Error: unknown option %s (see --help)\n' "$1" >&2
                exit 2
                ;;
            *)
                if [[ -n "$tag" ]]; then
                    printf 'Error: only one tag can be given (got %s and %s)\n' "$tag" "$1" >&2
                    exit 2
                fi
                tag="$1"
                ;;
        esac
        shift
    done
    if [[ -n "$tag" && "$stable" -eq 1 ]]; then
        printf 'Error: give either --stable or a tag, not both\n' >&2
        exit 2
    fi
    local mode=newest
    if [[ -n "$tag" ]]; then
        [[ "$tag" == v* ]] || tag="v$tag"
        [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]] ||
            die "'$tag' is not a release tag (vX.Y.Z or vX.Y.Z-rc.N)."
        mode=tag
    elif [[ "$stable" -eq 1 ]]; then
        mode=stable
    fi

    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    need curl "to download the release"
    need sha256sum "to verify the download"
    need python3 "to read the GitHub API's JSON; install it with your package manager"
    local arch
    arch="$(uname -m)"
    [[ "$arch" == x86_64 ]] || die "Anvil is built for x86_64 only; this machine is $arch."

    method="$(detect_method)"
    if [[ "$force_appimage" -eq 1 ]]; then
        method=appimage
    fi
    data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    bin_dir="$HOME/.local/bin"
    state_file="$data_home/anvil/installed-version"

    local suffix how
    case "$method" in
        deb)
            suffix=linux-amd64.deb
            how="deb package with apt-get"
            ;;
        rpm)
            suffix=linux-x86_64.rpm
            how="rpm package with dnf"
            ;;
        appimage)
            suffix=linux-x86_64.AppImage
            how="AppImage in $bin_dir for $(id -un)"
            ;;
    esac

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/anvil-install.XXXXXX")"

    local api="${ANVIL_RELEASES_API:-$DEFAULT_API}"
    api="${api%/}"
    local url rc=0
    case "$mode" in
        newest) url="$api/releases?per_page=100" ;;
        stable) url="$api/releases/latest" ;;
        tag) url="$api/releases/tags/$tag" ;;
    esac
    api_get "$url" "$tmp/release.json" || rc=$?
    if [[ "$rc" -eq 4 ]]; then
        case "$mode" in
            tag) die "There is no published release tagged $tag." ;;
            stable) die "There is no stable release yet; run without --stable for the newest release candidate." ;;
            *) die "The releases API returned 404 for $url" ;;
        esac
    fi

    python3 -I -c "$SELECT_PY" "$tmp/release.json" "$mode" "$tag" "$suffix" >"$tmp/selection" ||
        die "python3 could not read the release data."
    local -a sel
    mapfile -t sel <"$tmp/selection"
    case "${sel[0]:-}" in
        release) ;;
        none)
            case "$mode" in
                tag) die "There is no published release tagged $tag (drafts are never installed)." ;;
                stable) die "There is no stable release yet." ;;
                *) die "No published release found." ;;
            esac
            ;;
        error) die "The releases API sent data that is not JSON: ${sel[1]:-}" ;;
        *) die "Unexpected output while reading the release data." ;;
    esac
    tag="${sel[1]}"
    local kind="${sel[2]}" asset_name="${sel[3]}" asset_url="${sel[4]:-}" digest="${sel[5]:-}"
    local version="${tag#v}"
    if ! semver_parts "$version" >/dev/null; then
        asset_url=""
    fi
    local target="$version"
    if [[ "$method" != appimage ]]; then
        target="${version/-rc./~rc.}"
    fi

    local inst inst_shown
    inst="$(installed_version)"
    inst_shown="${inst/\~rc./-rc.}"

    action=install
    if [[ -n "$inst" && -n "$asset_url" ]]; then
        local cmp
        cmp="$(version_cmp "$inst" "$target")"
        case "$cmp" in
            0) action=current ;;
            -1) action=upgrade ;;
            1)
                if [[ "$mode" == tag ]]; then
                    action=downgrade
                else
                    action=newer
                fi
                ;;
        esac
    fi

    local kind_shown="stable"
    if [[ "$kind" == prerelease ]]; then
        kind_shown="release candidate"
    fi
    say "Release:   $tag ($kind_shown)"
    say "Install:   $how"
    say "Installed: ${inst_shown:-not installed}"

    if [[ -z "$asset_url" ]]; then
        die "Release $tag has no $asset_name, so there is nothing for this host to install. Releases before 0.2.0 are Electron builds this script does not handle; get them from https://github.com/tkforgeworks/anvil/releases."
    fi

    if [[ "$check" -eq 1 ]]; then
        case "$action" in
            install) say "Action:    would install $version" ;;
            upgrade) say "Action:    would upgrade $inst_shown to $version" ;;
            downgrade) say "Action:    would downgrade $inst_shown to $version" ;;
            current) say "Action:    none, already up to date" ;;
            newer) say "Action:    none, the installed $inst_shown is newer (pass the tag to downgrade)" ;;
        esac
        exit 0
    fi

    case "$action" in
        current)
            say "Anvil $version is already up to date."
            exit 0
            ;;
        newer)
            say "The installed Anvil $inst_shown is newer than $tag; not downgrading. To install $tag anyway, pass it: install-anvil.sh $tag"
            exit 0
            ;;
    esac

    if [[ "$method" != appimage ]]; then
        start_sudo
    fi

    local file="$tmp/$asset_name"
    say "Downloading $asset_name"
    local -a progress=(-sS)
    if [[ -t 2 ]]; then
        progress=(--progress-bar)
    fi
    curl -fL --retry 3 "${progress[@]}" -o "$file" "$asset_url" || die "Download failed: $asset_url"
    verify_digest "$file" "$asset_name" "$digest"

    case "$action" in
        install) say "Installing Anvil $version" ;;
        upgrade) say "Upgrading Anvil $inst_shown to $version" ;;
        downgrade) say "Downgrading Anvil $inst_shown to $version" ;;
    esac
    case "$method" in
        deb) install_deb "$file" ;;
        rpm) install_rpm "$file" ;;
        appimage) install_appimage "$file" ;;
    esac

    local now
    now="$(installed_version)"
    if [[ "$now" != "$target" ]]; then
        die "After the install the installed version is '${now:-none}', not $target."
    fi
    say "Anvil $version is installed."
}

main "$@"
