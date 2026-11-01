import '../domain/custom_template.dart';

/// Custom export templates: replaces 0.1.6's `export:list-custom-templates`,
/// `create-template`, `update-template` and `delete-template` channels
/// (`export.handlers.ts`).
///
/// Every mutation is one save transaction recorded in the save history as
/// `<name> - Template changed` (0.1.6 wrote no history for templates;
/// design §6.4). Errors: [get], [update] and [delete] throw
/// `RecordNotFound('custom_templates', id)` for an unknown id (0.1.6's
/// delete did nothing).
abstract interface class TemplateRepository {
  /// Ordered by name ignoring case, as 0.1.6's `getCustomTemplates`.
  Future<List<CustomTemplate>> list();

  Future<CustomTemplate> get(String id);

  /// Stores a new template with a fresh id; both timestamps are the
  /// current time as ISO text, as 0.1.6's `new Date().toISOString()`.
  Future<CustomTemplate> create(CreateTemplateInput input);

  /// Overwrites the fields [input] sets and sets `updated_at` to
  /// `datetime('now')` text, as 0.1.6 did.
  Future<CustomTemplate> update(String id, UpdateTemplateInput input);

  Future<void> delete(String id);
}
