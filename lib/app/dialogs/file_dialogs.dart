/// The native file dialogs the project lifecycle needs. Every dialog call in
/// the app goes through [FileDialogs], so tests override
/// [fileDialogsProvider] with a fake; this is the only file that imports
/// `file_selector`.
library;

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native dialogs. Each returns null when the user cancels.
abstract interface class FileDialogs {
  /// A folder, as 0.1.6's `openDirectory` + `createDirectory` dialog.
  Future<String?> pickDirectory({String? initialDirectory});

  /// One `.anvil` project file, as 0.1.6's "Open Anvil Project" dialog.
  Future<String?> pickAnvilFile({String? initialDirectory});

  /// One `.json` custom theme file, as 0.1.6's "Select Custom Theme JSON"
  /// dialog.
  Future<String?> pickThemeFile({String? initialDirectory});

  /// Where to save one file, as 0.1.6's save dialog; [suggestedName] is
  /// the initial file name. Returns the chosen path.
  Future<String?> pickSaveLocation({
    String? initialDirectory,
    String? suggestedName,
  });
}

/// [FileDialogs] over the Flutter team's `file_selector` plugin.
final class FileSelectorDialogs implements FileDialogs {
  const FileSelectorDialogs();

  static const _anvilFiles = fs.XTypeGroup(
    label: 'Anvil Projects',
    extensions: ['anvil'],
  );

  static const _jsonFiles = fs.XTypeGroup(
    label: 'JSON Files',
    extensions: ['json'],
  );

  @override
  Future<String?> pickDirectory({String? initialDirectory}) =>
      fs.getDirectoryPath(
        initialDirectory: initialDirectory,
        canCreateDirectories: true,
      );

  @override
  Future<String?> pickAnvilFile({String? initialDirectory}) async {
    final file = await fs.openFile(
      acceptedTypeGroups: const [_anvilFiles],
      initialDirectory: initialDirectory,
    );
    return file?.path;
  }

  @override
  Future<String?> pickThemeFile({String? initialDirectory}) async {
    final file = await fs.openFile(
      acceptedTypeGroups: const [_jsonFiles],
      initialDirectory: initialDirectory,
    );
    return file?.path;
  }

  @override
  Future<String?> pickSaveLocation({
    String? initialDirectory,
    String? suggestedName,
  }) async {
    final location = await fs.getSaveLocation(
      initialDirectory: initialDirectory,
      suggestedName: suggestedName,
      canCreateDirectories: true,
    );
    return location?.path;
  }
}

/// The app's file dialogs; tests override it with a fake.
final fileDialogsProvider = Provider<FileDialogs>(
  (ref) => const FileSelectorDialogs(),
);
