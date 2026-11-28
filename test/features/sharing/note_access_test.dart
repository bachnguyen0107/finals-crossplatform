import 'package:finals/features/notes/application/notes_providers.dart';
import 'package:finals/features/sharing/application/sharing_providers.dart';
import 'package:finals/features/sharing/domain/share_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SharedNoteItem _sharedItem({
  required String noteId,
  required SharePermission permission,
}) {
  final now = DateTime.utc(2026, 11, 28);
  return SharedNoteItem(
    shareId: 'share-$noteId',
    noteId: noteId,
    ownerId: 'owner-other',
    sharerEmail: 'owner@example.com',
    sharerDisplayName: 'Owner',
    permission: permission,
    sharedAt: now,
    title: 'Shared $noteId',
    content: 'Body',
    isPinned: false,
    isLocked: false,
    version: 1,
    createdAt: now,
    updatedAt: now,
  );
}

ProviderContainer _makeContainer({
  String? currentUserId = 'user-1',
  List<SharedNoteItem> sharedNotes = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      notesUserIdProvider.overrideWithValue(currentUserId),
      sharedWithMeProvider.overrideWith((ref) async => sharedNotes),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('noteAccessProvider', () {
    test('returns owner when ownerId matches current userId', () async {
      final container = _makeContainer(currentUserId: 'user-1');

      final access = await container.read(
        noteAccessProvider((noteId: 'n1', ownerId: 'user-1')).future,
      );

      expect(access, NoteAccess.owner);
    });

    test('returns edit when note is shared with edit permission', () async {
      final container = _makeContainer(
        currentUserId: 'user-1',
        sharedNotes: [
          _sharedItem(noteId: 'n2', permission: SharePermission.edit),
        ],
      );

      final access = await container.read(
        noteAccessProvider((noteId: 'n2', ownerId: 'user-2')).future,
      );

      expect(access, NoteAccess.edit);
    });

    test('returns read when note is shared with read permission', () async {
      final container = _makeContainer(
        currentUserId: 'user-1',
        sharedNotes: [
          _sharedItem(noteId: 'n3', permission: SharePermission.read),
        ],
      );

      final access = await container.read(
        noteAccessProvider((noteId: 'n3', ownerId: 'user-2')).future,
      );

      expect(access, NoteAccess.read);
    });

    test('returns read when note is not in shared list', () async {
      final container = _makeContainer(
        currentUserId: 'user-1',
        sharedNotes: [
          _sharedItem(noteId: 'n2', permission: SharePermission.edit),
        ],
      );

      final access = await container.read(
        noteAccessProvider((noteId: 'unknown-note', ownerId: 'user-2')).future,
      );

      expect(access, NoteAccess.read);
    });
  });
}