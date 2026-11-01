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
}

/// [FileDialogs] over the Flutter team's `file_selector` plugin.
final class FileSelectorDialogs implements FileDialogs {
  const FileSelectorDialogs();

  static const _anvilFiles = fs.XTypeGroup(
    label: 'Anvil Projects',
    extensions: ['anvil'],
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
}

/// The app's file dialogs; tests override it with a fake.
final fileDialogsProvider = Provider<FileDialogs>(
  (ref) => const FileSelectorDialogs(),
);
