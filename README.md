# Anvil — RPG Resource Manager

Anvil is a desktop application for managing RPG game data. It gives game developers a structured, project-based workspace for defining and exporting the core data domains of any RPG: character classes, abilities, items, crafting recipes, NPCs, and loot tables. Each project lives in a self-contained `.anvil` file (a SQLite database) that can be versioned, shared, and backed up independently.

Anvil is game-agnostic — it ships with sensible RPG defaults but allows full schema customization per project.

> **Status:** Project lifecycle is implemented and schema foundation work is underway. Users can create/open `.anvil` projects, see recent projects and dashboard counts, save/Save As with status feedback, and rely on file locking, schema migration, and recovery-mode guards. Domain repository CRUD and full domain editors are still in progress.

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
- **Export Engine** — Template-based export (Nunjucks) with built-in presets (Nested JSON, Flat JSON, CSV) and selective export with dependency resolution

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
│   │   ├── ipc/                 # Project/domain IPC handlers (some domain create/update paths still stubbed)
│   │   ├── project/             # Project lifecycle service: create/open/save/Save As/locking/recovery
│   │   ├── repositories/        # Shared domain repository foundation
│   │   └── settings/            # Application settings persistence
│   ├── preload/
│   │   └── index.ts             # contextBridge — exposes window.anvil with channel allowlist
│   ├── renderer/
│   │   ├── api/                 # Typed IPC client stubs (one file per domain)
│   │   └── src/
│   │       ├── main.tsx         # React root — ThemeProvider + HashRouter
│   │       ├── App.tsx          # Route tree (11 routes)
│   │       ├── components/      # AppShell, Sidebar, TitleBar
│   │       ├── pages/           # Welcome, dashboard, and domain placeholder pages
│   │       ├── stores/          # Zustand stores (ui + 10 domain stores)
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
| **Phase 1** | Character Classes, Abilities, Items, Crafting Recipes; project lifecycle; formula engine; validation; custom fields | In progress |
| **Phase 2** | NPC editor, Loot Table editor, export system, archive views, bulk ops, undo/redo | Not started |

### Completed epics

| Epic | Description |
|---|---|
| ANV-4 | Project bootstrap — Electron + electron-vite setup, IPC bridge, SQLite layer, React Router shell, MUI theme, Zustand stores |
| ANV-5 | Project file and lifecycle management — create/open/recent projects, dashboard, save/Save As, auto-save/status feedback, file locking, non-destructive migration, recovery-mode guards |

### Current work

| Epic | Description | Status |
|---|---|---|
| ANV-6 | Data model and schema foundation | In progress |

ANV-6 currently has migration 001 and migration 002 implemented for the initial schema and default meta-layer seed data. Remaining work is focused on the typed domain repository layer and wiring create/update/delete IPC paths for all six domains.

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
