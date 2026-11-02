import 'package:anvil/app/lists/list_domain_adapter.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil_core/anvil_core.dart';

/// The recipes list over the real repository, as ANVL-193's adapter will
/// be (minus its columns).
class SqliteRecipeListAdapter
    with ListAdapterDefaults<RecipeRecord>
    implements ListDomainAdapter<RecipeRecord> {
  SqliteRecipeListAdapter(this.repository);

  final RecipeRepository repository;

  @override
  ShellDomain get domain => ShellDomain.recipes;

  @override
  Future<List<RecipeRecord>> list(RecordListMode mode) =>
      repository.list(mode: mode);

  @override
  String idOf(RecipeRecord row) => row.id;

  @override
  String displayNameOf(RecipeRecord row) => row.displayName;

  @override
  String exportKeyOf(RecipeRecord row) => row.exportKey;

  @override
  String? deletedAtOf(RecipeRecord row) => row.deletedAt;

  @override
  List<ListColumn<RecipeRecord>> get columns => const [];

  @override
  Future<void> softDelete(String id) => repository.softDelete(id);

  @override
  Future<void> restore(String id) => repository.restore(id);

  @override
  Future<void> hardDelete(String id) => repository.hardDelete(id);

  @override
  Future<RecipeRecord?> duplicate(String id) => repository.duplicate(id);
}
