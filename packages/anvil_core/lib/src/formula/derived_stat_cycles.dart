import 'formula_engine.dart';

/// The fields of a derived stat definition the cycle check reads.
final class DerivedStatFormula {
  const DerivedStatFormula({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.formula,
  });

  final String id;
  final String displayName;

  /// What other formulas reference this stat by.
  final String exportKey;
  final String formula;
}

/// A dependency cycle between derived stats, in the order Electron's
/// `findCycle` reports it.
final class DerivedStatCycle {
  const DerivedStatCycle({required this.ids, required this.names});

  final List<String> ids;

  /// Display names, parallel to [ids].
  final List<String> names;

  String get _path => '${names.join(' → ')} → ${names.first}';

  /// The project-level issue message (one issue per stat in the cycle).
  String get message => 'Derived stat is part of a dependency cycle: $_path.';

  /// The per-class issue message when a class's overrides create the cycle.
  String get overrideMessage =>
      'Override formulas create a dependency cycle: $_path.';

  /// Electron's `arraysEqual`: the same stats, regardless of order. A class
  /// whose override graph has the same cycle as the base graph gets no
  /// per-class issue.
  bool isSameCycleAs(DerivedStatCycle? other) {
    if (other == null || other.ids.length != ids.length) return false;
    final a = [...ids]..sort();
    final b = [...other.ids]..sort();
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Finds a dependency cycle among [definitions], ported from Electron's
/// `checkDerivedStatCycles`/`findCycle` (`src/main/validation/engine.ts`).
///
/// An edge runs from a stat to every other stat whose export key its
/// formula references (by [extractVariableNames]; for duplicate export
/// keys the later definition wins). [overrides] maps derived stat id to a
/// class's override formula, which replaces that stat's edges. A stat
/// whose effective formula fails [validateFormula] is left out, as
/// Electron skips formulas that failed the syntax check. Returns null when
/// the graph is acyclic.
DerivedStatCycle? findDerivedStatCycle(
  List<DerivedStatFormula> definitions, {
  Map<String, String> overrides = const {},
}) {
  final byKey = <String, DerivedStatFormula>{
    for (final d in definitions) d.exportKey: d,
  };

  final graph = <String, List<String>>{};
  for (final d in definitions) {
    final formula = overrides[d.id] ?? d.formula;
    if (validateFormula(formula) != null) continue;
    graph[d.id] = [
      for (final name in extractVariableNames(formula))
        if (byKey[name] case final target?) target.id,
    ];
  }

  final cycle = _findCycle(graph);
  if (cycle == null) return null;
  return DerivedStatCycle(
    ids: List.unmodifiable(cycle),
    names: List.unmodifiable([
      for (final id in cycle)
        definitions.firstWhere((d) => d.id == id).displayName,
    ]),
  );
}

/// Iterative DFS with colours (0 unvisited, 1 on stack, 2 done) over the
/// graph's insertion order; on the first back-edge, returns the cycle
/// rebuilt from the parent chain, exactly as Electron orders it.
List<String>? _findCycle(Map<String, List<String>> graph) {
  final color = <String, int>{for (final k in graph.keys) k: 0};
  final parent = <String, String?>{};

  for (final start in graph.keys) {
    if (color[start] != 0) continue;

    final stack = <_Frame>[_Frame(start)];
    color[start] = 1;
    parent[start] = null;

    while (stack.isNotEmpty) {
      final frame = stack.last;
      final children = graph[frame.node] ?? const <String>[];

      if (frame.childIdx >= children.length) {
        color[frame.node] = 2;
        stack.removeLast();
        continue;
      }

      final child = children[frame.childIdx++];
      final c = color[child] ?? 0;

      if (c == 1) {
        final cycle = <String>[child];
        String? n = frame.node;
        while (n != null && n != child) {
          cycle.add(n);
          n = parent[n];
        }
        return cycle.reversed.toList();
      }
      if (c == 0) {
        color[child] = 1;
        parent[child] = frame.node;
        stack.add(_Frame(child));
      }
    }
  }

  return null;
}

final class _Frame {
  _Frame(this.node);
  final String node;
  int childIdx = 0;
}
