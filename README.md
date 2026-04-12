# Anvil — RPG Resource Manager

Anvil is a desktop application for managing RPG game data. It gives game developers a structured, project-based workspace for defining and exporting the core data domains of any RPG: character classes, abilities, items, crafting recipes, NPCs, and loot tables. Each project lives in a self-contained `.anvil` file (a SQLite database) that can be versioned, shared, and backed up independently.

Anvil is game-agnostic — it ships with sensible RPG defaults but allows full schema customization per project.

> **Status:** Pre-implementation — planning and architecture phase. No source code yet.

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
| Desktop runtime | Electron |
| UI framework | React + TypeScript |
| UI component library | Material UI (MUI) |
| State management | Zustand |
| Main process | Node.js + TypeScript |
| Database | SQLite via `better-sqlite3` |
| IPC | Electron `contextBridge` (preload) |
| Template engine | Nunjucks |
| Charting | Recharts |
| Bundler | Vite (`electron-vite`) |
| Packager | Electron Forge |

---

## Repository Structure

```
anvil/
├── archive/                              # Planning documents
│   ├── Anvil_PRD_v1_4.md                # Product Requirements Document (source of truth)
│   └── Anvil_Architecture_and_Schema_Design.md  # Prior design doc (superseded)
├── Anvil_Implementation_Design_v1_0.md  # Current architecture & implementation strategy
├── .claude/
│   └── CLAUDE.md                        # Project instructions for Claude Code
└── README.md
```

Source code structure (`src/`) will be established during the bootstrapping epic.

---

## Getting Started

> The project is not yet bootstrapped. Commands below are the intended development workflow.

**Prerequisites:** Node.js 20+, npm 10+

```bash
npm install
npm run dev    # Development mode with HMR
npm run make   # Build and package for current platform
```

---

## Architecture Overview

### Main Process / Renderer Split

All IPC between the Electron main process and the React renderer passes through a typed `contextBridge`. The renderer holds no database connection and calls no Node.js APIs directly. All data reads and writes are IPC calls to the main process, which owns SQLite access, formula evaluation, export rendering, and file I/O.

### Project File

`.anvil` files are SQLite databases. The schema is organized into four logical layers:

1. **Project metadata** — name, game title, schema version, level range, project-level settings
2. **Meta-layer definitions** — stat definitions, rarity tiers, item categories, NPC types, crafting stations (the project's configurable vocabulary)
3. **Custom field schemas** — EAV field definitions per item category and NPC type
4. **Domain records** — the six first-class data domains and their sub-tables

### Identity Model

Every domain record has three identity fields: an immutable internal ID (used in all cross-domain references), a display name (shown in UI), and a user-editable export key (written to export output). Renaming a record never breaks references because references store the internal ID, not the display name.

### Validation

Validation runs on save, on export, and on demand. Issues are surfaced inline in editors and aggregated in a global Validation Panel. Export is blocked when any Error-severity issue exists. Soft-deleted records generate configurable-severity issues on their references rather than breaking them.

### Export

The export engine assembles a full context object (all six domains + project meta) and renders it through a Nunjucks template. Three built-in presets ship with the application (Nested JSON, Flat JSON, CSV). Users can create and save custom templates per project. Export scope can be the full project, a single domain, or a hand-selected record set.
