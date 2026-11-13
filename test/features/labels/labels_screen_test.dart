import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finals/features/labels/application/labels_providers.dart';
import 'package:finals/features/labels/data/labels_repository.dart';
import 'package:finals/features/labels/domain/label.dart';
import 'package:finals/features/labels/presentation/labels_screen.dart';

// 1. Tạo bản giả kế thừa từ Fake và LabelsRepository (không cần gọi super với client thật)
class FakeLabelsRepository extends Fake implements LabelsRepository {
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

// 2. Tạo Controller giả bỏ qua bước kiểm tra user thực tế
class TestLabelsController extends LabelsController {
  @override
  Future<List<Label>> build() async {
    final repo = ref.watch(labelsRepositoryProvider);
    return repo.fetchLabels();
  }
}

void main() {
  testWidgets('LabelsScreen displays labels and confirms delete', (tester) async {
    final fakeRepo = FakeLabelsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labelsRepositoryProvider.overrideWithValue(fakeRepo),
          // Override controller bằng bản Test controller để tránh lỗi Auth/Supabase
          labelsControllerProvider.overrideWith(TestLabelsController.new),
        ],
        child: const MaterialApp(
          home: LabelsScreen(),
        ),
      ),
    );

    // Đợi async build hoàn tất
    await tester.pumpAndSettle();

    // Kiểm tra label 'Work' hiển thị
    expect(find.text('Work'), findsOneWidget);

    // Nhấn nút xóa
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Kiểm tra dialog xác nhận xuất hiện
    expect(find.textContaining('Deleting a label will never delete your notes.'), findsOneWidget);

    // Xác nhận xóa trên dialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Kiểm tra nhãn đã bị xóa và hiển thị trạng thái trống
    expect(find.text('Work'), findsNothing);
    expect(find.text('No labels yet'), findsOneWidget);
  });
}