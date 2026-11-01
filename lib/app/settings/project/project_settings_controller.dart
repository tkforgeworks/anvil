/// The state behind the Project Settings dialog's buffered tabs (General,
/// Stats & Formulas, Crafting): 0.1.6 `ProjectSettingsModal`'s
/// `projectSettings`/`originals`/`buffers` (ANVL-121), committed by one
/// `MetaRepository.saveProjectSettings` call (design §13.5).
///
/// The Custom Fields tab is not here: it persists immediately
/// (`custom_fields_controller.dart`).
library;

import 'dart:math';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart' show saveErrorMessage;
import '../../shell/shell_providers.dart';
import 'meta_buffer.dart';

/// The five buffered lists, with the `checkInUse` kind each deletes under
/// and the singular name 0.1.6's sections used.
enum ProjectSettingsList {
  stats(MetaInUseKind.stat, 'Stat'),
  rarities(MetaInUseKind.rarity, 'Rarity'),
  craftingStations(MetaInUseKind.craftingStation, 'Crafting Station'),
  craftingSpecializations(
    MetaInUseKind.craftingSpecialization,
    'Crafting Specialization',
  ),
  derivedStats(MetaInUseKind.derivedStat, 'Derived Stat');

  const ProjectSettingsList(this.inUseKind, this.singularName);

  final MetaInUseKind inUseKind;
  final String singularName;
}

/// 0.1.6's max level coercion, `Math.max(1, parseInt(text, 10) || 100)`:
/// the leading integer of [text], 100 when there is none or it is 0, and
/// at least 1.
int coerceMaxLevel(String text) {
  final match = RegExp(r'^\s*([+-]?\d+)').firstMatch(text);
  final parsed = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  return max(1, parsed == 0 ? 100 : parsed);
}

/// What the dialog edits: the loaded settings as [baseline] and the
/// working values over them.
final class ProjectSettingsState {
  ProjectSettingsState._({
    required this.baseline,
    required this.gameTitle,
    required this.maxLevelText,
    required this.severity,
    required this.stats,
    required this.rarities,
    required this.craftingStations,
    required this.craftingSpecializations,
    required this.derivedStats,
    this.saving = false,
    this.error,
  });

  /// The working values equal to [settings].
  factory ProjectSettingsState.loaded(ProjectSettingsDraft settings) =>
      ProjectSettingsState._(
        baseline: settings,
        gameTitle: settings.gameTitle,
        maxLevelText: '${settings.maxLevel}',
        severity: settings.softDeleteReferenceSeverity,
        stats: MetaBuffer(plainRowKind, settings.stats),
        rarities: MetaBuffer(rarityRowKind, settings.rarities),
        craftingStations: MetaBuffer(plainRowKind, settings.craftingStations),
        craftingSpecializations: MetaBuffer(
          plainRowKind,
          settings.craftingSpecializations,
        ),
        derivedStats: MetaBuffer(derivedStatRowKind, settings.derivedStats),
      );

  /// The settings as stored when the dialog opened or last saved.
  final ProjectSettingsDraft baseline;

  /// The game title field as typed; trimmed into [draft].
  final String gameTitle;

  /// The max level field as typed; coerced into [draft] as 0.1.6 did.
  final String maxLevelText;
  final SoftDeleteReferenceSeverity severity;
  final MetaBuffer<MetaRowDraft> stats;
  final MetaBuffer<RarityRowDraft> rarities;
  final MetaBuffer<MetaRowDraft> craftingStations;
  final MetaBuffer<MetaRowDraft> craftingSpecializations;
  final MetaBuffer<DerivedStatRowDraft> derivedStats;

  /// A save is in flight.
  final bool saving;

  /// Why the last save failed; null after a success or a discard.
  final String? error;

  /// What Save commits.
  ProjectSettingsDraft get draft => ProjectSettingsDraft(
    gameTitle: gameTitle.trim(),
    maxLevel: coerceMaxLevel(maxLevelText),
    softDeleteReferenceSeverity: severity,
    stats: stats.toList(),
    rarities: rarities.toList(),
    craftingStations: craftingStations.toList(),
    craftingSpecializations: craftingSpecializations.toList(),
    derivedStats: derivedStats.toList(),
  );

