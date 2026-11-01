/// How serious a [ValidationIssue] is; [value] is the 0.1.6 string.
enum ValidationSeverity {
  error('error'),
  warning('warning'),
  info('info');

  const ValidationSeverity(this.value);

  final String value;

  /// The severity whose [value] is [value]; throws [ArgumentError] otherwise.
  static ValidationSeverity fromValue(String value) {
    for (final s in values) {
      if (s.value == value) return s;
    }
    throw ArgumentError.value(value, 'value', 'Unknown validation severity');
  }
}

/// Which kind of record a [ValidationIssue] is about; [value] is the 0.1.6
/// string (`'loot-tables'`, `'derived-stats'`).
enum ValidationDomain {
  classes('classes'),
  abilities('abilities'),
  items('items'),
  recipes('recipes'),
  npcs('npcs'),
  lootTables('loot-tables'),
  derivedStats('derived-stats');

  const ValidationDomain(this.value);

  final String value;

  /// The domain whose [value] is [value]; throws [ArgumentError] otherwise.
  static ValidationDomain fromValue(String value) {
    for (final d in values) {
      if (d.value == value) return d;
    }
    throw ArgumentError.value(value, 'value', 'Unknown validation domain');
  }
}

int _nextIssueId = 0;

/// One validation finding, as 0.1.6's `ValidationIssue`.
///
/// [id] is unique within an isolate's run (`v-1`, `v-2`, ...); 0.1.6 used a
/// random UUID, so ids are not compared: `==`, `hashCode` and [toJson]
/// leave [id] out.
final class ValidationIssue {
  ValidationIssue({
    String? id,
    required this.domain,
    required this.recordId,
    required this.recordDisplayName,
    required this.field,
    required this.severity,
    required this.message,
  }) : id = id ?? 'v-${++_nextIssueId}';

  final String id;
  final ValidationDomain domain;
  final String recordId;
  final String recordDisplayName;

  /// The field the issue is about (`rarityId`, `custom:damage`,
  /// `derivedStat:Max HP`, ...), or null.
  final String? field;
  final ValidationSeverity severity;
  final String message;

  /// The 0.1.6 JSON shape without `id`.
  Map<String, Object?> toJson() => {
    'domain': domain.value,
    'recordId': recordId,
    'recordDisplayName': recordDisplayName,
    'field': field,
    'severity': severity.value,
    'message': message,
  };

  @override
  bool operator ==(Object other) =>
      other is ValidationIssue &&
      other.domain == domain &&
      other.recordId == recordId &&
      other.recordDisplayName == recordDisplayName &&
      other.field == field &&
      other.severity == severity &&
      other.message == message;

  @override
  int get hashCode => Object.hash(
    domain,
    recordId,
    recordDisplayName,
    field,
    severity,
    message,
  );

  @override
  String toString() =>
      'ValidationIssue(${severity.value} ${domain.value}/$recordId '
      '"$recordDisplayName" ${field ?? '-'}: $message)';
}
