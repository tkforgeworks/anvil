/// What the Stat Growth and Derived Stats tabs read besides the draft:
/// the project's max level, stats and derived stat definitions, and the
/// two previews computed beside the draft (design §8.4, §9.2).
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart';
import '../../shell/shell_providers.dart';
import 'classes_editor_controller.dart';
import 'classes_growth_math.dart';

/// How long a preview waits after the last change before it evaluates
/// (0.1.6's 300 ms `setTimeout`, design §9.2).
const previewDebounce = Duration(milliseconds: 300);

/// The project's max level, re-read after every write so a change in
/// Project Settings reaches an open editor. The tabs and the previews
/// watch it; the class controller only reads it at call time, so a new
/// max level never reloads a draft.
final classMaxLevelProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(writeEpochProvider);
  final settings = await ref
      .watch(metaRepositoryProvider)
      .loadProjectSettings();
  return settings.maxLevel;
});

/// The project's stats in their order, re-read after every write.
final classGrowthStatsProvider = FutureProvider.autoDispose<List<MetaStat>>((
  ref,
) {
  ref.watch(writeEpochProvider);
  return ref.watch(metaRepositoryProvider).listStats();
});

/// The project's derived stat definitions in their order, re-read after
/// every write.
final classDerivedStatsProvider =
    FutureProvider.autoDispose<List<DerivedStatDefinition>>((ref) {
      ref.watch(writeEpochProvider);
      return ref.watch(metaRepositoryProvider).listDerivedStats();
    });

/// The batch size at which a growth preview evaluates on a background
/// isolate ([isolateThreshold]); a test lowers it to run the isolate path.
final growthBatchThresholdProvider = Provider<int>((_) => isolateThreshold);

// ─── Stat growth preview ─────────────────────────────────────────────────────

/// Per formula stat of class `classId`, its computed values for levels 1
/// to max level and its first error, recomputed [previewDebounce] after
/// the last formula change (at once when the editor opens or the max
/// level changes) through [evaluateBatch].
final statGrowthPreviewProvider = NotifierProvider.autoDispose
    .family<StatGrowthPreviewNotifier, Map<String, GrowthPreview>, String>(
      StatGrowthPreviewNotifier.new,
    );

class StatGrowthPreviewNotifier extends Notifier<Map<String, GrowthPreview>> {
  StatGrowthPreviewNotifier(this.classId);

  final String classId;

  final _engine = FormulaEngine();

  /// Computed previews by formula and max level, for the editor session.
  final _cache = <(String, int), GrowthPreview>{};
  Timer? _timer;
  var _generation = 0;
  Map<String, String>? _formulas;
  int? _maxLevel;

  @override
  Map<String, GrowthPreview> build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen<AsyncValue<EditorState<ClassDraft>>>(
      classEditorProvider(classId),
      (_, next) => _inputsChanged(
        formulas: next.value?.draft.statGrowthFormulas,
        maxLevel: _maxLevel,
        debounce: true,
      ),
    );
    ref.listen<AsyncValue<int>>(
      classMaxLevelProvider,
      (_, next) => _inputsChanged(
        formulas: _formulas,
        maxLevel: next.value,
        debounce: false,
      ),
    );
    _formulas = ref
        .read(classEditorProvider(classId))
        .value
        ?.draft
        .statGrowthFormulas;
    _maxLevel = ref.read(classMaxLevelProvider).value;
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(_evaluate());
    });
    return const {};
  }

  void _inputsChanged({
    required Map<String, String>? formulas,
    required int? maxLevel,
    required bool debounce,
  }) {
    final first = _formulas == null || _maxLevel == null;
    if (mapEquals(formulas, _formulas) && maxLevel == _maxLevel) return;
    _formulas = formulas;
    _maxLevel = maxLevel;
    _timer?.cancel();
    if (debounce && !first) {
      _timer = Timer(previewDebounce, () => unawaited(_evaluate()));
    } else {
      unawaited(_evaluate());
    }
  }

  Future<void> _evaluate() async {
    final formulas = _formulas;
    final maxLevel = _maxLevel;
    if (formulas == null || maxLevel == null) return;
    final generation = ++_generation;
    final threshold = ref.read(growthBatchThresholdProvider);
    final bindings = growthBindingsList(maxLevel);
    final next = <String, GrowthPreview>{};
    for (final MapEntry(key: statId, value: formula) in formulas.entries) {
      final cached = _cache[(formula, maxLevel)];
      if (cached != null && cached.values != null) {
        next[statId] = cached;
        continue;
      }
      final results = await _engine.evaluateBatch(
        formula,
        bindings,
        threshold: threshold,
      );
      if (!ref.mounted || generation != _generation) return;
      final preview = growthPreviewFrom(results, previous: state[statId]);
      // A level-1 failure keeps the previous values, which belong to the
      // previous formula, so only successes are cached.
      if (results.isNotEmpty && results.first.error == null) {
        _cache[(formula, maxLevel)] = preview;
      }
      next[statId] = preview;
    }
    if (!mapEquals(next, state)) state = Map.unmodifiable(next);
  }
}

