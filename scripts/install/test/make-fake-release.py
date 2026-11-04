#!/usr/bin/env python3
"""Writes a fake tkforgeworks/anvil release set for testing the install scripts.

The output directory is meant to be served with `python3 -m http.server`
from its root, with the install scripts pointed at it through
ANVIL_RELEASES_API=<base-url>/api:

  api/releases/index.html     GET /releases?per_page=100 (http.server
                              redirects /releases to /releases/ and serves
                              index.html; the query string is ignored)
  api/releases/latest         GET /releases/latest
  api/releases/tags/<tag>     GET /releases/tags/<tag>
  api-old/...                 the same API with only v0.2.0-rc.1 and v0.1.6,
                              for the "installed is newer" (no downgrade) case
  download/<tag>/<name>       the asset files

Releases, newest first, as GitHub lists them:
  v0.3.0        draft (never chosen; GitHub hides drafts from anonymous
                calls, its tags/ file exists here only to test the guard)
  v0.2.0        stable, the --stable-dir packages, real digests
  v0.2.0-rc.1   prerelease, the --rc-dir packages, real digests except the
                AppImage, whose digest is null (the "no digest" warning)
  v0.1.6        stable, the electron-builder asset names of the real 0.1.6
                (no asset an install script accepts)
  v0.0.9        stable, every digest deliberately wrong (the mismatch case)

The Windows assets of v0.2.0 and v0.2.0-rc.1 are small dummy files; only the
PowerShell test's JSON reads them.

Usage: make-fake-release.py --out DIR --stable-dir DIR --rc-dir DIR
                            [--legacy-dir DIR] [--base-url URL]
"""

import argparse
import hashlib
import json
import os
import shutil
import sys

# Digests GitHub lists for the real v0.1.6 assets (checked 2026-11-03), used
# when --legacy-dir does not hold the file.
LEGACY_DIGESTS = {
    "Anvil-0.1.6.AppImage": "e459a4257c9d6de30caf450a562b95e880208f04dad5975e740f5e4bf02d05c2",
    "anvil-0.1.6.x86_64.rpm": "5e60cc57208f747bd8165373860a383ca1f9fc55ab98c247e0876b9be30a26ea",
    "Anvil.Setup.0.1.6.exe": "7eebdf5c4cbaafe064067665d7669f813c387120a8580ff3c581524a736b8e5e",
    "anvil_0.1.6_amd64.deb": "41fa640c8ffee81a431ec7abb9ad4856b4be9a689cfd8c5c8cd4851f29b52638",
}

LINUX_SUFFIXES = ["linux-amd64.deb", "linux-x86_64.rpm", "linux-x86_64.AppImage"]
WINDOWS_SUFFIXES = ["windows-x64-setup.exe", "windows-x64.zip"]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def place(src, dest):
    if os.path.abspath(src) == os.path.abspath(dest):
        return
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(dest):
        os.remove(dest)
    try:
        os.link(src, dest)
    except OSError:
        shutil.copy2(src, dest)


