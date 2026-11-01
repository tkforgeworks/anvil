import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wall clock the editor controllers stamp edits with, for undo
/// coalescing (design §8.3). Tests override it to drive the 500 ms window
/// deterministically.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
