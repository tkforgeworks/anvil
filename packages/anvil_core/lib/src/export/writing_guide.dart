/// The in-app template writing guide for Anvil 0.2.
library;

/// The template writing guide the export page shows next to the template
/// editor, as plain text with Markdown-style headings and code spans.
///
/// It lists exactly what the 0.2 renderer supports: the subset in
/// `template/parser.dart` and the 15 filters in `template/filters.dart`.
/// Anything else is rejected when the template is loaded, with a line and
/// column (design §11.5).
const String templateWritingGuide = r'''
## Context variables

Your template receives these top-level variables:

- `project`: name, game_title, schema_version, max_level
- `meta`: stats, rarities, item_categories, npc_types, crafting_stations, crafting_specializations, derived_stats
- `classes`: array of class records (with stat_growth, abilities, derived_stat_overrides, metadata)
- `abilities`: array of ability records (with stat_modifiers)
- `items`: array of item records (with custom_fields)
- `recipes`: array of recipe records (with ingredients)
- `npcs`: array of NPC records (with class_assignments, ability_assignments, combat_stats, custom_fields)
- `loot_tables`: array of loot table records (with entries)
- `ctx`: the whole context, so `ctx.items` is the same as `items`

## Each record has

- `id`: internal UUID (for references between records)
- `export_key`: user-defined key for external use
- `display_name`: human-readable name
- `description`

## Syntax

- `{{ value }}`: output a value. Outputting a missing or null value is an error; `{% if value %}` and `| default('...')` guard against it.
- `{# comment #}`: a comment, not output.
- `{%- ... -%}`, `{{- ... -}}`, `{#- ... -#}`: a `-` strips the whitespace before or after the tag.
- `{% for item in items %}...{% else %}...{% endfor %}`: loop over an array; the optional `else` part runs when it is empty. `{% for key, value in item.custom_fields %}` loops over an object. Inside a loop, `loop.index`, `loop.index0`, `loop.revindex`, `loop.revindex0`, `loop.first`, `loop.last` and `loop.length` describe the current iteration.
- `{% if condition %}...{% elif other %}...{% else %}...{% endif %}`: conditional (`elseif` also works).
- `{% set x = value %}`: assign a variable (`{% set a, b = value %}` assigns both).
- Values: strings in single or double quotes (`\n`, `\t` and `\r` are the only escapes), numbers, `true`, `false`, `none` or `null`, lists `[1, 2]` and objects `{ 'key': value }`.
- Lookups: `item.display_name`, `item['display_name']`, `items[0]`, and `.length` on arrays and strings.
- Operators: `and`, `or`, `not`, `in`, `not in`; comparisons `==`, `!=`, `===`, `!==`, `<`, `>`, `<=`, `>=`; `~` joins values as text; arithmetic `+`, `-`, `*`, `/`, `//` (divide and round down), `%`, `**`; parentheses; and `a if condition else b`.

## Filters

- `{{ value | json }}`: output as formatted JSON, indented by 2 (`json(4)` for 4, `json(0)` for compact)
- `{{ some_id | export_key }}`: resolve the internal ID of a class, ability, item, recipe, NPC or loot table to its export key. It does not resolve meta ids (stats, rarities, item categories, NPC types, crafting stations, crafting specializations, derived stats): `{{ item.rarity_id | export_key }}` prints the rarity's id unchanged.
- `{{ value | dump }}`: compact JSON (`dump(2)` to indent)
- `{{ value | length }}`: the number of entries in an array or object, or characters in a string
- `{{ text | upper }}`, `{{ text | lower }}`, `{{ text | capitalize }}`, `{{ text | title }}`, `{{ text | trim }}`: change case, or strip surrounding whitespace
- `{{ value | default('fallback') }}` (or `d`): the fallback when the value is missing; `default('fallback', true)` also replaces empty and false values
- `{{ text | replace('old', 'new') }}`: replace every occurrence (an optional third argument limits the count)
- `{{ list | join(', ') }}`: join an array into text; `join(', ', 'export_key')` joins one field of each record
- `{{ list | first }}`, `{{ list | last }}`, `{{ list | reverse }}`: the first or last entry, or the entries in reverse order

## Not supported

Macros, `include`, `import`, `extends` and blocks, `raw`, `filter` and `call` blocks, `{% set %}` blocks, `is` tests, function and method calls (such as `range()`), keyword arguments, and filters other than the ones above. A template that uses one of them is flagged with its line and column and cannot export until it is edited; Anvil never changes it.

## Example

```
# {{ project.game_title }} - Items

{% for item in items %}
## {{ item.display_name }} ({{ item.export_key }})
Category: {{ item.item_category_id | export_key }}
Rarity: {{ item.rarity_id | export_key }}
{{ item.description }}

{% endfor %}
```
''';