  bool get isDirty => draft != baseline;

  /// The rules that refuse a save, as messages. 0.1.6 dropped an empty game
  /// title silently and kept the stored one; 0.2.0 refuses the save. Export
  /// keys must be non-empty, and a key that is new or changed must match
  /// [metaExportKeyPattern]; keys already stored are left alone.
  List<String> get blockers {
    final messages = <String>[];
    if (gameTitle.trim().isEmpty) messages.add('Game title is required.');
    void check<T>(
      ProjectSettingsList list,
      MetaBuffer<T> buffer,
      List<T> base,
    ) {
      final stored = {
        for (final r in base) buffer.kind.idOf(r): buffer.kind.exportKeyOf(r),
      };
      for (final row in buffer.toList()) {
        final name = buffer.kind.displayNameOf(row);
        final key = buffer.kind.exportKeyOf(row);
        if (name.trim().isEmpty) {
          messages.add('${list.singularName} display name is required.');
        }
        if (key.trim().isEmpty) {
          messages.add('${list.singularName} "$name" needs an export key.');
        } else if (stored[buffer.kind.idOf(row)] != key &&
            !metaExportKeyPattern.hasMatch(key)) {
          messages.add(
            '${list.singularName} "$name": $metaExportKeyPatternMessage',
          );
        }
      }
    }

    check(ProjectSettingsList.stats, stats, baseline.stats);
    check(ProjectSettingsList.rarities, rarities, baseline.rarities);
    check(
      ProjectSettingsList.craftingStations,
      craftingStations,
      baseline.craftingStations,
    );
    check(
      ProjectSettingsList.craftingSpecializations,
      craftingSpecializations,
      baseline.craftingSpecializations,
    );
    check(
      ProjectSettingsList.derivedStats,
      derivedStats,
      baseline.derivedStats,
    );
    return messages;
  }

  bool get canSave => isDirty && !saving && blockers.isEmpty;

  /// The buffer of one of the three plain lists.
  MetaBuffer<MetaRowDraft> plain(ProjectSettingsList list) => switch (list) {
    ProjectSettingsList.stats => stats,
    ProjectSettingsList.craftingStations => craftingStations,
    ProjectSettingsList.craftingSpecializations => craftingSpecializations,
    _ => throw ArgumentError.value(list, 'list', 'Not a plain meta list'),
  };

  ProjectSettingsState copyWith({
    String? gameTitle,
    String? maxLevelText,
    SoftDeleteReferenceSeverity? severity,
    MetaBuffer<MetaRowDraft>? stats,
    MetaBuffer<RarityRowDraft>? rarities,
    MetaBuffer<MetaRowDraft>? craftingStations,
    MetaBuffer<MetaRowDraft>? craftingSpecializations,
    MetaBuffer<DerivedStatRowDraft>? derivedStats,
    bool? saving,
    String? error,
    bool clearError = false,
  }) => ProjectSettingsState._(
    baseline: baseline,
    gameTitle: gameTitle ?? this.gameTitle,
    maxLevelText: maxLevelText ?? this.maxLevelText,
    severity: severity ?? this.severity,
    stats: stats ?? this.stats,
    rarities: rarities ?? this.rarities,
    craftingStations: craftingStations ?? this.craftingStations,
    craftingSpecializations:
        craftingSpecializations ?? this.craftingSpecializations,
    derivedStats: derivedStats ?? this.derivedStats,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
  );

  ProjectSettingsState _withPlain(
    ProjectSettingsList list,
    MetaBuffer<MetaRowDraft> buffer,
  ) => switch (list) {
    ProjectSettingsList.stats => copyWith(stats: buffer),
    ProjectSettingsList.craftingStations => copyWith(craftingStations: buffer),
    ProjectSettingsList.craftingSpecializations => copyWith(
      craftingSpecializations: buffer,
    ),
    _ => throw ArgumentError.value(list, 'list', 'Not a plain meta list'),
  };
}

