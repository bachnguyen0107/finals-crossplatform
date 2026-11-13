import 'package:flutter/material.dart';

import '../../application/note_view_mode.dart';
import '../../domain/note.dart';
import 'note_card.dart';

class NotesView extends StatelessWidget {
  const NotesView({super.key, required this.notes, required this.mode});

  final List<Note> notes;
  final NoteViewMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == NoteViewMode.list) {
      // Keep list cards readable on wide screens.
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: notes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) =>
                NoteCard(note: notes[index], compact: true),
          ),
        ),
      );
    }

    // Column count adapts to the window width.
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 180,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: notes.length,
      itemBuilder: (_, index) => NoteCard(note: notes[index]),
    );
  }
}