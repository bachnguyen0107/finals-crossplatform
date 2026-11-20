import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/preferences_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesRepository(prefs);
});

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.read(preferencesRepositoryProvider).getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesRepositoryProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class NoteFontSizeController extends Notifier<NoteFontSize> {
  @override
  NoteFontSize build() {
    return ref.read(preferencesRepositoryProvider).getNoteFontSize();
  }

  Future<void> setNoteFontSize(NoteFontSize size) async {
    state = size;
    await ref.read(preferencesRepositoryProvider).setNoteFontSize(size);
  }
}

final noteFontSizeProvider =
    NotifierProvider<NoteFontSizeController, NoteFontSize>(
  NoteFontSizeController.new,
);

final noteFontSizeValueProvider = Provider<double>((ref) {
  return ref.watch(noteFontSizeProvider).fontSize;
});