class Builder:
    def __init__(self, out, base_url):
        self.out = out
        self.base = base_url.rstrip("/")
        self.next_id = 1000

    def asset(self, tag, name, path, digest="real"):
        """An asset served from download/<tag>/<name>, copied from path."""
        dest = os.path.join(self.out, "download", tag, name)
        place(path, dest)
        if digest == "real":
            digest = "sha256:" + sha256(dest)
        self.next_id += 1
        return {
            "id": self.next_id,
            "name": name,
            "size": os.path.getsize(dest),
            "digest": digest,
            "browser_download_url": "%s/download/%s/%s" % (self.base, tag, name),
        }

    def dummy(self, tag, name):
        dest = os.path.join(self.out, "download", tag, name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(("dummy %s for the install-script tests\n" % name).encode())
        return self.asset(tag, name, dest)

    def release(self, tag, assets, prerelease=False, draft=False, created="2026-11-01T00:00:00Z"):
        self.next_id += 1
        return {
            "id": self.next_id,
            "tag_name": tag,
            "name": tag,
            "draft": draft,
            "prerelease": prerelease,
            "created_at": created,
            "published_at": None if draft else created,
            "assets": assets,
        }


def linux_files(directory, version):
    files = {}
    for suffix in LINUX_SUFFIXES:
        name = "anvil-%s-%s" % (version, suffix)
        path = os.path.join(directory, name)
        if not os.path.isfile(path):
            sys.exit("missing %s" % path)
        files[suffix] = path
    return files


def write_api(root, releases, latest):
    os.makedirs(os.path.join(root, "releases", "tags"), exist_ok=True)
    with open(os.path.join(root, "releases", "index.html"), "w") as f:
        json.dump(releases, f, indent=2)
    with open(os.path.join(root, "releases", "latest"), "w") as f:
        json.dump(latest, f, indent=2)
    for r in releases:
        with open(os.path.join(root, "releases", "tags", r["tag_name"]), "w") as f:
            json.dump(r, f, indent=2)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", required=True)
    ap.add_argument("--stable-dir", required=True, help="anvil-0.2.0-linux-* packages")
    ap.add_argument("--rc-dir", required=True, help="anvil-0.2.0-rc.1-linux-* packages")
    ap.add_argument("--legacy-dir", help="the real 0.1.6 assets (optional)")
    ap.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = ap.parse_args()

    out = os.path.abspath(args.out)
    for sub in ("api", "api-old", "download"):
        shutil.rmtree(os.path.join(out, sub), ignore_errors=True)
    b = Builder(out, args.base_url)

    stable = linux_files(args.stable_dir, "0.2.0")
    rc = linux_files(args.rc_dir, "0.2.0-rc.1")

    v020_assets = [b.asset("v0.2.0", "anvil-0.2.0-" + s, p) for s, p in stable.items()]
    v020_assets += [b.dummy("v0.2.0", "anvil-0.2.0-" + s) for s in WINDOWS_SUFFIXES]

    rc_assets = []
    for s, p in rc.items():
        digest = None if s.endswith("AppImage") else "real"
        rc_assets.append(b.asset("v0.2.0-rc.1", "anvil-0.2.0-rc.1-" + s, p, digest))
    rc_assets += [b.dummy("v0.2.0-rc.1", "anvil-0.2.0-rc.1-" + s) for s in WINDOWS_SUFFIXES]

    # The draft's assets point at the v0.2.0 files under v0.3.0 names.
    draft_assets = []
    for a in v020_assets:
        d = dict(a)
        d["name"] = a["name"].replace("0.2.0", "0.3.0")
        draft_assets.append(d)

    legacy_assets = []
    for name, known in LEGACY_DIGESTS.items():
        path = os.path.join(args.legacy_dir, name) if args.legacy_dir else None
        if path and os.path.isfile(path):
            legacy_assets.append(b.asset("v0.1.6", name, path))
        else:
            b.next_id += 1
            legacy_assets.append({
                "id": b.next_id,
                "name": name,
                "size": 0,
                "digest": "sha256:" + known,
                "browser_download_url": "https://github.com/tkforgeworks/anvil/releases/download/v0.1.6/" + name,
            })

    wrong = "sha256:" + hashlib.sha256(b"deliberately wrong").hexdigest()
    bad_assets = [b.asset("v0.0.9", "anvil-0.0.9-" + s, p, wrong) for s, p in stable.items()]

    releases = [
        b.release("v0.3.0", draft_assets, draft=True, created="2026-11-03T00:00:00Z"),
        b.release("v0.2.0", v020_assets, created="2026-11-02T00:00:00Z"),
        b.release("v0.2.0-rc.1", rc_assets, prerelease=True, created="2026-11-01T00:00:00Z"),
        b.release("v0.1.6", legacy_assets, created="2026-10-11T00:00:00Z"),
        b.release("v0.0.9", bad_assets, created="2026-01-01T00:00:00Z"),
    ]
    write_api(os.path.join(out, "api"), releases, releases[1])
    old = [r for r in releases if r["tag_name"] in ("v0.2.0-rc.1", "v0.1.6")]
    write_api(os.path.join(out, "api-old"), old, old[1])
    print("fake release written to %s (serve it at %s)" % (out, b.base))


if __name__ == "__main__":
    main()
