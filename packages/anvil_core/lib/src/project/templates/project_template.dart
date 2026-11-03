import 'fantasy_rpg_template.dart';
import 'project_template_content.dart';
import 'sci_fi_rpg_template.dart';

/// The templates a new project can start from (0.1.6 `PROJECT_TEMPLATES`
/// in `src/shared/project-types.ts`, which 0.1.6 offered but never applied).
///
/// Every project is created by the migrations first, which seed 0.1.6's
/// meta layer; a template other than [blank] then replaces that meta layer
/// with its own [content].
enum ProjectTemplate {
  blank(
    'blank',
    'Blank',
    'The generic starter stats, rarities, categories and stations.',
  ),
  fantasyRpg(
    'fantasy-rpg',
    'Fantasy RPG',
    'Might, Arcana and Faith, mythic loot, runic altars and alchemy.',
  ),
  sciFiRpg(
    'sci-fi-rpg',
    'Sci-Fi RPG',
    'Physique, Tech and Reflexes, prototype gear, fabricators and implants.',
  );

  const ProjectTemplate(this.id, this.displayName, this.description);

  /// The 0.1.6 template id.
  final String id;
  final String displayName;

  /// One line for the template picker.
  final String description;

  /// The meta layer this template seeds. Blank's is empty: it keeps what
  /// the migrations seeded.
  ProjectTemplateContent get content => switch (this) {
    blank => ProjectTemplateContent.empty,
    fantasyRpg => fantasyRpgContent,
    sciFiRpg => sciFiRpgContent,
  };

  /// The template with the 0.1.6 [id], or null for an unknown one.
  static ProjectTemplate? fromId(String id) {
    for (final template in values) {
      if (template.id == id) return template;
    }
    return null;
  }
}
