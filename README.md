# Anvil — RPG Resource Manager

Anvil is a desktop application for managing RPG game data. It gives game developers a structured, project-based workspace for defining and exporting the core data domains of any RPG: character classes, abilities, items, crafting recipes, NPCs, and loot tables. Each project lives in a self-contained `.anvil` file (a SQLite database) that can be versioned, shared, and backed up independently.

Anvil is game-agnostic — it ships with sensible RPG defaults but allows full schema customization per project.

> **Status:** Pre-release (v0.1.x). All six domain editors, the validation engine, export system, and full project lifecycle are implemented and in active testing. See [Releases](https://github.com/tkforgeworks/anvil/releases) for builds.

---

## What It Does

- **Project Management** — Create, open, save, and manage `.anvil` project files with auto-save, file locking, and non-destructive migration
- **Class Editor** — Define character classes with primary stat growth curves, user-defined derived stat formulas, resource multipliers, and ability assignments
- **Ability Editor** — Manage reusable ability records (first-class domain) assignable to both classes and NPCs
- **Item Editor** — Manage items across user-defined categories with configurable custom fields and rarity tiers
- **Crafting Recipe Editor** — Define crafting recipes with ingredient lists, output items, station requirements, and specialization prerequisites
- **NPC Editor** — Manage enemies and NPCs with class-based stat inheritance (additive, multi-class), loot table assignment, and ability assignment
- **Loot Table Editor** — Define standalone drop tables with integer weight-based probability visualization and item resolution
- **Cross-Domain Validation** — Continuous referential integrity checks, configurable severity levels, and an export gate that blocks on errors
- **Export Engine** — Template-based export (Nunjucks) with built-in presets (Nested JSON, Flat JSON, CSV), custom templates, selective export with dependency resolution
- **Recycle Bin & Bulk Operations** — Soft-delete with restore, bulk actions across domains, per-record and project-wide recycle bin with impact summaries
- **Undo/Redo** — Per-record undo/redo (Ctrl+Z/Y) across all editor pages
- **Dashboard** — Project overview with record counts, weekly deltas, save history feed, validation summary, and quick-add
- **Application & Project Settings** — Theme selection (dark/light/custom), editing mode (modal/full-page), stat/rarity/station/specialization CRUD, custom fields

### Out of Scope (v1)

No sprite/asset management, dialogue branching logic, combat simulation, multiplayer/cloud sync, or runtime game integration.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Desktop runtime | Electron 41 |
| UI framework | React 18 + TypeScript 5.5 |
| UI component library | Material UI (MUI) 6 |
| State management | Zustand 5 |
| Main process | Node.js + TypeScript |
| Database | SQLite via `better-sqlite3` 12 |
| IPC | Electron `contextBridge` (preload) |
| Template engine | Nunjucks |
| Charting | Recharts |
| Bundler | Vite (`electron-vite` 5) |
| Packager | Electron Forge 7 |

---

## Repository Structure

```
anvil/
├── archive/                                      # Planning documents
│   ├── Anvil_PRD_v1_4.md                        # Product Requirements Document (source of truth)
│   └── Anvil_Architecture_and_Schema_Design.md  # Prior design doc (superseded)
├── design_notes/
│   └── Anvil_Implementation_Design_v1_0.md      # Current architecture & implementation strategy
├── src/
│   ├── main/                    # Electron main process
│   │   ├── index.ts             # Entry point — IPC registration, window creation, app shutdown hooks
│   │   ├── db/
│   │   │   ├── connection.ts    # SQLite singleton (openDatabase, getDb, closeDatabase)
│   │   │   └── migrations/      # Sequential migration runner + migration files
│   │   ├── export/              # Context assembler + Nunjucks renderer
│   │   ├── formula/             # Recursive-descent formula engine (derived stats, stat growth)
│   │   ├── ipc/                 # IPC handlers for all domains and lifecycle operations
│   │   ├── lifecycle/           # Cross-domain bulk delete/restore/impact analysis
│   │   ├── logging/             # Application logger + telemetry writer + log rotation
│   │   ├── project/             # Project lifecycle: create/open/save/locking/recovery/folder structure
│   │   ├── repositories/        # Domain repositories (classes, abilities, items, recipes, NPCs, loot tables)
│   │   ├── settings/            # Application settings persistence
│   │   └── validation/          # Validation engine — referential integrity, formula, custom field checks
│   ├── preload/
│   │   └── index.ts             # contextBridge — exposes window.anvil with channel allowlist
│   ├── renderer/
│   │   ├── api/                 # Typed IPC client stubs (one file per domain)
│   │   └── src/
│   │       ├── main.tsx         # React root — ThemeProvider + HashRouter
│   │       ├── App.tsx          # Route tree (11 routes)
│   │       ├── components/      # Shared UI: AppShell, Sidebar, TitleBar, editors, dialogs
│   │       ├── pages/           # Welcome, dashboard, settings, and all domain list/editor pages
│   │       ├── stores/          # Zustand stores (project, ui, lifecycle, settings, domain stores)
│   │       └── themes/          # MUI dark/light theme objects
│   └── shared/
│       ├── ipc-channels.ts      # All IPC channel name constants
│       ├── ipc-types.ts         # AnvilBridge interface (shared main/renderer contract)
│       └── domain-types.ts      # Base domain record types
├── electron.vite.config.ts      # electron-vite build config (main/preload/renderer targets)
├── forge.config.ts              # Electron Forge packaging config
├── tsconfig.json                # Root tsconfig (references main + renderer)
├── tsconfig.main.json           # Main/preload TypeScript config (Node target)
├── tsconfig.renderer.json       # Renderer TypeScript config (DOM target)
├── .claude/
│   └── CLAUDE.md                # Project instructions for Claude Code
└── README.md
```

---

## Getting Started

**Prerequisites:** Node.js 20+, npm 10+

```bash
npm install
npm run rebuild   # Recompile better-sqlite3 native addon against the installed Electron version
npm run dev       # Development mode with HMR
npm run make      # Build and package for current platform
```

> **Note on `npm run rebuild`:** `better-sqlite3` is a native Node.js addon and must be compiled against the exact Electron version in use. Run this once after `npm install` and again after any Electron version upgrade.

---

## Development Status

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | All 6 domain editors, project lifecycle, formula engine, validation, custom fields, export, settings, undo/redo, recycle bin, bulk operations, UI standardization | Complete |
| **Phase 2** | Multi-class comparison, project templates, data import, advanced search/filter | Planned |

---

## Roadmap

Planned work for upcoming releases:

- **Multi-class stat comparison view** — Side-by-side stat growth and derived stat comparison across classes
- **Project templates** — Start new projects from saved templates with pre-configured meta-data
- **Data import** — Import records from external sources (CSV, JSON)
- **macOS builds** — Distribution for macOS alongside existing Windows and Linux builds
- **Additional export presets** — More built-in export template options beyond JSON and CSV

---

## Architecture Overview

### Main Process / Renderer Split

All IPC between the Electron main process and the React renderer passes through a typed `contextBridge`. The renderer holds no database connection and calls no Node.js APIs directly. All data reads and writes are IPC calls to the main process, which owns SQLite access, formula evaluation, export rendering, and file I/O.

The preload script (`src/preload/index.ts`) exposes `window.anvil` with two methods: `invoke(channel, ...args)` (validates against an explicit channel allowlist before forwarding) and `on(channel, callback)` (push events from main, returns an unsubscribe function).

### Project File

`.anvil` files are SQLite databases. The schema is organized into four logical layers:

1. **Project metadata** — name, game title, schema version, level range, project-level settings
2. **Meta-layer definitions** — stat definitions, rarity tiers, item categories, NPC types, crafting stations (the project's configurable vocabulary)
3. **Custom field schemas** — EAV field definitions per item category and NPC type
4. **Domain records** — the six first-class data domains and their sub-tables

Schema changes are applied via the sequential migration runner in `src/main/db/migrations/`. Each migration runs in a transaction and is tracked in a `schema_migrations` table.

### Identity Model

Every domain record has three identity fields: an immutable internal ID (used in all cross-domain references), a display name (shown in UI), and a user-editable export key (written to export output). Renaming a record never breaks references because references store the internal ID, not the display name.

### Validation

Validation runs on save, on export, and on demand. Issues are surfaced inline in editors and aggregated in a global Validation Panel. Export is blocked when any Error-severity issue exists. Soft-deleted records generate configurable-severity issues on their references rather than breaking them.

### Export

The export engine assembles a full context object (all six domains + project meta) and renders it through a Nunjucks template. Three built-in presets ship with the application (Nested JSON, Flat JSON, CSV). Users can create and save custom templates per project. Export scope can be the full project, a single domain, or a hand-selected record set.
