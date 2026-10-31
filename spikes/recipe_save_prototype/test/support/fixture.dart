import 'dart:io';

import 'package:recipe_save_prototype/src/core/project_database.dart';

/// The real project file, created with Electron Anvil 0.1.6. Never opened
/// directly: every test works on a fresh copy in a temp directory.
const fixturePath = 'test/fixtures/sample-0.1.6.anvil';

const forgeIronSwordId = 'a7a5c929-8193-457c-bedd-eea367abf255';
const brewHealingPotionId = '2f3bcc27-2306-43c3-99ee-87b9319fd960';
const ironIngotId = '11a74879-0851-4af7-8ff1-7be63edae9f2';
const leatherStripId = '990f8604-827f-4890-b130-122bf252788a';
const ironSwordId = '6069c26a-d758-4981-b29b-eed2c95fe6f3';
const moonpetalHerbId = '65e565f0-6126-4927-b3f7-cccc4c3ed0f3';
const healingPotionId = 'a4b66c54-05d2-4007-bed7-8f13bee1f087';

final class FixtureCopy {
  FixtureCopy._(this.dir, this.project);

  factory FixtureCopy.open() {
    final dir = Directory.systemTemp.createTempSync('anvl158-test-');
    return FixtureCopy._(
      dir,
      ProjectDatabase.openCopy(fixturePath, workDir: dir),
    );
  }

  final Directory dir;
  final ProjectDatabase project;

  /// Everything the save touches, for before/after comparison.
  Map<String, Object?> snapshot(String recipeId) {
    final db = project.db;
    return {
      'recipe': db
          .select('SELECT * FROM recipes WHERE id = ?', [recipeId])
          .map((r) => Map<String, Object?>.of(r))
          .toList(),
      'ingredients': db
          .select(
            'SELECT item_id, quantity, sort_order FROM recipe_ingredients '
            'WHERE recipe_id = ? ORDER BY sort_order',
            [recipeId],
          )
          .map((r) => Map<String, Object?>.of(r))
          .toList(),
      'historyCount': db
          .select('SELECT COUNT(*) AS n FROM save_history')
          .first['n'],
    };
  }

  int historyCount() =>
      project.db.select('SELECT COUNT(*) AS n FROM save_history').first['n']
          as int;

  void close() {
    project.close();
    dir.deleteSync(recursive: true);
  }
}
