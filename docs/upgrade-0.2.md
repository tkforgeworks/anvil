## Upgrading from Anvil 0.1.x

Anvil 0.2.0 is a rebuild of the app in Flutter. It does what 0.1.6 did, with the differences listed below. Read this before you upgrade if you have been using 0.1.x.

### Your projects

- **Your `.anvil` project files open unchanged.** 0.2.0 uses the same file format and schema as 0.1.6, so nothing is converted when you open a project.
- **0.1.6 and 0.2.0 can open each other's projects**, so you can go back to 0.1.6 if you need to. This holds until a future release changes the schema; its notes will say so.
- **The two versions respect each other's lock.** A project open in one cannot be opened in the other at the same time (`This project is already open in another Anvil window.`). As before, if Anvil crashes and leaves the lock behind, delete the `.anvil.lock` file next to the project file by hand.
- A project from an older 0.1.x release that still needs a schema upgrade gets the same prompt as in 0.1.6: Anvil writes an upgraded copy beside it and leaves the original file unchanged.

### Settings and recent projects start fresh

0.2.0 keeps its settings, recent-projects list and log in a new folder and does not read the 0.1.x ones. The old files are left where they were.

| | 0.2.0 | 0.1.x (not read) |
| :---- | :---- | :---- |
| Windows | `%APPDATA%\TK ForgeWorks\Anvil` | `%APPDATA%\Anvil` |
| Linux | `~/.local/share/com.tkforgeworks.anvil` (under `$XDG_DATA_HOME` when that is set) | `~/.config/Anvil` |

The settings are `app-settings.json`, the recent list is `recent-projects.json`, and the log is `logs/anvil.log` in that folder.

After upgrading:

- **Reopen your projects** with **Open file...** on the Welcome page or **File > Open Project…** in the menu. Each project you open joins the new recent list.
- **Set your preferences again** in **Application Settings** (in the menu, or the settings button on the Welcome page): theme, editing mode (modal or full page), default save location and any custom keyboard shortcuts.
- **A custom theme file from 0.1.x still works.** Choose Custom under Appearance and select the same JSON file.

### Saving works per record

- **Each record saves on its own.** Edit a class, item or any other record, then press **Save** in that editor, or **Ctrl+S** while the editor has focus. The record is written right away, in one step.
- **There is no project-wide Save, no unsaved-project flag and no auto-save.** The auto-save setting and the dashboard's auto-save countdown are gone. The app bar shows whether everything is saved (**All changes saved**, **Unsaved Changes**, **Saving...** or **Save Error**).
- **Anvil asks before you lose changes.** Leaving an editor with unsaved changes offers Save, Discard or Cancel. Closing the project, opening another one or quitting Anvil lists every record with unsaved changes and offers Save all, Discard all or Cancel.
- **Undo and redo work per editor.** Ctrl+Z and Ctrl+Shift+Z (or Ctrl+Y) step through that record's changes. Inside a text field they undo the typing in that field instead.
- **The class editor has one Save.** Stat growth, derived stat overrides, metadata fields and ability assignments now save together with the rest of the class instead of panel by panel. Ability and class assignments on classes and NPCs can now be undone like any other edit.
- **Delete, restore and duplicate in lists offer Undo** in a message at the bottom of the window for a few seconds.

### Export and validation use saved records

Exports and the project-wide Validation page work from what you have saved. Changes still open in an editor are not included until you save them; the Export page tells you when any record has unsaved changes.

### Custom export templates

0.2.0 renders custom templates with its own engine, which supports a subset of Nunjucks covering everything the 0.1.x writing guide documented: `{{ }}` output, comments, whitespace control, `for` (with `else` and `loop.*`), `if` / `elif` / `else`, `set`, the usual operators, and the filters `json`, `export_key`, `dump`, `length`, `upper`, `lower`, `capitalize`, `title`, `trim`, `default` (`d`), `replace`, `join`, `first`, `last` and `reverse`. A template that stays within that subset produces the same output as in 0.1.6, byte for byte. The full list is in the **Template writing guide** in the template editor.

- **Templates that use anything else are disabled, never changed.** Macros, `include`, `import`, `extends` and blocks, `raw`, `filter` and `call` blocks, `{% set %}` blocks, `is` tests, function or method calls (such as `range()`), keyword arguments and other filters are not supported. When you open the Export page, Anvil tells you how many templates need changes, shows a warning for each one with the line and column of the first unsupported part, and greys it out in the template list until you edit it. The warning's **Edit** button opens the template at that position. Anvil never rewrites or deletes the template.
- As in 0.1.6, `export_key` turns the id of a class, ability, item, recipe, NPC or loot table into its export key; ids of stats, rarities, item categories, NPC types, crafting stations, crafting specializations and derived stats print unchanged.

**A security fix for templates.** In 0.1.x, custom export templates were not isolated from the rest of the app: a template written to do so could run arbitrary code on your computer with the same access as Anvil. Templates are stored inside project files, so this matters when you open a project or a template someone else made. 0.2.0's template engine can only read your project data and write the export, so this can no longer happen. If you keep using 0.1.x, only open projects and use templates from people you trust. Upgrading to 0.2.0 closes the issue.

### Also new in 0.2.0

- **Project templates.** New Project offers Blank (0.1.6's starter stats, rarities and categories), Fantasy RPG and Sci-Fi RPG.
- **Right-click a row in any list** for Edit, Duplicate, Export (opens the Export page with just that record selected) and Move to Recycle Bin.
- **Formula fill** on a class's Stat Growth tab fills a range of levels from a step, a multiplier with a cap, an approach to a limit, or an expression.

### Window and app

- **Anvil uses your operating system's normal window frame** and title bar instead of 0.1.x's custom title bar. The minimum window size is still 1400 × 600.
- **Usage telemetry is gone.** 0.1.x release candidate builds could record a usage log on your computer; 0.2.0 records none. The application log is kept.
- **Windows only:** the 0.2.0 installer removes a 0.1.x installation for your user before it installs, so you end up with one Anvil in Apps. Your projects are not touched and the 0.1.x settings folder is kept. A 0.1.x installed for all users is replaced only when you install 0.2.0 for all users; otherwise both stay installed side by side. The installer is not signed, so Windows SmartScreen may warn on first run (More info, then Run anyway).
