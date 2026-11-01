import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

void main() {
  final copy = FixtureCopy.setUpEach();

  test('runProject on a background isolate matches validateProject', () async {
    final path = copy().copyFixture();
    final before = File(path).readAsBytesSync();

    final background = await ValidationService(projectPath: path).runProject();

    expect(File(path).readAsBytesSync(), before);
    expect(File('$path-wal').existsSync(), isFalse);
    expect(File('$path-journal').existsSync(), isFalse);

    final db = copy().track(ProjectDatabase.open(path));
    expect(background, validateProject(db));
    expect(background, isNotEmpty);
  });

  test('runProject reads a WAL project while the UI handle is open', () async {
    final db = copy().openFixture();
    // ignore: invalid_use_of_internal_member
    db.handle.execute(
      "UPDATE project_info SET soft_delete_reference_severity = 'Error'",
    );
    // ignore: invalid_use_of_internal_member
    db.handle.execute(
      'INSERT INTO npc_ability_assignments (npc_id, ability_id) '
      "VALUES ('1fdfd4c3-bf59-405d-9a77-f4ad056d82b4', "
      "'b252cd54-6b6e-4534-b5dc-5b5c2d53262b')",
    );

    final background = await ValidationService(projectPath: db.path)
        .runProject();

    expect(background, validateProject(db));
    expect(
      background.map((i) => i.message),
      contains("Assignment references soft-deleted ability 'Retired Move'."),
    );
  });
}