/// The dialog's controller; disposed when the dialog closes, so Cancel
/// discards by dropping it, as 0.1.6's modal did on Discard.
final projectSettingsProvider =
    AsyncNotifierProvider.autoDispose<
      ProjectSettingsController,
      ProjectSettingsState
    >(ProjectSettingsController.new);

/// Loads the settings once and holds the working draft until [save].
///
/// Intents are ignored before the load completes and while a save is in
/// flight. Row edits return null on success or 0.1.6's refusal message
/// (an export key another row of the list uses), and change nothing then.
class ProjectSettingsController extends AsyncNotifier<ProjectSettingsState> {
  @override
  Future<ProjectSettingsState> build() async {
    final repository = ref.watch(metaRepositoryProvider);
    return ProjectSettingsState.loaded(await repository.loadProjectSettings());
  }

  MetaRepository get _repository => ref.read(metaRepositoryProvider);

  /// The loaded, idle state, or null when an intent must be ignored.
  ProjectSettingsState? get _idle {
    final s = state.value;
    return s == null || s.saving ? null : s;
  }

  void _set(ProjectSettingsState next) => state = AsyncData(next);

  void setGameTitle(String value) {
    if (_idle case final s?) _set(s.copyWith(gameTitle: value));
  }

  void setMaxLevelText(String value) {
    if (_idle case final s?) _set(s.copyWith(maxLevelText: value));
  }

  void setSeverity(SoftDeleteReferenceSeverity value) {
    if (_idle case final s?) _set(s.copyWith(severity: value));
  }

  /// Adds a stat, crafting station or crafting specialization.
  String? addMetaRow(ProjectSettingsList list, MetaItemInput input) =>
      _edit((s) {
        final row = MetaRowDraft(
          id: '',
          displayName: input.displayName.trim(),
          exportKey: input.exportKey.trim(),
        );
        return s._withPlain(list, s.plain(list).add(row));
      });

  String? updateMetaRow(
    ProjectSettingsList list,
    String id,
    MetaItemInput input,
  ) => _edit(
    (s) => s._withPlain(
      list,
      s
          .plain(list)
          .update(
            id,
            (r) => r.copyWith(
              displayName: input.displayName.trim(),
              exportKey: input.exportKey.trim(),
            ),
          ),
    ),
  );

  String? addRarity(MetaRarityInput input) => _edit(
    (s) => s.copyWith(
      rarities: s.rarities.add(
        RarityRowDraft(
          id: '',
          displayName: input.displayName.trim(),
          exportKey: input.exportKey.trim(),
          colorHex: input.colorHex.trim(),
        ),
      ),
    ),
  );

  String? updateRarity(String id, MetaRarityInput input) => _edit(
    (s) => s.copyWith(
      rarities: s.rarities.update(
        id,
        (r) => r.copyWith(
          displayName: input.displayName.trim(),
          exportKey: input.exportKey.trim(),
          colorHex: input.colorHex.trim(),
        ),
      ),
    ),
  );

  String? addDerivedStat(DerivedStatInput input) => _edit(
    (s) => s.copyWith(
      derivedStats: s.derivedStats.add(
        DerivedStatRowDraft(
          id: '',
          displayName: input.displayName.trim(),
          exportKey: input.exportKey.trim(),
          formula: input.formula.trim(),
          outputType: input.outputType,
          roundingMode: input.roundingMode,
        ),
      ),
    ),
  );

  String? updateDerivedStat(String id, DerivedStatInput input) => _edit(
    (s) => s.copyWith(
      derivedStats: s.derivedStats.update(
        id,
        (r) => r.copyWith(
          displayName: input.displayName.trim(),
          exportKey: input.exportKey.trim(),
          formula: input.formula.trim(),
          outputType: input.outputType,
          roundingMode: input.roundingMode,
        ),
      ),
    ),
  );

