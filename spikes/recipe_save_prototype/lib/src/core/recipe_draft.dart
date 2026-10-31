/// The editable state of one recipe: header fields plus the ordered
/// ingredient list. Immutable, with value equality, so `draft != baseline`
/// is the dirty check.
///
/// Holds only what the user edits. Row metadata (`created_at`, `updated_at`,
/// `deleted_at`) is not part of the draft; `sort_order` is the list index.
library;

final class IngredientLine {
  const IngredientLine({required this.itemId, required this.quantity});

  final String itemId;
  final int quantity;

  IngredientLine copyWith({String? itemId, int? quantity}) => IngredientLine(
    itemId: itemId ?? this.itemId,
    quantity: quantity ?? this.quantity,
  );

  @override
  bool operator ==(Object other) =>
      other is IngredientLine &&
      other.itemId == itemId &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(itemId, quantity);

  @override
  String toString() => 'IngredientLine($itemId x$quantity)';
}

const Object _unset = Object();

final class RecipeDraft {
  RecipeDraft({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.outputItemId,
    required this.outputQuantity,
    required this.craftingStationId,
    required this.craftingSpecializationId,
    required List<IngredientLine> ingredients,
  }) : ingredients = List<IngredientLine>.unmodifiable(ingredients);

  /// Immutable internal ID; never edited, never shown.
  final String id;
  final String displayName;
  final String exportKey;
  final String description;
  final String outputItemId;
  final int outputQuantity;
  final String? craftingStationId;
  final String? craftingSpecializationId;

  /// In display (and `sort_order`) order.
  final List<IngredientLine> ingredients;

  /// Nullable foreign keys use a sentinel so `copyWith(craftingStationId:
  /// null)` clears the field instead of keeping it.
  RecipeDraft copyWith({
    String? displayName,
    String? exportKey,
    String? description,
    String? outputItemId,
    int? outputQuantity,
    Object? craftingStationId = _unset,
    Object? craftingSpecializationId = _unset,
    List<IngredientLine>? ingredients,
  }) {
    return RecipeDraft(
      id: id,
      displayName: displayName ?? this.displayName,
      exportKey: exportKey ?? this.exportKey,
      description: description ?? this.description,
      outputItemId: outputItemId ?? this.outputItemId,
      outputQuantity: outputQuantity ?? this.outputQuantity,
      craftingStationId: identical(craftingStationId, _unset)
          ? this.craftingStationId
          : craftingStationId as String?,
      craftingSpecializationId: identical(craftingSpecializationId, _unset)
          ? this.craftingSpecializationId
          : craftingSpecializationId as String?,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecipeDraft &&
      other.id == id &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.description == description &&
      other.outputItemId == outputItemId &&
      other.outputQuantity == outputQuantity &&
      other.craftingStationId == craftingStationId &&
      other.craftingSpecializationId == craftingSpecializationId &&
      _listEquals(other.ingredients, ingredients);

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    exportKey,
    description,
    outputItemId,
    outputQuantity,
    craftingStationId,
    craftingSpecializationId,
    Object.hashAll(ingredients),
  );

  @override
  String toString() =>
      'RecipeDraft($displayName, out=$outputItemId x$outputQuantity, '
      'ingredients=$ingredients)';
}

bool _listEquals<E>(List<E> a, List<E> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
