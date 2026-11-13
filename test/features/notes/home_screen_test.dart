import 'package:finals/features/notes/application/notes_providers.dart';
import 'package:finals/features/notes/domain/note.dart';
import 'package:finals/features/notes/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotesController extends NotesController {
  FakeNotesController(this.notes);

  final List<Note> notes;

  @override
  Future<List<Note>> build() async => notes;
}

Note makeNote(
  String id, {
  String content = '',
  bool pinned = false,
  bool locked = false,
}) {
  return Note(
    id: id,
    ownerId: 'user-1',
    title: 'Note $id',
    content: content,
    isPinned: pinned,
    pinnedAt: pinned ? DateTime.utc(2026, 11, 13) : null,
    isLocked: locked,
    version: 1,
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 12),
  );
}

Future<void> pumpHome(WidgetTester tester, List<Note> notes) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notesControllerProvider.overrideWith(() => FakeNotesController(notes)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an empty state when there are no notes', (tester) async {
    await pumpHome(tester, []);
    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets('shows notes in a grid and switches to a list', (tester) async {
    await pumpHome(tester, [makeNote('a'), makeNote('b')]);
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(find.byTooltip('Show as list'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Note a'), findsOneWidget);
  });

  testWidgets('shows status icons and hides locked content', (tester) async {
    await pumpHome(tester, [
      makeNote('pinned', content: 'Milk', pinned: true),
      makeNote('locked', content: 'secret text', locked: true),
    ]);

    expect(find.byTooltip('Pinned'), findsOneWidget);
    expect(find.byTooltip('Locked'), findsOneWidget);
    expect(find.text('secret text'), findsNothing);
    expect(find.text('Locked note'), findsOneWidget);
  });
}