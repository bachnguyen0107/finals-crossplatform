import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../notes/application/note_view_mode.dart';

enum NoteFontSize {
  small(label: 'Small', fontSize: 14.0),
  medium(label: 'Medium', fontSize: 16.0),
  large(label: 'Large', fontSize: 18.0);

  const NoteFontSize({required this.label, required this.fontSize});

  final String label;
  final double fontSize;
}

class PreferencesRepository {
  PreferencesRepository(this._prefs);

  final SharedPreferences? _prefs;

  static const themeModeKey = 'pref_theme_mode';
  static const noteFontSizeKey = 'pref_note_font_size';
  static const noteViewModeKey = 'pref_note_view_mode';

  ThemeMode getThemeMode() {
    final value = _prefs?.getString(themeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs?.setString(themeModeKey, mode.name);
  }

  NoteFontSize getNoteFontSize() {
    final value = _prefs?.getString(noteFontSizeKey);
    return switch (value) {
      'small' => NoteFontSize.small,
      'large' => NoteFontSize.large,
      _ => NoteFontSize.medium,
    };
  }

  Future<void> setNoteFontSize(NoteFontSize size) async {
    await _prefs?.setString(noteFontSizeKey, size.name);
  }

  NoteViewMode getNoteViewMode() {
    final value = _prefs?.getString(noteViewModeKey);
    return switch (value) {
      'list' => NoteViewMode.list,
      _ => NoteViewMode.grid,
    };
  }

  Future<void> setNoteViewMode(NoteViewMode mode) async {
    await _prefs?.setString(noteViewModeKey, mode.name);
  }
}