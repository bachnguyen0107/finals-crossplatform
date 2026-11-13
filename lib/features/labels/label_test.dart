import 'package:flutter_test/flutter_test.dart';
import 'package:finals/features/labels/domain/label.dart';

void main() {
  group('Label validation & mapping', () {
    test('validateLabelName checks empty, trim, and max length', () {
      expect(validateLabelName(''), isNotNull);
      expect(validateLabelName('   '), isNotNull);
      expect(validateLabelName('A' * 41), isNotNull);
      expect(validateLabelName('Work'), isNull);
      expect(validateLabelName('  Personal  '), isNull);
    });

    test('Label.fromMap parses correctly', () {
      final map = {
        'id': '123',
        'owner_id': 'owner-abc',
        'name': 'Important',
        'created_at': '2026-01-01T00:00:00.000Z',
      };
      final label = Label.fromMap(map);
      expect(label.id, '123');
      expect(label.ownerId, 'owner-abc');
      expect(label.name, 'Important');
      expect(label.createdAt.isUtc, isTrue);
    });
  });
}