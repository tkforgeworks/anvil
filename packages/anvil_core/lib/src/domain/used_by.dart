/// One active record that references another, as the Used By panels list
/// them: the `{ id, displayName }` pairs of 0.1.6's `ClassUsedBy`,
/// `AbilityUsedBy`, `ItemUsedBy` and `LootTableUsedBy`.
class UsedByRef {
  const UsedByRef(this.id, this.displayName);

  final String id;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is UsedByRef && other.id == id && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);

  @override
  String toString() => 'UsedByRef($id, $displayName)';
}