  /// Moves a row of [list] from [from] to [to] (the move up / move down
  /// buttons pass neighbours).
  void moveRow(ProjectSettingsList list, int from, int to) {
    _edit(
      (s) => switch (list) {
        ProjectSettingsList.rarities => s.copyWith(
          rarities: s.rarities.move(from, to),
        ),
        ProjectSettingsList.derivedStats => s.copyWith(
          derivedStats: s.derivedStats.move(from, to),
        ),
        _ => s._withPlain(list, s.plain(list).move(from, to)),
      },
    );
  }

  /// Removes the row [id] from [list] unless records use it.
  ///
  /// A stored row is checked with `checkInUse` first, so an in-use row is
  /// refused at click time with the core's 0.1.6 reason (for example
  /// `Rarity is used by 2 item(s).`), which is returned, and the buffer is
  /// left as it was. A `new:` row is removed without a check. Returns null
  /// when the row was removed.
  Future<String?> tryDelete(ProjectSettingsList list, String id) async {
    if (_idle == null) return null;
    if (!isNewMetaId(id)) {
      final MetaInUseResult result;
      try {
        result = await _repository.checkInUse(list.inUseKind, id);
      } on Object catch (e) {
        return saveErrorMessage(e);
      }
      if (!ref.mounted) return null;
      if (result.inUse) return result.reason;
    }
    _edit(
      (s) => switch (list) {
        ProjectSettingsList.rarities => s.copyWith(
          rarities: s.rarities.remove(id),
        ),
        ProjectSettingsList.derivedStats => s.copyWith(
          derivedStats: s.derivedStats.remove(id),
        ),
        _ => s._withPlain(list, s.plain(list).remove(id)),
      },
    );
    return null;
  }

  /// Back to the stored settings (0.1.6's Discard).
  void discard() {
    if (_idle case final s?) _set(ProjectSettingsState.loaded(s.baseline));
  }

  void clearError() {
    if (_idle case final s?) _set(s.copyWith(clearError: true));
  }

  /// Commits the scalars and the five lists in one `saveProjectSettings`
  /// transaction, recorded as `Project settings changed`. On success the
  /// read-back settings become the baseline, the write epoch is bumped once
  /// and true is returned. A refusal or failure keeps every edit, sets
  /// [ProjectSettingsState.error] and returns false. Does nothing (false)
  /// when not dirty, blocked or already saving.
  Future<bool> save() async {
    final s = _idle;
    if (s == null || !s.canSave) return false;
    final epoch = ref.read(writeEpochProvider.notifier);
    _set(s.copyWith(saving: true, clearError: true));
    try {
      final saved = await _repository.saveProjectSettings(s.draft);
      epoch.bump();
      if (ref.mounted) _set(ProjectSettingsState.loaded(saved));
      return true;
    } on Object catch (e) {
      if (ref.mounted) {
        _set(state.requireValue.copyWith(saving: false, error: _message(e)));
      }
      return false;
    }
  }

  String? _edit(ProjectSettingsState Function(ProjectSettingsState) change) {
    final s = _idle;
    if (s == null) return null;
    try {
      _set(change(s));
      return null;
    } on MetaBufferConflict catch (e) {
      return e.message;
    }
  }

  static String _message(Object error) => switch (error) {
    MetaInUse(:final kind, :final counts) =>
      'A removed ${kind.replaceAll('-', ' ')} is still in use '
          '(${counts.entries.map((e) => '${e.value} ${e.key}').join(', ')}). '
          'Nothing was saved.',
    _ => saveErrorMessage(error),
  };
}

/// The read-only facts the General tab shows about the open project.
final class ProjectSettingsHeader {
  const ProjectSettingsHeader({
    required this.projectName,
    required this.location,
  });

  /// `project_info.project_name`, which the settings draft does not carry
  /// and 0.1.6 never let the user edit.
  final String projectName;

  /// The project folder, or the file when it has no folder set (0.1.6
  /// `projectFolder?.root ?? filePath`).
  final String location;
}

final projectSettingsHeaderProvider =
    Provider.autoDispose<ProjectSettingsHeader>((ref) {
      final metadata = ref.watch(requireSessionProvider).metadata;
      return ProjectSettingsHeader(
        projectName: metadata.projectName,
        location: metadata.projectFolder?.root ?? metadata.filePath,
      );
    });
