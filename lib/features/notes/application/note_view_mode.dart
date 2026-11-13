import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NoteViewMode { grid, list }

/// Grid by default. Saving this choice as a user preference is added later.
final noteViewModeProvider =
    NotifierProvider<NoteViewModeController, NoteViewMode>(
  NoteViewModeController.new,
);

class NoteViewModeController extends Notifier<NoteViewMode> {
  @override
  NoteViewMode build() => NoteViewMode.grid;

  void toggle() {
    state = state == NoteViewMode.grid ? NoteViewMode.list : NoteViewMode.grid;
  }
}