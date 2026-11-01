/// Custom export templates, the rows of `custom_templates`.
///
/// Ported from 0.1.6's `CustomTemplate` (`src/main/ipc/export.handlers.ts`
/// and `src/renderer/api/export.api.ts`) and the create/update payloads of
/// the `export:*-template` channels.
library;

/// One stored template; ports 0.1.6 `CustomTemplate`.
class CustomTemplate {
  const CustomTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.templateSource,
    required this.format,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;

  /// The template text as stored; never rewritten, even when the renderer
  /// cannot run it (design §11.5).
  final String templateSource;

  /// Free text: 0.1.6's editor offered `text`, `json` and `csv`.
  final String format;

  /// Passed through as stored: a template created by 0.1.6 or 0.2.0 has an
  /// ISO `YYYY-MM-DDTHH:MM:SS.sssZ` creation time, an updated one
  /// `datetime('now')` text, and rows written by other means the column
  /// default `datetime('now')`.
  final String createdAt;
  final String updatedAt;

  @override
  bool operator ==(Object other) =>
      other is CustomTemplate &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.templateSource == templateSource &&
      other.format == format &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    templateSource,
    format,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'CustomTemplate($id, $name, $format)';
}

/// Ports 0.1.6's create payload
/// `{name, description?, template_source, format?}`.
class CreateTemplateInput {
  const CreateTemplateInput({
    required this.name,
    required this.templateSource,
    this.description = '',
    this.format = 'text',
  });

  final String name;
  final String templateSource;
  final String description;
  final String format;
}

/// Ports 0.1.6's update payload: every field optional, null keeps the
/// stored value (no column is nullable, so nothing is ever cleared).
class UpdateTemplateInput {
  const UpdateTemplateInput({
    this.name,
    this.description,
    this.templateSource,
    this.format,
  });

  final String? name;
  final String? description;
  final String? templateSource;
  final String? format;
}
