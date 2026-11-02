/// The project data the Stat Growth and Derived Stats tabs read: the
/// abilities tests' two stats plus derived stat definitions and a max
/// level the tests can change mid-edit.
library;

import 'package:anvil_core/anvil_core.dart';

import '../abilities/fakes.dart';

const hpId = 'derived-hp';
const mpId = 'derived-mp';

/// Health (`strength * 10`, an integer floored) and Mana
/// (`intelligence * 5 + hp / 4`, a float that depends on Health).
const sampleDerivedStats = [
  DerivedStatDefinition(
    id: hpId,
    displayName: 'Health',
    exportKey: 'hp',
    formula: 'strength * 10',
    outputType: DerivedStatOutputType.integer,
    roundingMode: RoundingMode.floor,
    sortOrder: 1,
  ),
  DerivedStatDefinition(
    id: mpId,
    displayName: 'Mana',
    exportKey: 'mp',
    formula: 'intelligence * 5 + hp / 4',
    outputType: DerivedStatOutputType.float,
    roundingMode: RoundingMode.none,
    sortOrder: 2,
  ),
];

/// [FakeStatsRepository] that also answers [listDerivedStats] and
/// [loadProjectSettings] (only its max level matters here).
class FakeClassMetaRepository extends FakeStatsRepository {
  FakeClassMetaRepository();

  List<DerivedStatDefinition> derivedStats = sampleDerivedStats;
  int maxLevel = 10;
  var settingsLoads = 0;

  @override
  Future<List<DerivedStatDefinition>> listDerivedStats() async => derivedStats;

  @override
  Future<ProjectSettingsDraft> loadProjectSettings() async {
    settingsLoads++;
    return ProjectSettingsDraft(
      gameTitle: 'Test',
      maxLevel: maxLevel,
      softDeleteReferenceSeverity: SoftDeleteReferenceSeverity.warning,
    );
  }
}
