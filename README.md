# Anvil — RPG Resource Manager

Anvil is a desktop application for managing RPG game data. It gives game developers a structured, project-based workspace for defining and exporting the core data domains of any RPG: character classes, abilities, items, crafting recipes, NPCs, and loot tables. Each project lives in a self-contained `.anvil` file (a SQLite database) that can be versioned, shared, and backed up independently.

Anvil is game-agnostic — it ships with sensible RPG defaults but allows full schema customization per project.

> **Status:** Anvil 0.2.0 is a Flutter desktop app for Windows and Linux. 0.1.6 (October 2026) was the final Electron release; its source is at git tag `v0.1.6`. See [Releases](https://github.com/tkforgeworks/anvil/releases) for builds.

---

## Install

The install scripts (Anvil 0.2.0 and later) pick a release from GitHub, download the right file for your machine, check it against the sha256 digest GitHub publishes, and install it. Run the same command again to update. Without a version they never downgrade.

**Linux** (x86_64): the deb with apt on Debian and Ubuntu, the rpm with dnf on Fedora, otherwise the AppImage for your user only (`~/.local/bin/anvil` plus a menu entry). It needs `curl` and `python3`, and asks for `sudo` once for the deb or rpm.

```bash
# newest release, release candidates included
curl -fsSL https://raw.githubusercontent.com/tkforgeworks/anvil/main/scripts/install/install-anvil.sh | bash
# newest stable release
curl -fsSL https://raw.githubusercontent.com/tkforgeworks/anvil/main/scripts/install/install-anvil.sh | bash -s -- --stable
# one version (may downgrade)
curl -fsSL https://raw.githubusercontent.com/tkforgeworks/anvil/main/scripts/install/install-anvil.sh | bash -s -- v0.2.0
```

`--check` shows what would be installed and changes nothing, and `--appimage` installs the AppImage on a deb or rpm system too. `--help` lists every option.

**Windows** (x64, Windows PowerShell 5.1 or PowerShell 7): runs the installer silently, for the current user unless you pass `-AllUsers` from an elevated PowerShell.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/tkforgeworks/anvil/main/scripts/install/install-anvil.ps1))) -Stable
```

Leave out `-Stable` to get the newest release including release candidates, or pass `-Tag v0.2.0` for one version. `-Check`, `-InstallDir` and `-Help` are also available. Close Anvil first: the installer asks a running Anvil to close and does not reopen it.

These URLs serve the scripts from `main`, so they work once 0.2.0 has shipped. Until then, run them from a checkout of `v0.2.0/main`: `bash scripts/install/install-anvil.sh`, or on Windows `powershell -ExecutionPolicy Bypass -File scripts\install\install-anvil.ps1`.

**By hand.** Download the file for your platform from [Releases](https://github.com/tkforgeworks/anvil/releases):

| Platform | File | Install |
|---|---|---|
| Windows | `anvil-<version>-windows-x64-setup.exe` | Run it (Windows SmartScreen warns because it is unsigned: More info → Run anyway). `…-windows-x64.zip` is the same app unpacked, with no installer. |
| Debian, Ubuntu | `anvil-<version>-linux-amd64.deb` | `sudo apt install ./anvil-<version>-linux-amd64.deb` |
| Fedora | `anvil-<version>-linux-x86_64.rpm` | `sudo dnf install ./anvil-<version>-linux-x86_64.rpm` |
| Other Linux | `anvil-<version>-linux-x86_64.AppImage` | `chmod +x` it and run it |

The 0.2.0 packages replace an installed 0.1.x. [`docs/upgrade-0.2.md`](docs/upgrade-0.2.md) covers what changes for 0.1.x users. The 0.1.x releases use different file names, and the scripts do not install them.

---

## About the app

Anvil opens the same `.anvil` SQLite project files as 0.1.x. The architecture is `design_notes/Anvil_Implementation_Design_v2_0.md`.

**Upgrading from 0.1.x.** [`docs/upgrade-0.2.md`](docs/upgrade-0.2.md) is the user-facing note on what changes for 0.1.x users: per-record saving, settings and recent projects starting fresh in a new folder, custom templates outside the supported subset, and the 0.1.x template security fix. It heads each 0.2.0 release's notes.

### What it does

- **Projects** — create, open and back up `.anvil` files with file locking and non-destructive migration; New Project offers Blank, Fantasy RPG and Sci-Fi RPG templates
- **Domain editors** — character classes (stat growth curves, derived stat formulas, ability assignments), abilities, items (categories, rarities, custom fields), crafting recipes, NPCs (class-based stat inheritance, loot table and ability assignment) and loot tables (weighted entries)
- **Validation** — referential integrity, formula and custom-field checks, inline and in a project-wide panel, with an export gate that blocks on errors
- **Export** — Nested JSON, Flat JSON and CSV presets, custom templates in a Nunjucks-compatible subset, full, per-domain or hand-selected scope
- **Recycle bin and bulk operations** — soft delete with restore, impact summaries, undo snackbars
- **Undo/redo** — per-record, Ctrl+Z / Ctrl+Y in every editor
- **Dashboard, menu and shortcuts** — record counts, save history, validation summary, a hamburger menu with remappable shortcuts
- **Settings** — Dark / Light / Custom theme file, modal or full-page editing, project stats, rarities, crafting lists, derived stats and custom fields

Out of scope: sprite or asset management, dialogue logic, combat simulation, multiplayer or cloud sync, runtime game integration.

### Repository layout

| Path | What it is |
|---|---|
| `pubspec.yaml`, `lib/`, `test/` | The Flutter app (`anvil`). `lib/main.dart` is the entry point. |
| `lib/app/` | App code by feature, for example `theme/`, `shell/`, `menu/`, `editor/`, `lists/`, `domains/`, `dashboard/`, `export/`, `settings/`, `validation/`, `recycle_bin/` and `welcome/`. |
| `packages/anvil_core/` | The Flutter-free core: data access, project lifecycle, formula, validation and export logic. A member of the root pub workspace. |
| `linux/`, `windows/` | Desktop runners; `linux/packaging/` and `windows/installer/` hold the package definitions. |
| `scripts/release/`, `scripts/install/` | Release build and version scripts; install and update scripts with their tests. |
| `design_notes/` | Design documents. |
| `docs/` | `testing.md` and the 0.2 upgrade note. |
| `.fvmrc` | Pins Flutter 3.47.5, the SDK the org CI and `forge-ui` use. |

**Theme.** The app theme is built on the shared [`forge_ui`](https://github.com/tkforgeworks/forge-ui) package. Colours come from the theme, never literals; `test/theme/no_hardcoded_colors_test.dart` enforces it. A custom theme JSON file from Anvil 0.1.x (`mode` plus up to eleven colour keys) still works.

**Core/UI boundary.** `packages/anvil_core` must never depend on `package:flutter`. Its `pubspec.yaml` has no Flutter dependency, so any Flutter import fails `flutter analyze`; everything in the core runs under plain `dart test`. The app depends on the core, never the other way round.

### Working on it

```bash
fvm use 3.47.5                 # once per clone; installs the pinned SDK
fvm flutter pub get            # resolves the whole workspace
fvm flutter run -d linux       # or: -d windows
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test test packages/anvil_core/test   # app + core (a bare `flutter test` runs only test/)
```

[`docs/testing.md`](docs/testing.md) covers the test suites. Release packages are built by CI, not by hand: `scripts/release/build-windows.ps1` (Inno Setup installer and zip) and `scripts/release/build-linux.sh` (AppImage, deb and rpm from `linux/packaging/`), both run by the org `release-flutter.yml` workflow when an RC or release is cut. Flutter build output goes to `build/`, which is ignored.

The 0.1.x Electron source is not in this repository any more; check out tag `v0.1.6` to read it or to re-run the fixture oracles (see `packages/anvil_core/test/fixtures/README.md`).

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Image assets (logos, icons,
illustrations, screenshots) are **not** covered and are all rights reserved;
see [`NOTICE`](NOTICE).
