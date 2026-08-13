import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod provider to manage the active index of the app's root navigation shell.
/// 0 = Dashboard, 1 = Tasks, 2 = Settings
final shellIndexProvider = StateProvider<int>((ref) => 0);