// ─── Derived stat preview ────────────────────────────────────────────────────

/// The derived stat tab's local view state: the preview level of the
/// definition list and the breakpoint levels, which 0.1.6 kept in the
/// editor and never saved. [breakpoints] is null until the user changes
/// them, meaning [defaultBreakpointLevels] of the current max level.
final class DerivedPreviewLevels {
  const DerivedPreviewLevels({this.previewLevel = 1, this.breakpoints});

  final int previewLevel;
  final List<int>? breakpoints;

  List<int> breakpointsFor(int maxLevel) =>
      breakpoints ?? defaultBreakpointLevels(maxLevel);

  @override
  bool operator ==(Object other) =>
      other is DerivedPreviewLevels &&
      other.previewLevel == previewLevel &&
      _sameList(other.breakpoints, breakpoints);

  @override
  int get hashCode => Object.hash(
    previewLevel,
    breakpoints == null ? null : Object.hashAll(breakpoints!),
  );

  static bool _sameList(List<int>? a, List<int>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// [DerivedPreviewLevels] of the editor of class `classId`.
final derivedPreviewLevelsProvider = NotifierProvider.autoDispose
    .family<DerivedPreviewLevelsNotifier, DerivedPreviewLevels, String>(
      DerivedPreviewLevelsNotifier.new,
    );

class DerivedPreviewLevelsNotifier extends Notifier<DerivedPreviewLevels> {
  DerivedPreviewLevelsNotifier(this.classId);

  final String classId;

  @override
  DerivedPreviewLevels build() => const DerivedPreviewLevels();

  /// 0.1.6's `Preview at level`: `max(1, min(maxLevel, n))`.
  void setPreviewLevel(int level, int maxLevel) => state = DerivedPreviewLevels(
    previewLevel: level.clamp(1, maxLevel < 1 ? 1 : maxLevel),
    breakpoints: state.breakpoints,
  );

  /// Adds breakpoint [level] if it lies in 1..[maxLevel] and is not
  /// already there, keeping the list sorted; false (and nothing changes)
  /// otherwise, as 0.1.6's `addLevel` ignored such input.
  bool addBreakpoint(int level, int maxLevel) {
    final current = state.breakpointsFor(maxLevel);
    if (level < 1 || level > maxLevel || current.contains(level)) return false;
    state = DerivedPreviewLevels(
      previewLevel: state.previewLevel,
      breakpoints: [...current, level]..sort(),
    );
    return true;
  }

  void removeBreakpoint(int level, int maxLevel) =>
      state = DerivedPreviewLevels(
        previewLevel: state.previewLevel,
        breakpoints: [
          for (final l in state.breakpointsFor(maxLevel))
            if (l != level) l,
        ],
      );
}

/// The derived stat previews of one class: the stats in a cycle, and per
/// level (the preview level and every breakpoint) each definition's
/// result, absent where it was not evaluated.
final class DerivedStatPreview {
  const DerivedStatPreview({
    this.cyclicIds = const {},
    this.byLevel = const {},
    this.ready = false,
  });

  final Set<String> cyclicIds;
  final Map<int, Map<String, FormulaEvalResult>> byLevel;

  /// False until the first evaluation has run.
  final bool ready;

  FormulaEvalResult? result(int level, String derivedId) =>
      byLevel[level]?[derivedId];
}

/// The inputs a derived preview is computed from.
typedef _DerivedInputs = ({
  ClassDraft draft,
  Map<String, GrowthPreview> growth,
  List<MetaStat> stats,
  List<DerivedStatDefinition> defs,
  List<int> levels,
});

/// [DerivedStatPreview] of class `classId`, recomputed [previewDebounce]
/// after the last change to its inputs (the draft's overrides, metadata,
/// resource multiplier and stat growth, the growth preview, the levels,
/// the project's stats and definitions; at once for the first result):
/// each definition evaluated in dependency order at every level with the
/// stats bound to the grid's values at that level, and cycles found with
/// [findDerivedStatCycle] over the project's graph plus this class's
/// overrides.
final derivedStatPreviewProvider = NotifierProvider.autoDispose
    .family<DerivedStatPreviewNotifier, DerivedStatPreview, String>(
      DerivedStatPreviewNotifier.new,
    );

class DerivedStatPreviewNotifier extends Notifier<DerivedStatPreview> {
  DerivedStatPreviewNotifier(this.classId);

  final String classId;

  final _engine = FormulaEngine();
  Timer? _timer;
  _DerivedInputs? _inputs;

  @override
  DerivedStatPreview build() {
    ref.onDispose(() => _timer?.cancel());
    void changed() => _changed();
    ref.listen(classEditorProvider(classId), (_, _) => changed());
    ref.listen(statGrowthPreviewProvider(classId), (_, _) => changed());
    ref.listen(classGrowthStatsProvider, (_, _) => changed());
    ref.listen(classDerivedStatsProvider, (_, _) => changed());
    ref.listen(classMaxLevelProvider, (_, _) => changed());
    ref.listen(derivedPreviewLevelsProvider(classId), (_, _) => changed());
    scheduleMicrotask(() {
      if (ref.mounted) changed();
    });
    return const DerivedStatPreview();
  }

  _DerivedInputs? _read() {
    final draft = ref.read(classEditorProvider(classId)).value?.draft;
    final stats = ref.read(classGrowthStatsProvider).value;
    final defs = ref.read(classDerivedStatsProvider).value;
    final maxLevel = ref.read(classMaxLevelProvider).value;
    if (draft == null || stats == null || defs == null || maxLevel == null) {
      return null;
    }
    final view = ref.read(derivedPreviewLevelsProvider(classId));
    return (
      draft: draft,
      growth: ref.read(statGrowthPreviewProvider(classId)),
      stats: stats,
      defs: defs,
      levels: {
        view.previewLevel.clamp(1, maxLevel < 1 ? 1 : maxLevel),
        ...view.breakpointsFor(maxLevel),
      }.toList(),
    );
  }

  void _changed() {
    final inputs = _read();
    if (inputs == null) return;
    final previous = _inputs;
    if (previous != null && _sameInputs(previous, inputs)) return;
    _inputs = inputs;
    _timer?.cancel();
    if (!state.ready) {
      _evaluate();
    } else {
      _timer = Timer(previewDebounce, _evaluate);
    }
  }

  static bool _sameInputs(_DerivedInputs a, _DerivedInputs b) =>
      identical(a.stats, b.stats) &&
      identical(a.defs, b.defs) &&
      mapEquals(a.growth, b.growth) &&
      _sameDerivedInputs(a.draft, b.draft) &&
      _sameInts(a.levels, b.levels);

  static bool _sameDerivedInputs(ClassDraft a, ClassDraft b) =>
      a.resourceMultiplier == b.resourceMultiplier &&
      mapEquals(a.derivedStatOverrides, b.derivedStatOverrides) &&
      mapEquals(a.statGrowth, b.statGrowth) &&
      mapEquals(a.statGrowthFormulas, b.statGrowthFormulas) &&
      _sameMetadata(a.metadataFields, b.metadataFields);

  static bool _sameMetadata(
    List<ClassMetadataField> a,
    List<ClassMetadataField> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _evaluate() {
    final inputs = _inputs;
    if (inputs == null || !ref.mounted) return;
    final (:draft, :growth, :stats, :defs, :levels) = inputs;
    final overrides = draft.derivedStatOverrides;
    final cyclic = derivedCycleIds(defs, overrides);
    state = DerivedStatPreview(
      ready: true,
      cyclicIds: cyclic,
      byLevel: {
        for (final level in levels)
          level: evaluateDerivedAtLevel(
            defs: defs,
            overrides: overrides,
            cyclicIds: cyclic,
            baseBindings: derivedBaseBindings(
              stats: stats,
              draft: draft,
              growthAt: (statId) =>
                  displayedGrowth(draft, growth, statId, level),
            ),
            engine: _engine,
          ),
      },
    );
  }
}
