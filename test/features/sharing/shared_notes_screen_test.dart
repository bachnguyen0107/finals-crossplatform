import 'package:finals/features/sharing/application/sharing_providers.dart';
import 'package:finals/features/sharing/domain/share_models.dart';
import 'package:finals/features/sharing/presentation/shared_notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SharedNoteItem _sampleItem({
  required String shareId,
  required String noteId,
  required String title,
  required String sharerEmail,
  required SharePermission permission,
  required bool isLocked,
  required String content,
  required DateTime updatedAt,
}) {
  return SharedNoteItem(
    shareId: shareId,
    noteId: noteId,
    ownerId: 'owner-$shareId',
    sharerEmail: sharerEmail,
    sharerDisplayName: sharerEmail.split('@').first,
    permission: permission,
    sharedAt: updatedAt,
    title: title,
    content: content,
    isPinned: false,
    isLocked: isLocked,
    version: 1,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

Widget _wrapWithApp(List<SharedNoteItem> Function() itemsBuilder) {
  return ProviderScope(
    overrides: [
      sharedWithMeProvider.overrideWith((ref) async => itemsBuilder()),
    ],
    child: const MaterialApp(
      home: SharedNotesScreen(),
    ),
  );
}

Widget _wrapWithError(Object error) {
  return ProviderScope(
    overrides: [
      sharedWithMeProvider.overrideWith((ref) async {
        throw error;
      }),
    ],
    child: const MaterialApp(
      home: SharedNotesScreen(),
    ),
  );
}

void main() {
  group('SharedNotesScreen', () {
    testWidgets('renders shared items, Untitled fallback, permission chips, and lock icon',
        (tester) async {
      final items = [
        _sampleItem(
          shareId: 's1',
          noteId: 'n1',
          title: 'Lecture Notes',
          sharerEmail: 'alice@example.com',
          permission: SharePermission.read,
          isLocked: false,
          content: 'Public shared body',
          updatedAt: DateTime(2026, 11, 27, 9, 30),
        ),
        _sampleItem(
          shareId: 's2',
          noteId: 'n2',
          title: '   ',
          sharerEmail: 'bob@example.com',
          permission: SharePermission.edit,
          isLocked: true,
          content: 'Top secret locked body',
          updatedAt: DateTime(2026, 11, 27, 10, 15),
        ),
      ];

      await tester.pumpWidget(_wrapWithApp(() => items));
      await tester.pumpAndSettle();

      expect(find.text('Lecture Notes'), findsOneWidget);
      expect(find.text('Untitled'), findsOneWidget);
      expect(find.text('Shared by alice@example.com'), findsOneWidget);
      expect(find.text('Shared by bob@example.com'), findsOneWidget);
      expect(find.text('Can read'), findsOneWidget);
      expect(find.text('Can edit'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('Top secret locked body'), findsNothing);
    });

    testWidgets('shows empty state message when no notes are shared',
        (tester) async {
      await tester.pumpWidget(_wrapWithApp(() => const <SharedNoteItem>[]));
      await tester.pumpAndSettle();

      expect(
        find.text('No notes have been shared with you yet'),
        findsOneWidget,
      );
    });

    testWidgets('shows error state and Retry button on provider failure',
        (tester) async {
      await tester.pumpWidget(_wrapWithError(Exception('Network error')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load shared notes'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });
  });
}