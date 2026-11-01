/// A save-blocking rule a draft breaks (design §8.6).
///
/// The editor notifier (ANVL-164) runs the per-domain blocker functions on
/// every edit, disables Save while the list is non-empty and shows each
/// [message] against its [field]; the repository `save` runs the same
/// functions again inside the transaction and refuses with `SaveBlocked`.
class SaveBlocker {
  const SaveBlocker(this.field, this.message);

  /// The draft field the rule is about, as a path such as `exportKey`,
  /// `ingredients`, `entries[2].quantityMax` or `metadataFields[0].fieldKey`;
  /// empty for a record-level rule.
  final String field;

  /// The message shown to the user.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is SaveBlocker && other.field == field && other.message == message;

  @override
  int get hashCode => Object.hash(field, message);

  @override
  String toString() => 'SaveBlocker($field: $message)';
}
