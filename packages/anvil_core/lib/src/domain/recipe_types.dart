/// Crafting recipe record, create input and draft.
///
/// Ported from the "Crafting Recipes" section of 0.1.6's
/// `src/shared/domain-types.ts`.
library;

import 'equality.dart';

/// A list row of the recipes table; ports 0.1.6 `RecipeRecord`.
class RecipeRecord {
  const RecipeRecord({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.outputItemId,
    required this.outputQuantity,
    required this.craftingStationId,
    required this.craftingSpecializationId,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String description;
  final String outputItemId;
  final int outputQuantity;
  final String? craftingStationId;
  final String? craftingSpecializationId;

  /// SQLite `datetime('now')` text, as 0.1.6 passes it through.
  final String createdAt;
  final String updatedAt;

  /// Set when the recipe is soft-deleted.
  final String? deletedAt;
}

/// Ports 0.1.6 `CreateRecipeInput`; the defaults are the ones 0.1.6's
/// repository applies to omitted fields.
class CreateRecipeInput {
  const CreateRecipeInput({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    required this.outputItemId,
    this.outputQuantity = 1,
    this.craftingStationId,
    this.craftingSpecializationId,
  });

  final String displayName;
  final String exportKey;
  final String description;
  final String outputItemId;
  final int outputQuantity;
  final String? craftingStationId;
  final String? craftingSpecializationId;
}

/// Ports 0.1.6 `RecipeIngredient` without its `sortOrder`, which is the
/// ingredient's index in [RecipeDraft.ingredients].
class RecipeIngredient {
  const RecipeIngredient({required this.itemId, required this.quantity});

  final String itemId;

  /// `CHECK (quantity > 0)`; a draft may hold less until save is attempted.
  final int quantity;

  RecipeIngredient copyWith({String? itemId, int? quantity}) =>
      RecipeIngredient(
        itemId: itemId ?? this.itemId,
        quantity: quantity ?? this.quantity,
      );

  @override
  bool operator ==(Object other) =>
      other is RecipeIngredient &&
      other.itemId == itemId &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(itemId, quantity);

  @override
  String toString() => 'RecipeIngredient($itemId, $quantity)';
}

/// The editable value of one crafting recipe; ports the fields of 0.1.6
/// `UpdateRecipeInput` plus its `RecipeIngredient` rows.
class RecipeDraft {
  RecipeDraft({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    required this.outputItemId,
    this.outputQuantity = 1,
    this.craftingStationId,
    this.craftingSpecializationId,
    List<RecipeIngredient> ingredients = const [],
  }) : ingredients = List.unmodifiable(ingredients);

  final String displayName;
  final String exportKey;
  final String description;
  final String outputItemId;
  final int outputQuantity;
  final String? craftingStationId;
  final String? craftingSpecializationId;

  /// Ingredients in order; the index is the `sort_order`.
  final List<RecipeIngredient> ingredients;

  /// Pass `null` for [craftingStationId] or [craftingSpecializationId] to
  /// clear it; omit it to keep the current value.
  RecipeDraft copyWith({
    String? displayName,
    String? exportKey,
    String? description,
    String? outputItemId,
    int? outputQuantity,
    Object? craftingStationId = unset,
    Object? craftingSpecializationId = unset,
    List<RecipeIngredient>? ingredients,
  }) => RecipeDraft(
    displayName: displayName ?? this.displayName,
    exportKey: exportKey ?? this.exportKey,
    description: description ?? this.description,
    outputItemId: outputItemId ?? this.outputItemId,
    outputQuantity: outputQuantity ?? this.outputQuantity,
    craftingStationId: identical(craftingStationId, unset)
        ? this.craftingStationId
        : craftingStationId as String?,
    craftingSpecializationId: identical(craftingSpecializationId, unset)
        ? this.craftingSpecializationId
        : craftingSpecializationId as String?,
    ingredients: ingredients ?? this.ingredients,
  );

  @override
  bool operator ==(Object other) =>
      other is RecipeDraft &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.description == description &&
      other.outputItemId == outputItemId &&
      other.outputQuantity == outputQuantity &&
      other.craftingStationId == craftingStationId &&
      other.craftingSpecializationId == craftingSpecializationId &&
      listEquals(other.ingredients, ingredients);

  @override
  int get hashCode => Object.hash(
    displayName,
    exportKey,
    description,
    outputItemId,
    outputQuantity,
    craftingStationId,
    craftingSpecializationId,
    listHash(ingredients),
  );

  @override
  String toString() =>
      'RecipeDraft($displayName, $exportKey, $description, $outputItemId, '
      '$outputQuantity, $craftingStationId, $craftingSpecializationId, '
      '$ingredients)';
}
