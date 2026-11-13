import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finals/features/labels/application/labels_providers.dart';
import 'package:finals/features/labels/data/labels_repository.dart';
import 'package:finals/features/labels/domain/label.dart';
import 'package:finals/features/labels/presentation/labels_screen.dart';

class FakeLabelsRepository extends LabelsRepository {
  FakeLabelsRepository() : super(null!);

  final List<Label> _labels = [
    Label(
      id: '1',
      ownerId: 'user-1',
      name: 'Work',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Label>> fetchLabels() async => _labels;

  @override
  Future<void> deleteLabel(String id) async {
    _labels.removeWhere((l) => l.id == id);
  }
}

void main() {
  testWidgets('LabelsScreen displays labels and confirms delete', (tester) async {
    final fakeRepo = FakeLabelsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labelsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: LabelsScreen(),
        ),
      ),
    );

    // Let the async build complete
    await tester.pumpAndSettle();

    // Verify label is shown
    expect(find.text('Work'), findsOneWidget);

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Verify confirmation dialog appears stating notes will not be deleted
    expect(find.textContaining('Deleting a label will never delete your notes.'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify label is removed
    expect(find.text('Work'), findsNothing);
    expect(find.text('No labels yet'), findsOneWidget);
  });
}