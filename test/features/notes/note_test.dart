import 'package:finals/features/notes/domain/note.dart';
import 'package:flutter_test/flutter_test.dart';

Note makeNote(
  String id, {
  bool pinned = false,
  DateTime? pinnedAt,
  required DateTime updatedAt,
}) {
  return Note(
    id: id,
    ownerId: 'user-1',
    title: 'Note $id',
    content: '',
    isPinned: pinned,
    pinnedAt: pinnedAt,
    isLocked: false,
    version: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: updatedAt,
  );
}

void main() {
  test('fromMap reads a Supabase row', () {
    final note = Note.fromMap({
      'id': 'a1',
      'owner_id': 'u1',
      'title': 'Shopping',
      'content': 'Milk',
      'is_pinned': true,
      'pinned_at': '2026-11-13T08:00:00+00:00',
      'is_locked': false,
      'version': 3,
      'created_at': '2026-11-10T08:00:00+00:00',
      'updated_at': '2026-11-12T08:00:00+00:00',
    });

    expect(note.title, 'Shopping');
    expect(note.isPinned, isTrue);
    expect(note.version, 3);
    expect(note.pinnedAt, DateTime.utc(2026, 11, 13, 8));
  });

  test('pinned notes always come before unpinned notes', () {
    final sorted = sortNotes([
      makeNote('new', updatedAt: DateTime.utc(2026, 11, 13)),
      makeNote(
        'pinned',
        pinned: true,
        pinnedAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);

    expect(sorted.map((n) => n.id), ['pinned', 'new']);
  });

  test('pinned notes are ordered by pin time, others by last edit', () {
    final sorted = sortNotes([
      makeNote('old-edit', updatedAt: DateTime.utc(2026, 11, 1)),
      makeNote(
        'pinned-first',
        pinned: true,
        pinnedAt: DateTime.utc(2026, 11, 5),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
      makeNote('new-edit', updatedAt: DateTime.utc(2026, 11, 12)),
      makeNote(
        'pinned-later',
        pinned: true,
        pinnedAt: DateTime.utc(2026, 11, 9),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    ]);

    expect(
      sorted.map((n) => n.id),
      ['pinned-later', 'pinned-first', 'new-edit', 'old-edit'],
    );
  });
}