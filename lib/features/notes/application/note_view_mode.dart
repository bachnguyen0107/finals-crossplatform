import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';

enum NoteViewMode { grid, list }

/// Grid by default. Saving this choice as a user preference is added later.
final noteViewModeProvider =
    NotifierProvider<NoteViewModeController, NoteViewMode>(
  NoteViewModeController.new,
);

class NoteViewModeController extends Notifier<NoteViewMode> {
  @override
  NoteViewMode build() {
    listenSelf((previous, next) {
      if (previous != null && previous != next) {
        ref.read(preferencesRepositoryProvider).setNoteViewMode(next);
      }
    });
    return ref.read(preferencesRepositoryProvider).getNoteViewMode();
  }

  void toggle() {
    state = state == NoteViewMode.grid ? NoteViewMode.list : NoteViewMode.grid;
  }
}