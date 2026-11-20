import 'package:finals/features/notes/application/auto_saver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const delay = Duration(milliseconds: 20);
  Future<void> waitForSave() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  test('several quick edits are saved only once', () async {
    var saves = 0;
    final saver = AutoSaver(save: () async => saves++, delay: delay);

    saver.markChanged();
    saver.markChanged();
    saver.markChanged();
    await waitForSave();

    expect(saves, 1);
    expect(saver.status, SaveStatus.saved);
    saver.dispose();
  });

  test('flush saves right away without waiting for the delay', () async {
    var saves = 0;
    final saver = AutoSaver(
      save: () async => saves++,
      delay: const Duration(minutes: 1),
    );

    saver.markChanged();
    await saver.flush();

    expect(saves, 1);
    expect(saver.hasUnsavedChanges, isFalse);
    saver.dispose();
  });

  test('a failed save is reported and can be retried', () async {
    var offline = true;
    var saves = 0;
    final saver = AutoSaver(
      save: () async {
        if (offline) throw Exception('offline');
        saves++;
      },
      delay: delay,
    );

    saver.markChanged();
    await saver.flush();
    expect(saver.status, SaveStatus.failed);
    expect(saver.hasUnsavedChanges, isTrue);

    offline = false;
    await saver.flush();
    expect(saves, 1);
    expect(saver.status, SaveStatus.saved);
    saver.dispose();
  });
}